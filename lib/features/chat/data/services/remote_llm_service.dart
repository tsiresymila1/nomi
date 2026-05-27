import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/logger.dart';
import 'package:gena/features/chat/data/services/chat_runtime_dependencies.dart';
import 'package:gena/features/chat/data/services/chat_session_runtime_service.dart';
import 'package:gena/features/chat/data/tools/chat_tools.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:openai_dart/openai_dart.dart';

class RemoteGenerationCancelled implements Exception {
  const RemoteGenerationCancelled();
}

class RemoteChatTurnResult {
  const RemoteChatTurnResult({
    required this.generatedText,
    required this.toolCalls,
  });

  final String generatedText;
  final List<ToolCall> toolCalls;

  bool get hasToolCalls => toolCalls.isNotEmpty;
}

Future<RemoteChatTurnResult> runRemoteChatTurnStreamed({
  required ModelInfo model,
  required List<ChatMessage> messages,
  List<Tool> tools = const <Tool>[],
  Future<void>? abortTrigger,
  void Function(String delta)? onTextDelta,
}) async {
  final apiUrlRaw = (model.apiUrl ?? '').trim();
  final apiTokenRaw = (model.apiToken ?? '').trim();

  if (apiUrlRaw.isEmpty) {
    throw StateError('Remote model is missing API URL or token.');
  }

  final baseUrl = _normalizeBaseUrl(apiUrlRaw);
  final apiToken = _normalizeApiKey(apiTokenRaw);
  final modelId = _resolveModelId(model);

  final client = OpenAIClient.withApiKey(apiToken, baseUrl: baseUrl);
  final request = ChatCompletionCreateRequest(
    model: modelId,
    messages: messages,
    tools: tools.isEmpty ? null : tools,
    toolChoice: tools.isEmpty ? null : ToolChoice.auto(),
    parallelToolCalls: tools.isEmpty ? null : true,
    temperature: model.temperature,
    topP: model.topP,
    maxTokens: model.tokenBuffer,
  );

  final turnTextBuffer = StringBuffer();
  final accumulator = ChatStreamAccumulator();
  var aborted = false;
  abortTrigger?.then((_) => aborted = true);

  try {
    final stream = client.chat.completions.createStream(
      request,
      abortTrigger: abortTrigger,
    );

    await for (final event in stream) {
      accumulator.add(event);
      final delta = event.textDelta;
      if (delta == null || delta.isEmpty) continue;
      turnTextBuffer.write(delta);
      onTextDelta?.call(delta);
    }
  } finally {
    client.close();
  }

  final completion = accumulator.toChatCompletion();
  final generatedText = turnTextBuffer.toString();
  final toolCalls = completion.allToolCalls;

  if (aborted && generatedText.trim().isEmpty && toolCalls.isEmpty) {
    throw const RemoteGenerationCancelled();
  }

  if (generatedText.trim().isEmpty && toolCalls.isEmpty) {
    throw StateError('Remote API returned neither text nor tool calls.');
  }

  return RemoteChatTurnResult(
    generatedText: generatedText,
    toolCalls: toolCalls,
  );
}

List<ChatMessage> buildRemoteMessagesFromStoredMessages({
  required String systemInstruction,
  required List<db.Message> storedMessages,
}) {
  final messages = <ChatMessage>[];

  final trimmedSystem = systemInstruction.trim();
  if (trimmedSystem.isNotEmpty) {
    messages.add(ChatMessage.system(trimmedSystem));
  }

  for (final message in storedMessages) {
    final role = message.role;
    if (role != 'user' && role != 'assistant') continue;

    final textContent = _messageToTextContent(message);
    if (textContent.isEmpty) continue;

    if (role == 'user') {
      messages.add(ChatMessage.user(textContent));
    } else {
      messages.add(ChatMessage.assistant(content: textContent));
    }
  }

  return messages;
}

String _messageToTextContent(db.Message message) {
  if (message.kind == 'image') {
    final base = message.content.trim();
    return base.isEmpty ? '[Image attached]' : '$base\n\n[Image attached]';
  }

  if (message.kind != 'text') return '';
  return message.content.trim();
}

String _resolveModelId(ModelInfo model) {
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
  final trimmed = input.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    throw StateError('Invalid API URL: $input');
  }

  var normalized = trimmed.replaceAll(RegExp(r'/+$'), '');
  if (normalized.endsWith('/chat/completions')) {
    normalized = normalized.substring(0, normalized.length - 17);
  }

  if (normalized.isEmpty) {
    throw StateError('Invalid API URL: $input');
  }

  return normalized;
}

Future<void> generateRemoteAssistantResponse({
  required ChatRuntimeDependencies deps,
  required db.GenaDatabase database,
  required int chatId,
  required ModelInfo activeModel,
  required Future<void> abortTrigger,
  required bool Function() isCancelled,
}) async {
  final activeWorkspace = await deps.workspaceQueries.resolveActiveWorkspace();
  final basePrompt = activeWorkspace?.generalInstruction.trim() ?? '';
  final systemInstruction = buildSystemInstruction(basePrompt);
  final remoteTools = buildRemoteChatTools(
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

  final remoteMessages = buildRemoteMessagesFromStoredMessages(
    systemInstruction: systemInstruction,
    storedMessages: storedMessages,
  );

  final responseBuffer = StringBuffer();
  var toolTurns = 0;

  while (true) {
    if (isCancelled()) return;

    final turnResult = await runRemoteChatTurnStreamed(
      model: activeModel,
      messages: remoteMessages,
      tools: remoteTools,
      abortTrigger: abortTrigger,
      onTextDelta: (delta) {
        responseBuffer.write(delta);
        deps.chatDraftResponseCubit.setDraft(responseBuffer.toString());
      },
    );

    if (!turnResult.hasToolCalls) {
      break;
    }

    if (toolTurns++ >= 4) {
      if (responseBuffer.isNotEmpty) responseBuffer.write('\n\n');
      responseBuffer.write(
        'I could not complete the request because too many consecutive tool calls were generated.',
      );
      deps.chatDraftResponseCubit.setDraft(responseBuffer.toString());
      break;
    }

    remoteMessages.add(
      ChatMessage.assistant(content: null, toolCalls: turnResult.toolCalls),
    );

    for (final call in turnResult.toolCalls) {
      if (isCancelled()) return;
      deps.chatToolWaitingCubit.setWaitingTool(call.function.name);
      try {
        final parsedArgs = _decodeToolArguments(call.function.arguments);
        final toolResult = await executeChatToolByName(
          call.function.name,
          parsedArgs,
          ragToolHandler: activeWorkspace == null
              ? null
              : (query, {topK = 4, threshold = 0.15}) =>
                    deps.workspaceRagActions.runRagTool(
                      workspaceId: activeWorkspace.id,
                      query: query,
                      topK: topK,
                      threshold: threshold,
                    ),
          nativeToolHandler:
              !isNativeToolAllowed(
                workspace: activeWorkspace,
                toolName: call.function.name,
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
                content: _formatRemoteToolTraceMessage(call, toolResult),
              ),
            );

        remoteMessages.add(
          ChatMessage.tool(
            toolCallId: call.id,
            content: jsonEncode(toolResult),
          ),
        );
      } finally {
        deps.chatToolWaitingCubit.clear();
      }
    }
  }

  final responseText = responseBuffer.toString().trim();
  if (responseText.isEmpty) {
    throw StateError(
      'Remote API returned no final assistant text after tool execution.',
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
          content: responseText,
        ),
      );
}

Map<String, dynamic> _decodeToolArguments(String rawArguments) {
  final decoded = jsonDecode(rawArguments);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

String _formatRemoteToolTraceMessage(
  ToolCall call,
  Map<String, dynamic> result,
) {
  final payload = <String, dynamic>{
    'call': <String, dynamic>{
      'id': call.id,
      'name': call.function.name,
      'args': call.function.arguments,
    },
    'result': result,
  };
  const encoder = JsonEncoder.withIndent('  ');
  return 'Function trace\n${encoder.convert(payload)}';
}
