import 'dart:convert';
import 'package:gena/features/chat/data/cubits/chat_ui_cubits.dart';

import 'package:drift/drift.dart';
import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/logger.dart';
import 'package:gena/features/chat/data/models/gemma_chat_session.dart';
import 'package:gena/features/chat/data/services/chat_runtime_dependencies.dart';
import 'package:gena/features/chat/data/services/chat_thread_context_service.dart';
import 'package:gena/features/chat/data/services/chat_thread_streaming_service.dart';
import 'package:gena/features/chat/data/tools/chat_tools.dart';

Future<void> storeUserMessage({
  required db.GenaDatabase database,
  required int chatId,
  required String text,
  required bool hasImage,
  required String? imagePath,
}) async {
  await database
      .into(database.messages)
      .insert(
        db.MessagesCompanion.insert(
          chat: chatId,
          role: 'user',
          content: text,
          kind: Value(hasImage ? 'image' : 'text'),
          mediaPath: hasImage ? Value<String?>(imagePath) : const Value.absent(),
        ),
      );
}

Future<void> updateThreadTitleFromFirstMessage({
  required db.GenaDatabase database,
  required int chatId,
  required String messageText,
  required bool hasImage,
  Future<String?> Function(String messageText, {required bool hasImage})?
  titleGenerator,
}) {
  return _updateThreadTitleFromFirstMessage(
    database: database,
    chatId: chatId,
    messageText: messageText,
    hasImage: hasImage,
    titleGenerator: titleGenerator,
  );
}

Future<void> prepareContext({
  required ChatRuntimeDependencies deps,
  required db.GenaDatabase database,
  required int chatId,
  required gemma.InferenceChat chat,
  required int maxTokens,
  required int tokenBuffer,
  String? overrideLastUserText,
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
    overrideLastUserText: overrideLastUserText,
  );

  deps.chatContextWindowCubit.update(
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

  if (contextPlan.replayHistory.isNotEmpty) {
    await chat.addQueryChunk(contextPlan.replayHistory.last);
  }
}

Future<void> generateAssistantResponse({
  required ChatRuntimeDependencies deps,
  required GemmaChatSession session,
  required gemma.ModelType modelType,
  required bool shouldHandleThinking,
  required db.GenaDatabase database,
  required int chatId,
  bool Function()? isCancelled,
}) async {
  final responseBuffer = StringBuffer();
  final thinkingBuffer = StringBuffer();
  var toolTurns = 0;

  while (true) {
    if (isCancelled?.call() ?? false) return;

    final turnResult = await runStreamingTurn(
      chatDraftResponseCubit: deps.chatDraftResponseCubit,
      chatDraftThinkingCubit: deps.chatDraftThinkingCubit,
      chat: session.chat,
      responseBuffer: responseBuffer,
      thinkingBuffer: thinkingBuffer,
      shouldHandleThinking: shouldHandleThinking,
      modelType: modelType,
      isCancelled: isCancelled,
    );
    if (turnResult.wasCancelled) return;

    if (turnResult.toolCalls.isEmpty) break;
    if (toolTurns++ >= 4) {
      if (responseBuffer.isNotEmpty) responseBuffer.write('\n\n');
      responseBuffer.write(
        'I could not complete the request because too many consecutive tool calls were generated.',
      );
      deps.chatDraftResponseCubit.setDraft(responseBuffer.toString());
      break;
    }

    for (final call in turnResult.toolCalls) {
      if (isCancelled?.call() ?? false) return;
      deps.chatToolWaitingCubit.setWaitingTool(call.name);
      try {
        final activeWorkspace = await deps.workspaceQueries.resolveActiveWorkspace();
        final workspaceId = activeWorkspace?.id;
        final nativeToolAllowed = isNativeToolAllowed(
          workspace: activeWorkspace,
          toolName: call.name,
        );
        final toolResult = await executeChatTool(
          call,
          ragToolHandler: workspaceId == null
              ? null
              : (query, {topK = 4, threshold = 0.15}) => deps.workspaceRagActions
                    .runRagTool(
                      workspaceId: workspaceId,
                      query: query,
                      topK: topK,
                      threshold: threshold,
                    ),
          nativeToolHandler: !nativeToolAllowed
              ? null
              : (toolName, args) => deps.nativeToolActions
                    .requestAndExecute(toolName: toolName, args: args),
        );
        final modelToolResult = _compactToolResultForModel(
          toolName: call.name,
          result: toolResult,
        );
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
          gemma.Message.toolResponse(
            toolName: call.name,
            response: modelToolResult,
          ),
        );
      } finally {
        deps.chatToolWaitingCubit.clear();
      }
    }
  }

  if (isCancelled?.call() ?? false) return;

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
      final source = entry.map(
        (key, value) => MapEntry(key.toString(), value),
      );
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

Future<void> _updateThreadTitleFromFirstMessage({
  required db.GenaDatabase database,
  required int chatId,
  required String messageText,
  required bool hasImage,
  Future<String?> Function(String messageText, {required bool hasImage})?
  titleGenerator,
}) async {
  final normalizedText = messageText.trim();
  if (normalizedText.isEmpty && !hasImage) return;

  final chat =
      await (database.select(database.chats)
            ..where((t) => t.id.equals(chatId))
            ..limit(1))
          .getSingleOrNull();
  if (chat == null) return;
  if (chat.title.trim().toLowerCase() != 'new chat') return;

  var nextTitle = _fallbackTitle(normalizedText, hasImage: hasImage);

  if (titleGenerator != null) {
    try {
      final aiTitle = await titleGenerator(
        normalizedText,
        hasImage: hasImage,
      );
      final normalizedAiTitle = _sanitizeTitle(aiTitle);
      if (normalizedAiTitle != null) {
        nextTitle = normalizedAiTitle;
      }
    } catch (_) {
      // Keep fallback title.
    }
  }

  await (database.update(database.chats)..where((t) => t.id.equals(chatId))).write(
    db.ChatsCompanion(title: Value(nextTitle)),
  );
}

String _fallbackTitle(String messageText, {required bool hasImage}) {
  if (messageText.isEmpty) {
    return hasImage ? 'Image request' : 'New chat';
  }

  final compact = messageText.replaceAll(RegExp(r'\s+'), ' ').trim();
  final withoutPrefix = compact.replaceFirst(
    RegExp(r'^(please|can you|could you)\s+', caseSensitive: false),
    '',
  );
  final candidate = withoutPrefix.isEmpty ? compact : withoutPrefix;

  final words = candidate.split(' ');
  final firstWords = words.take(6).join(' ');
  final clipped = firstWords.length > 32
      ? '${firstWords.substring(0, 32).trim()}...'
      : firstWords;

  if (hasImage) {
    return '${_capitalize(clipped)} (image)';
  }
  return _capitalize(clipped);
}

String? _sanitizeTitle(String? raw) {
  final title = raw?.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (title == null || title.isEmpty) return null;

  var normalized = title;
  if (normalized.startsWith('"') && normalized.endsWith('"')) {
    normalized = normalized.substring(1, normalized.length - 1).trim();
  }
  normalized = normalized.replaceAll(RegExp(r'^[\p{P}\p{S}]+', unicode: true), '');
  normalized = normalized.replaceAll(RegExp(r'[\p{P}\p{S}]+$', unicode: true), '');

  if (normalized.isEmpty) return null;

  final clipped = normalized.length > 32
      ? normalized.substring(0, 32).trim()
      : normalized;
  return _capitalize(clipped);
}

String _capitalize(String input) {
  if (input.isEmpty) return input;
  return '${input[0].toUpperCase()}${input.substring(1)}';
}
