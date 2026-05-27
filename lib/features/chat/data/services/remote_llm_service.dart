import 'dart:async';

import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:openai_dart/openai_dart.dart';

class RemoteGenerationCancelled implements Exception {
  const RemoteGenerationCancelled();
}

class RemoteChatTurnResult {
  final String generatedText;
  final List<ToolCall> toolCalls;

  const RemoteChatTurnResult({
    required this.generatedText,
    required this.toolCalls,
  });

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
      print("========================");
      print("=== ${event.textDelta} ");
      print("========================");
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
  print('Generated Text: $generatedText');

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
