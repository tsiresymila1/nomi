import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/logger.dart';
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/chat/presentation/cubit/chat_ui_cubits.dart';
import 'package:gena/features/chat/data/services/chat_runtime_dependencies.dart';
import 'package:gena/features/chat/data/services/chat_runtime_helpers.dart';
import 'package:gena/features/chat/data/services/chat_thread_context_service.dart';
import 'package:gena/features/chat/data/services/genkit_chat_helpers.dart';
import 'package:gena/features/chat/data/services/local_model_runtime.dart';
import 'package:gena/features/chat/data/tools/chat_tools.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/workspace/data/models/workspace_entity.dart';
import 'package:genkit/genkit.dart' hide ModelInfo;
import 'package:genkit_openai/genkit_openai.dart';
import 'package:schemantic/schemantic.dart';

const String _remoteNamespace = 'remote';

Future<void> generateAssistantResponseWithGenkit({
  required ChatRuntimeDependencies deps,
  required db.GenaDatabase database,
  required int chatId,
  required ModelInfo activeModel,
  required bool Function() isCancelled,
}) async {
  final activeWorkspace = await deps.workspaceQueries.resolveActiveWorkspace();
  final basePrompt = activeWorkspace?.generalInstruction.trim() ?? '';
  final systemInstruction = buildSystemInstruction(basePrompt);
  final enableRag = AppCapabilities.current.isWorkspaceRagEnabled(
    workspaceRagEnabled: activeWorkspace?.ragEnabled ?? false,
  );
  final toolDefinitions = buildUnifiedChatToolDefinitions(
    supportsFunctionCalls: activeModel.supportsFunctionCalls,
    enableRagTool: enableRag,
    enableNativeOpenUrlTool:
        (activeWorkspace?.nativeToolsEnabled ?? false) &&
        (activeWorkspace?.nativeOpenUrlEnabled ?? false),
    enableNativeOpenAppTool:
        (activeWorkspace?.nativeToolsEnabled ?? false) &&
        (activeWorkspace?.nativeOpenAppEnabled ?? false),
    enableNativePhoneCallTool:
        (activeWorkspace?.nativeToolsEnabled ?? false) &&
        (activeWorkspace?.nativeOpenAppEnabled ?? false),
    enableNativeContactsTool:
        (activeWorkspace?.nativeToolsEnabled ?? false) &&
        (activeWorkspace?.nativeOpenAppEnabled ?? false),
    enableNativeSmsTool:
        (activeWorkspace?.nativeToolsEnabled ?? false) &&
        (activeWorkspace?.nativeOpenAppEnabled ?? false),
    enableNativeSendEmailTool:
        (activeWorkspace?.nativeToolsEnabled ?? false) &&
        (activeWorkspace?.nativeSendEmailEnabled ?? false),
    enableNativeFlashlightTool:
        (activeWorkspace?.nativeToolsEnabled ?? false) &&
        (activeWorkspace?.nativeFlashlightEnabled ?? false),
  );

  final storedMessages =
      await (database.select(database.messages)
            ..where((t) => t.chat.equals(chatId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  if (isCancelled()) return;

  PreparedLocalModel? prepared;
  if (activeModel.provider == ModelProviderType.local) {
    prepared = await deps.localModelRuntime.prepare(activeModel);
  }

  final messageWindow = await _resolveMessageWindow(
    deps: deps,
    activeModel: activeModel,
    storedMessages: storedMessages,
    systemInstruction: systemInstruction,
  );
  final messages = buildGenkitMessages(
    systemInstruction: systemInstruction,
    storedMessages: messageWindow.keptMessages,
  );
  final ai = prepared?.ai ?? _buildRemoteGenkit(activeModel);
  final toolResultCollector = ToolResultCollector();
  final stringifyToolResultForGemma4LiteRt =
      shouldStringifyToolResultForGemma4LiteRt(activeModel);
  final toolNames = _registerTools(
    ai: ai,
    toolDefinitions: toolDefinitions,
    database: database,
    chatId: chatId,
    deps: deps,
    workspace: activeWorkspace,
    enableRag: enableRag,
    isCancelled: isCancelled,
    toolResultCollector: toolResultCollector,
    stringifyToolResultForGemma4LiteRt: stringifyToolResultForGemma4LiteRt,
  );

  deps.chatContextWindowCubit.update(
    ChatContextWindowState(
      maxTokens: activeModel.maxTokens,
      reservedOutputTokens: messageWindow.reservedOutputTokens,
      estimatedPromptTokens: messageWindow.promptTokens,
      remainingTokens: messageWindow.remainingTokens,
      compactedMessages: messageWindow.compactedMessages,
    ),
  );

  final responseBuffer = StringBuffer();
  final thinkingBuffer = StringBuffer();

  final stream = ai.generateStream(
    model: _resolveModelRef(activeModel, prepared),
    messages: messages,
    config: resolveModelConfig(activeModel: activeModel),
    toolNames: toolNames.isEmpty ? null : toolNames,
    maxTurns: 5,
  );

  await for (final chunk in stream) {
    if (isCancelled()) return;

    if (chunk.text.isNotEmpty) {
      responseBuffer.write(chunk.text);
      deps.chatDraftResponseCubit.setDraft(responseBuffer.toString());
    }

    final reasoningDelta = extractReasoning(chunk.content);
    if (reasoningDelta.isNotEmpty) {
      thinkingBuffer.write(reasoningDelta);
      deps.chatDraftThinkingCubit.setDraft(thinkingBuffer.toString());
    }
  }

  if (isCancelled()) return;

  final result = await stream.onResult;
  var finalText = result.text.trim();
  if (finalText.isEmpty && toolResultCollector.hasEntries) {
    finalText = toolResultCollector.buildAssistantFallback();
  }
  if (finalText.isEmpty) {
    throw StateError('Model returned no final assistant text.');
  }

  if (responseBuffer.toString().trim() != finalText) {
    responseBuffer
      ..clear()
      ..write(finalText);
    deps.chatDraftResponseCubit.setDraft(responseBuffer.toString());
  }

  final thinkingText = thinkingBuffer.toString().trim();
  if (thinkingText.isNotEmpty) {
    await database
        .into(database.messages)
        .insert(
          db.MessagesCompanion.insert(
            chat: chatId,
            role: 'assistant',
            kind: const Value('thinking'),
            content: thinkingText,
          ),
        );
  }

  if (isCancelled()) return;

  await database
      .into(database.messages)
      .insert(
        db.MessagesCompanion.insert(
          chat: chatId,
          role: 'assistant',
          kind: const Value('text'),
          content: finalText,
        ),
      );
}

Genkit _buildRemoteGenkit(ModelInfo model) {
  final baseUrl = normalizeBaseUrl((model.apiUrl ?? '').trim());
  final apiToken = normalizeApiKey((model.apiToken ?? '').trim());
  return Genkit(
    plugins: [
      openAI(
        name: _remoteNamespace,
        apiKey: apiToken.isEmpty ? 'local-api-key' : apiToken,
        baseUrl: baseUrl,
        models: [CustomModelDefinition(name: resolveRemoteModelId(model))],
      ),
    ],
  );
}

Future<StoredContextWindowPlan> _resolveMessageWindow({
  required ChatRuntimeDependencies deps,
  required ModelInfo activeModel,
  required List<db.Message> storedMessages,
  required String systemInstruction,
}) async {
  if (activeModel.provider != ModelProviderType.local) {
    return _defaultMessageWindowPlan(
      storedMessages: storedMessages,
      maxTokens: activeModel.maxTokens,
      tokenBuffer: activeModel.tokenBuffer,
    );
  }

  final countTokens = deps.localModelRuntime.countTokens;
  final systemTokens = await _estimateSystemInstructionTokens(
    countTokens,
    systemInstruction,
  );

  return planStoredMessagesWindow(
    countTokens: countTokens,
    storedMessages: storedMessages,
    settingsMaxTokens: activeModel.maxTokens,
    requestedOutputReserve: activeModel.tokenBuffer,
    minMessagesToKeep: 1,
    extraPromptTokens: systemTokens,
  );
}

Future<int> _estimateSystemInstructionTokens(
  Future<int> Function(String text) countTokens,
  String systemInstruction,
) async {
  final trimmed = systemInstruction.trim();
  if (trimmed.isEmpty) return 0;
  return countTokens(trimmed);
}

StoredContextWindowPlan _defaultMessageWindowPlan({
  required List<db.Message> storedMessages,
  required int maxTokens,
  required int tokenBuffer,
}) {
  final reserved = resolveOutputReserve(
    maxTokens: maxTokens,
    requested: tokenBuffer,
  );
  return StoredContextWindowPlan(
    keptMessages: storedMessages,
    promptTokens: 0,
    reservedOutputTokens: reserved,
    remainingTokens: maxTokens - reserved,
    compactedMessages: 0,
  );
}

ModelRef<dynamic> _resolveModelRef(
  ModelInfo model,
  PreparedLocalModel? prepared,
) {
  if (model.provider == ModelProviderType.local) {
    if (prepared == null) {
      throw StateError('Local model runtime was not prepared.');
    }
    return prepared.modelRef;
  }
  return openAI.model(resolveRemoteModelId(model), namespace: _remoteNamespace);
}

List<String> _registerTools({
  required Genkit ai,
  required List<UnifiedChatToolDefinition> toolDefinitions,
  required db.GenaDatabase database,
  required int chatId,
  required ChatRuntimeDependencies deps,
  required WorkspaceEntity? workspace,
  required bool enableRag,
  required bool Function() isCancelled,
  required ToolResultCollector toolResultCollector,
  required bool stringifyToolResultForGemma4LiteRt,
}) {
  final names = <String>[];
  for (final definition in toolDefinitions) {
    final inputSchema = SchemanticType.from<Map<String, dynamic>>(
      jsonSchema: Map<String, Object?>.from(definition.parameters),
      parse: _parseToolInput,
    );

    ai.defineTool<Map<String, dynamic>, Map<String, dynamic>>(
      name: definition.name,
      description: definition.description,
      inputSchema: inputSchema,
      fn: (input, _) async {
        if (isCancelled()) {
          return <String, dynamic>{
            'status': 'cancelled',
            'message': 'Generation was cancelled.',
          };
        }

        deps.chatToolWaitingCubit.setWaitingTool(definition.name);
        try {
          final toolResult = await executeChatToolByName(
            definition.name,
            input,
            ragToolHandler: workspace == null || !enableRag
                ? null
                : (query, {topK = 4, threshold = 0.0}) =>
                      deps.workspaceRagActions.runRagTool(
                        workspaceId: workspace.id,
                        query: query,
                        topK: topK,
                        threshold: threshold,
                      ),
            nativeToolHandler:
                !isNativeToolAllowed(
                  workspace: workspace,
                  toolName: definition.name,
                )
                ? null
                : (toolName, args) => deps.nativeToolActions.requestAndExecute(
                    toolName: toolName,
                    args: args,
                  ),
          );
          logger.i(
            'tool result: ${_formatToolTraceMessage(toolName: definition.name, args: input, result: toolResult)}',
          );

          await database
              .into(database.messages)
              .insert(
                db.MessagesCompanion.insert(
                  chat: chatId,
                  role: 'assistant',
                  kind: const Value('tool_trace'),
                  content: _formatToolTraceMessage(
                    toolName: definition.name,
                    args: input,
                    result: toolResult,
                  ),
                ),
              );

          toolResultCollector.add(
            renderToolResultText(definition.name, toolResult),
          );

          return compactToolResultForModel(
            toolName: definition.name,
            result: toolResult,
            stringifyForGemma4LiteRt: stringifyToolResultForGemma4LiteRt,
          );
        } catch (e) {
          logger.e('tool error: $e');
          return <String, dynamic>{
            'status': 'error',
            'message': 'Tool error: $e',
          };
        } finally {
          deps.chatToolWaitingCubit.clear();
        }
      },
    );

    names.add(definition.name);
  }
  return names;
}

Map<String, dynamic> _parseToolInput(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

String _formatToolTraceMessage({
  required String toolName,
  required Map<String, dynamic> args,
  required Map<String, dynamic> result,
}) {
  final payload = <String, dynamic>{
    'call': <String, dynamic>{'name': toolName, 'args': args},
    'result': result,
  };
  const encoder = JsonEncoder.withIndent('  ');
  return 'Function trace\n${encoder.convert(payload)}';
}
