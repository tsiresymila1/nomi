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
import 'package:gena/features/chat/data/providers/native_tool_actions_provider.dart';
import 'package:gena/features/workspace/data/models/workspace_entity.dart';
import 'package:gena/features/workspace/data/providers/workspace_rag_actions_provider.dart';
import 'package:gena/features/workspace/data/providers/workspace_queries_provider.dart';

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
          mediaPath: hasImage
              ? Value<String?>(imagePath)
              : const Value.absent(),
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
  required Ref ref,
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

  if (contextPlan.replayHistory.isNotEmpty) {
    await chat.addQueryChunk(contextPlan.replayHistory.last);
  }
}

Future<void> generateAssistantResponse({
  required Ref ref,
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
      ref: ref,
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
      ref
          .read(chatDraftResponseProvider.notifier)
          .setDraft(responseBuffer.toString());
      break;
    }

    for (final call in turnResult.toolCalls) {
      if (isCancelled?.call() ?? false) return;
      ref.read(chatToolWaitingProvider.notifier).setWaitingTool(call.name);
      try {
        final activeWorkspace = ref.read(activeWorkspaceProvider);
        final workspaceId = activeWorkspace?.id;
        final nativeToolAllowed = _isNativeToolAllowed(
          workspace: activeWorkspace,
          toolName: call.name,
        );
        final toolResult = await executeChatTool(
          call,
          ragToolHandler: workspaceId == null
              ? null
              : (query, {topK = 4, threshold = 0.15}) => ref
                    .read(workspaceRagActionsProvider)
                    .runRagTool(
                      workspaceId: workspaceId,
                      query: query,
                      topK: topK,
                      threshold: threshold,
                    ),
          nativeToolHandler: !nativeToolAllowed
              ? null
              : (toolName, args) => ref
                    .read(nativeToolActionsProvider)
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
        ref.read(chatToolWaitingProvider.notifier).clear();
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
  final status = (result['status'] ?? '').toString();
  if (status != 'success') {
    return _sanitizeMap(
      result,
      maxDepth: 4,
      maxStringChars: 800,
      maxMapEntries: 16,
      maxListItems: 8,
    );
  }

  final compacted = <String, dynamic>{
    'status': 'success',
    'query': _trimString(result['query']?.toString() ?? '', 220),
    'engine': _trimString(result['engine']?.toString() ?? '', 40),
  };

  final rawResults = result['results'];
  if (rawResults is List) {
    compacted['results'] = rawResults
        .take(4)
        .map((item) {
          if (item is! Map) return null;
          final map = item.map((key, value) => MapEntry(key.toString(), value));
          return <String, dynamic>{
            'title': _trimString((map['title'] ?? '').toString(), 180),
            'url': _trimString((map['url'] ?? '').toString(), 400),
            'snippet': _trimString((map['snippet'] ?? '').toString(), 300),
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  final rawDocuments = result['documents'];
  if (rawDocuments is List) {
    compacted['documents'] = rawDocuments
        .take(2)
        .map((item) {
          if (item is! Map) return null;
          final map = item.map((key, value) => MapEntry(key.toString(), value));
          return <String, dynamic>{
            'title': _trimString((map['title'] ?? '').toString(), 180),
            'url': _trimString((map['url'] ?? '').toString(), 400),
            'content_markdown': _trimString(
              (map['content_markdown'] ?? '').toString(),
              1000,
            ),
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  compacted['truncated_for_model'] = true;
  return compacted;
}

Map<String, dynamic> _sanitizeMap(
  Map<String, dynamic> source, {
  required int maxDepth,
  required int maxStringChars,
  required int maxMapEntries,
  required int maxListItems,
}) {
  final output = <String, dynamic>{};
  var count = 0;
  for (final entry in source.entries) {
    if (count >= maxMapEntries) break;
    output[entry.key] = _sanitizeDynamic(
      entry.value,
      depth: 0,
      maxDepth: maxDepth,
      maxStringChars: maxStringChars,
      maxMapEntries: maxMapEntries,
      maxListItems: maxListItems,
    );
    count += 1;
  }
  return output;
}

Object? _sanitizeDynamic(
  Object? value, {
  required int depth,
  required int maxDepth,
  required int maxStringChars,
  required int maxMapEntries,
  required int maxListItems,
}) {
  if (value == null) return null;
  if (depth >= maxDepth) return '[truncated-depth]';
  if (value is num || value is bool) return value;
  if (value is String) return _trimString(value, maxStringChars);
  if (value is List) {
    return value
        .take(maxListItems)
        .map(
          (item) => _sanitizeDynamic(
            item,
            depth: depth + 1,
            maxDepth: maxDepth,
            maxStringChars: maxStringChars,
            maxMapEntries: maxMapEntries,
            maxListItems: maxListItems,
          ),
        )
        .toList(growable: false);
  }
  if (value is Map) {
    final map = <String, dynamic>{};
    var count = 0;
    for (final entry in value.entries) {
      if (count >= maxMapEntries) break;
      map[entry.key.toString()] = _sanitizeDynamic(
        entry.value,
        depth: depth + 1,
        maxDepth: maxDepth,
        maxStringChars: maxStringChars,
        maxMapEntries: maxMapEntries,
        maxListItems: maxListItems,
      );
      count += 1;
    }
    return map;
  }
  return _trimString(value.toString(), maxStringChars);
}

String _trimString(String input, int maxChars) {
  if (input.length <= maxChars) return input;
  return '${input.substring(0, maxChars)}...[truncated]';
}

Future<void> _updateThreadTitleFromFirstMessage({
  required db.GenaDatabase database,
  required int chatId,
  required String messageText,
  required bool hasImage,
  Future<String?> Function(String messageText, {required bool hasImage})?
  titleGenerator,
}) async {
  final chat = await (database.select(
    database.chats,
  )..where((t) => t.id.equals(chatId))).getSingleOrNull();
  if (chat == null) return;

  const defaultTitles = {'new chat', 'new thread'};
  final normalizedCurrentTitle = chat.title.trim().toLowerCase();
  if (!defaultTitles.contains(normalizedCurrentTitle)) return;

  final userMessageCountExpression = database.messages.id.count();
  final userMessageCountQuery = database.selectOnly(database.messages)
    ..addColumns([userMessageCountExpression])
    ..where(
      database.messages.chat.equals(chatId) &
          database.messages.role.equals('user'),
    );
  final userMessageCountRow = await userMessageCountQuery.getSingle();
  final userMessageCount =
      userMessageCountRow.read(userMessageCountExpression) ?? 0;
  if (userMessageCount != 1) return;

  String? generatedTitle;
  if (titleGenerator != null) {
    try {
      generatedTitle = await titleGenerator(messageText, hasImage: hasImage);
    } catch (_) {
      generatedTitle = null;
    }
  }

  generatedTitle =
      _normalizeGeneratedThreadTitle(generatedTitle) ??
      _buildAutoThreadTitle(messageText: messageText, hasImage: hasImage);
  if (generatedTitle == null) return;

  await (database.update(database.chats)..where((t) => t.id.equals(chatId)))
      .write(db.ChatsCompanion(title: Value(generatedTitle)));
}

String? _buildAutoThreadTitle({
  required String messageText,
  required bool hasImage,
}) {
  final normalized = messageText.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return hasImage ? 'Image chat' : null;
  }

  final withoutTrailingPunctuation = normalized.replaceAll(
    RegExp(r'[\s\.,;:!?-]+$'),
    '',
  );
  final base = withoutTrailingPunctuation.isEmpty
      ? normalized
      : withoutTrailingPunctuation;
  final maxLength = 32;
  if (base.length <= maxLength) {
    return base.length >= 6 ? base : 'Chat: $base';
  }

  final words = base.split(' ');
  final buffer = StringBuffer();
  for (final word in words) {
    final nextLength = buffer.isEmpty
        ? word.length
        : buffer.length + 1 + word.length;
    if (nextLength > maxLength) break;
    if (buffer.isNotEmpty) {
      buffer.write(' ');
    }
    buffer.write(word);
    if (buffer.length >= 28) break;
  }

  final compact = buffer.toString().trim();
  if (compact.length >= 6) return compact;
  return '${base.substring(0, maxLength - 1).trim()}…';
}

String? _normalizeGeneratedThreadTitle(String? raw) {
  if (raw == null) return null;
  var normalized = raw.trim();
  if (normalized.isEmpty) return null;

  normalized = normalized.split('\n').first.trim();
  normalized = normalized.replaceAll(RegExp('^["\'`]+|["\'`]+\$'), '').trim();
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

  if (normalized.length < 6) return null;
  if (normalized.length > 32) {
    normalized = normalized.substring(0, 31).trimRight();
    normalized = '$normalized…';
  }

  return normalized;
}

bool _isNativeToolAllowed({
  required WorkspaceEntity? workspace,
  required String toolName,
}) {
  if (workspace == null) return false;
  if (!workspace.nativeToolsEnabled) return false;
  return switch (toolName) {
    nativeOpenUrlToolName => workspace.nativeOpenUrlEnabled,
    nativeOpenAppToolName => workspace.nativeOpenAppEnabled,
    nativeSendEmailToolName => workspace.nativeSendEmailEnabled,
    nativeFlashlightToolName => workspace.nativeFlashlightEnabled,
    _ => true,
  };
}
