import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/logger.dart';
import 'package:gena/features/chat/data/models/gemma_chat_session.dart';
import 'package:gena/features/chat/data/services/chat_thread_context_service.dart';
import 'package:gena/features/chat/data/services/chat_thread_streaming_service.dart';
import 'package:gena/features/chat/data/providers/chat_ui_state_provider.dart';
import 'package:gena/features/chat/data/tools/chat_tools.dart';

Future<void> storeUserMessage({
  required db.GenaDatabase database,
  required int chatId,
  required String text,
  required bool hasImage,
  required String? imagePath,
}) {
  return database
      .into(database.messages)
      .insert(
        db.MessagesCompanion.insert(
          chat: chatId,
          role: 'user',
          content: text,
          kind: Value(hasImage ? 'image' : 'text'),
          mediaPath: hasImage
              ? Value<String?>(imagePath)
              : const Value.absent(),
        ),
      );
}

Future<void> prepareContext({
  required Ref ref,
  required db.GenaDatabase database,
  required int chatId,
  required gemma.InferenceChat chat,
  required int maxTokens,
  required int tokenBuffer,
}) async {
  final storedMessages =
      await (database.select(database.messages)
            ..where((t) => t.chat.equals(chatId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  final contextPlan = await planContextWindow(
    chat: chat,
    storedMessages: storedMessages,
    settingsMaxTokens: maxTokens,
    requestedOutputReserve: tokenBuffer,
  );

  ref
      .read(chatContextWindowProvider.notifier)
      .update(
        ChatContextWindowState(
          maxTokens: maxTokens,
          reservedOutputTokens: contextPlan.reservedOutputTokens,
          estimatedPromptTokens: contextPlan.promptTokens,
          remainingTokens: contextPlan.remainingTokens,
          compactedMessages: contextPlan.compactedMessages,
        ),
      );

  if (contextPlan.compactedMessages > 0) {
    await chat.clearHistory(replayHistory: contextPlan.replayHistory);
    logger.i(
      'Context compacted: removed ${contextPlan.compactedMessages} old message(s). Prompt≈${contextPlan.promptTokens}/$maxTokens, reserve=${contextPlan.reservedOutputTokens}, remaining≈${contextPlan.remainingTokens}',
    );
    return;
  }

  final lastMessage = storedMessages.last;
  final userMessage = await buildUserMessage(
    text: lastMessage.content,
    imagePath: lastMessage.mediaPath,
  );
  await chat.addQueryChunk(userMessage);
}

Future<void> generateAssistantResponse({
  required Ref ref,
  required GemmaChatSession session,
  required gemma.ModelType modelType,
  required bool shouldHandleThinking,
  required db.GenaDatabase database,
  required int chatId,
}) async {
  final responseBuffer = StringBuffer();
  final thinkingBuffer = StringBuffer();
  var toolTurns = 0;

  while (true) {
    final turnResult = await runStreamingTurn(
      ref: ref,
      chat: session.chat,
      responseBuffer: responseBuffer,
      thinkingBuffer: thinkingBuffer,
      shouldHandleThinking: shouldHandleThinking,
      modelType: modelType,
    );

    if (turnResult.toolCalls.isEmpty) break;
    if (toolTurns++ >= 4) {
      if (responseBuffer.isNotEmpty) responseBuffer.write('\n\n');
      responseBuffer.write(
        'I could not complete the request because too many consecutive tool calls were generated.',
      );
      ref
          .read(chatDraftResponseProvider.notifier)
          .setDraft(responseBuffer.toString());
      break;
    }

    for (final call in turnResult.toolCalls) {
      ref.read(chatToolWaitingProvider.notifier).setWaitingTool(call.name);
      try {
        final toolResult = await executeChatTool(call);
        await database
            .into(database.messages)
            .insert(
              db.MessagesCompanion.insert(
                chat: chatId,
                role: 'assistant',
                kind: const Value('tool_trace'),
                content: _formatToolTraceMessage(call, toolResult),
              ),
            );
        await session.chat.addQueryChunk(
          gemma.Message.toolResponse(toolName: call.name, response: toolResult),
        );
      } finally {
        ref.read(chatToolWaitingProvider.notifier).clear();
      }
    }
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

  final responseText = responseBuffer.toString().trim();
  if (responseText.isNotEmpty) {
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
}

String _formatToolTraceMessage(
  gemma.FunctionCallResponse call,
  Map<String, dynamic> result,
) {
  final payload = <String, dynamic>{
    'call': <String, dynamic>{'name': call.name, 'args': call.args},
    'result': result,
  };
  return 'Function trace\n${_toPrettyJson(payload)}';
}

String _toPrettyJson(Map<String, dynamic> payload) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(payload);
}
