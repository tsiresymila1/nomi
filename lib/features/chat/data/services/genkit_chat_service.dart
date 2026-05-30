import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/chat/data/cubits/chat_ui_cubits.dart';
import 'package:gena/features/chat/data/services/chat_runtime_dependencies.dart';
import 'package:gena/features/chat/data/services/chat_session_runtime_service.dart';
import 'package:gena/features/chat/data/tools/chat_tools.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/workspace/data/models/workspace_entity.dart';
import 'package:genkit/genkit.dart' hide ModelInfo;
import 'package:genkit_flutter_gemma/genkit_flutter_gemma.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:schemantic/schemantic.dart';

const String _localModelName = 'active-local-model';
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
  final toolDefinitions = buildUnifiedChatToolDefinitions(
    supportsFunctionCalls: activeModel.supportsFunctionCalls,
    enableRagTool: activeWorkspace?.ragEnabled ?? false,
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

  final messages = _buildGenkitMessages(
    systemInstruction: systemInstruction,
    storedMessages: storedMessages,
  );
  final ai = _buildGenkit(activeModel);
  final toolNames = _registerTools(
    ai: ai,
    toolDefinitions: toolDefinitions,
    database: database,
    chatId: chatId,
    deps: deps,
    workspace: activeWorkspace,
    isCancelled: isCancelled,
  );

  _updateContextWindowEstimate(
    deps.chatContextWindowCubit,
    maxTokens: activeModel.maxTokens,
    tokenBuffer: activeModel.tokenBuffer,
  );

  final responseBuffer = StringBuffer();
  final thinkingBuffer = StringBuffer();

  final stream = ai.generateStream(
    model: _resolveModelRef(activeModel),
    messages: messages,
    config: _resolveModelConfig(
      activeModel: activeModel,
      systemInstruction: systemInstruction,
    ),
    toolNames: toolNames.isEmpty ? null : toolNames,
    maxTurns: 5,
  );

  await for (final chunk in stream) {
    if (isCancelled()) return;

    if (chunk.text.isNotEmpty) {
      responseBuffer.write(chunk.text);
      deps.chatDraftResponseCubit.setDraft(responseBuffer.toString());
    }

    final reasoningDelta = _extractReasoning(chunk.content);
    if (reasoningDelta.isNotEmpty) {
      thinkingBuffer.write(reasoningDelta);
      deps.chatDraftThinkingCubit.setDraft(thinkingBuffer.toString());
    }
  }

  if (isCancelled()) return;

  final result = await stream.onResult;
  final finalText = result.text.trim();
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

Genkit _buildGenkit(ModelInfo model) {
  if (model.provider == ModelProviderType.local) {
    return Genkit(
      plugins: [
        GenkitFlutterGemmaPlugin(
          models: [
            FlutterGemmaModelConfig(
              name: _localModelName,
              modelType: parseModelType(model.modelType),
            ),
          ],
        ),
      ],
    );
  }

  final baseUrl = _normalizeBaseUrl((model.apiUrl ?? '').trim());
  final apiToken = _normalizeApiKey((model.apiToken ?? '').trim());
  return Genkit(
    plugins: [
      openAI(
        name: _remoteNamespace,
        apiKey: apiToken.isEmpty ? 'local-api-key' : apiToken,
        baseUrl: baseUrl,
        models: [CustomModelDefinition(name: _resolveRemoteModelId(model))],
      ),
    ],
  );
}

ModelRef<dynamic> _resolveModelRef(ModelInfo model) {
  if (model.provider == ModelProviderType.local) {
    return flutterGemma.model(_localModelName);
  }
  return openAI.model(
    _resolveRemoteModelId(model),
    namespace: _remoteNamespace,
  );
}

Object _resolveModelConfig({
  required ModelInfo activeModel,
  required String systemInstruction,
}) {
  if (activeModel.provider == ModelProviderType.local) {
    return FlutterGemmaModelOptions(
      maxTokens: activeModel.maxTokens,
      temperature: activeModel.temperature,
      topK: activeModel.topK,
      topP: activeModel.topP,
      supportImage: activeModel.supportImage,
      supportAudio: activeModel.supportAudio,
      isThinking: activeModel.isThinking,
      randomSeed: activeModel.randomSeed,
      toolChoice: activeModel.supportsFunctionCalls ? 'auto' : 'none',
      systemInstruction: systemInstruction,
    );
  }

  return OpenAIChatOptions(
    temperature: activeModel.temperature,
    topP: activeModel.topP,
    maxTokens: activeModel.tokenBuffer,
    seed: activeModel.randomSeed,
  );
}

List<String> _registerTools({
  required Genkit ai,
  required List<UnifiedChatToolDefinition> toolDefinitions,
  required db.GenaDatabase database,
  required int chatId,
  required ChatRuntimeDependencies deps,
  required WorkspaceEntity? workspace,
  required bool Function() isCancelled,
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
            ragToolHandler: workspace == null
                ? null
                : (query, {topK = 4, threshold = 0.15}) =>
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

          return _compactToolResultForModel(
            toolName: definition.name,
            result: toolResult,
          );
        } finally {
          deps.chatToolWaitingCubit.clear();
        }
      },
    );

    names.add(definition.name);
  }
  return names;
}

List<Message> _buildGenkitMessages({
  required String systemInstruction,
  required List<db.Message> storedMessages,
}) {
  final messages = <Message>[];

  final trimmedSystem = systemInstruction.trim();
  if (trimmedSystem.isNotEmpty) {
    messages.add(
      Message(
        role: Role.system,
        content: [TextPart(text: trimmedSystem)],
      ),
    );
  }

  for (final message in storedMessages) {
    if (message.role == 'user') {
      final content = <Part>[];
      final text = message.content.trim();
      if (text.isNotEmpty) {
        content.add(TextPart(text: text));
      }

      if (message.kind == 'image') {
        final mediaPath = (message.mediaPath ?? '').trim();
        if (mediaPath.isNotEmpty) {
          final mediaUri = Uri.file(mediaPath).toString();
          content.add(
            MediaPart(
              media: Media(contentType: 'image/*', url: mediaUri),
            ),
          );
        }
      }

      if (content.isEmpty) continue;
      messages.add(Message(role: Role.user, content: content));
      continue;
    }

    if (message.role == 'assistant' && message.kind == 'text') {
      final text = message.content.trim();
      if (text.isEmpty) continue;
      messages.add(
        Message(
          role: Role.model,
          content: [TextPart(text: text)],
        ),
      );
    }
  }

  return messages;
}

Map<String, dynamic> _parseToolInput(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

String _extractReasoning(List<Part> parts) {
  final buffer = StringBuffer();
  for (final part in parts) {
    final json = part.toJson();
    final reasoning = json['reasoning'];
    if (reasoning is String && reasoning.isNotEmpty) {
      buffer.write(reasoning);
    }
  }
  return buffer.toString();
}

String _resolveRemoteModelId(ModelInfo model) {
  final modelId = (model.modelId ?? '').trim();
  if (modelId.isNotEmpty) return modelId;

  final name = model.name.trim();
  if (name.isNotEmpty) return name;

  throw StateError('Remote model id is missing.');
}

String _normalizeApiKey(String apiToken) {
  final trimmed = apiToken.trim();
  if (trimmed.toLowerCase().startsWith('bearer ')) {
    return trimmed.substring(7).trim();
  }
  return trimmed;
}

String _normalizeBaseUrl(String input) {
  if (input.isEmpty) {
    throw StateError('Remote model is missing API URL.');
  }

  final uri = Uri.tryParse(input);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    throw StateError('Invalid API URL: $input');
  }

  var normalized = input.replaceAll(RegExp(r'/+$'), '');
  if (normalized.endsWith('/chat/completions')) {
    normalized = normalized.substring(0, normalized.length - 17);
  }

  if (normalized.isEmpty) {
    throw StateError('Invalid API URL: $input');
  }

  return normalized;
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

Map<String, dynamic> _compactToolResultForModel({
  required String toolName,
  required Map<String, dynamic> result,
}) {
  if (toolName == webSearchToolName) {
    return _compactWebSearchResult(result);
  }
  return _sanitizeMap(
    result,
    maxDepth: 5,
    maxStringChars: 1200,
    maxMapEntries: 24,
    maxListItems: 12,
  );
}

Map<String, dynamic> _compactWebSearchResult(Map<String, dynamic> result) {
  final output = Map<String, dynamic>.from(result);
  final rawData = result['data'];
  if (rawData is List) {
    final compactItems = <Map<String, dynamic>>[];
    for (final entry in rawData.take(5)) {
      if (entry is! Map) continue;
      final source = entry.map((key, value) => MapEntry(key.toString(), value));
      compactItems.add(<String, dynamic>{
        if (source['title'] != null) 'title': source['title'],
        if (source['url'] != null) 'url': source['url'],
        if (source['source'] != null) 'source': source['source'],
        if (source['published'] != null) 'published': source['published'],
        if (source['body'] != null)
          'body': _truncate(source['body'].toString(), 360),
      });
    }
    output['data'] = compactItems;
    output['count'] = compactItems.length;
  }

  final summary = result['summary'];
  if (summary is String) {
    output['summary'] = _truncate(summary, 700);
  }

  return output;
}

dynamic _sanitizeMap(
  dynamic input, {
  required int maxDepth,
  required int maxStringChars,
  required int maxMapEntries,
  required int maxListItems,
}) {
  if (input == null || maxDepth <= 0) {
    return input;
  }

  if (input is String) {
    return _truncate(input, maxStringChars);
  }

  if (input is num || input is bool) {
    return input;
  }

  if (input is List) {
    final result = <dynamic>[];
    for (final value in input.take(maxListItems)) {
      result.add(
        _sanitizeMap(
          value,
          maxDepth: maxDepth - 1,
          maxStringChars: maxStringChars,
          maxMapEntries: maxMapEntries,
          maxListItems: maxListItems,
        ),
      );
    }
    if (input.length > maxListItems) {
      result.add('...(${input.length - maxListItems} more item(s))');
    }
    return result;
  }

  if (input is Map) {
    final output = <String, dynamic>{};
    var count = 0;
    for (final entry in input.entries) {
      if (count >= maxMapEntries) {
        output['__truncated__'] =
            '${input.length - maxMapEntries} more key(s) omitted';
        break;
      }
      output[entry.key.toString()] = _sanitizeMap(
        entry.value,
        maxDepth: maxDepth - 1,
        maxStringChars: maxStringChars,
        maxMapEntries: maxMapEntries,
        maxListItems: maxListItems,
      );
      count++;
    }
    return output;
  }

  return _truncate(input.toString(), maxStringChars);
}

String _truncate(String value, int maxLength) {
  if (value.length <= maxLength) return value;
  return '${value.substring(0, maxLength)}...';
}

void _updateContextWindowEstimate(
  ChatContextWindowCubit contextWindowCubit, {
  required int maxTokens,
  required int tokenBuffer,
}) {
  final reserved = tokenBuffer.clamp(0, maxTokens);
  contextWindowCubit.update(
    ChatContextWindowState(
      maxTokens: maxTokens,
      reservedOutputTokens: reserved,
      estimatedPromptTokens: 0,
      remainingTokens: maxTokens - reserved,
      compactedMessages: 0,
    ),
  );
}
