import 'dart:math' as math;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/features/chat/data/providers/chat_session_provider.dart';
import 'package:gena/features/chat/data/providers/chat_ui_state_provider.dart';
import 'package:gena/features/chat/data/providers/selected_chat_provider.dart';
import 'package:gena/features/setting/data/providers/chat_model_settings_provider.dart';

final chatThreadActionsProvider = Provider<ChatThreadActions>(
  (ref) => ChatThreadActions(ref),
);

class ChatThreadActions {
  final Ref ref;
  ChatThreadActions(this.ref);

  Future<void> sendMessage(String rawText, {String? imagePath}) async {
    final text = rawText.trim();
    final normalizedImagePath = imagePath?.trim();
    final hasImage =
        normalizedImagePath != null && normalizedImagePath.isNotEmpty;
    if (text.isEmpty && !hasImage) return;

    var chatId = ref.read(selectedChatIdProvider);
    chatId ??= await ref
        .read(selectedChatIdProvider.notifier)
        .createNewThread();

    final parsedChatId = int.tryParse(chatId);
    if (parsedChatId == null) return;

    final session = await ref.read(activeGemmaChatProvider.future);
    if (session == null) return;
    final modelRuntime = await ref.read(activeGemmaModelRuntimeProvider.future);
    if (modelRuntime == null) return;

    final database = ref.read(genaDatabaseProvider);
    final settings = ref.read(chatModelSettingsProvider);
    final effectiveThinking =
        settings.isThinkingOverride ?? modelRuntime.defaultIsThinking;
    final shouldHandleThinking =
        effectiveThinking && _supportsThinkingModel(modelRuntime.modelType);

    await database
        .into(database.messages)
        .insert(
          db.MessagesCompanion.insert(
            chat: parsedChatId,
            role: 'user',
            content: text,
            kind: Value(hasImage ? 'image' : 'text'),
            mediaPath: hasImage
                ? Value<String?>(normalizedImagePath)
                : const Value.absent(),
          ),
        );

    final storedMessages = await (database.select(database.messages)
          ..where((t) => t.chat.equals(parsedChatId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    final contextPlan = await _planContextWindow(
      chat: session.chat,
      storedMessages: storedMessages,
      settingsMaxTokens: settings.maxTokens,
      requestedOutputReserve: settings.tokenBuffer,
    );
    ref.read(chatContextWindowProvider.notifier).update(
          ChatContextWindowState(
            maxTokens: settings.maxTokens,
            reservedOutputTokens: contextPlan.reservedOutputTokens,
            estimatedPromptTokens: contextPlan.promptTokens,
            remainingTokens: contextPlan.remainingTokens,
            compactedMessages: contextPlan.compactedMessages,
          ),
        );

    if (contextPlan.compactedMessages > 0) {
      await session.chat.clearHistory(replayHistory: contextPlan.replayHistory);
      logger.i(
        'Context compacted: removed ${contextPlan.compactedMessages} old message(s). '
        'Prompt≈${contextPlan.promptTokens}/${settings.maxTokens}, reserve=${contextPlan.reservedOutputTokens}, '
        'remaining≈${contextPlan.remainingTokens}',
      );
    } else {
      final userMessage = await _buildUserMessage(
        text: text,
        imagePath: normalizedImagePath,
      );
      await session.chat.addQueryChunk(userMessage);
    }

    ref.read(chatGeneratingProvider.notifier).setGenerating(true);
    ref.read(chatDraftResponseProvider.notifier).setDraft('');
    ref.read(chatDraftThinkingProvider.notifier).clear();

    final responseBuffer = StringBuffer();
    final thinkingBuffer = StringBuffer();
    try {
      await for (final response in session.chat.generateChatResponseAsync()) {
        if (response is gemma.TextResponse) {
          responseBuffer.write(response.token);
          ref
              .read(chatDraftResponseProvider.notifier)
              .setDraft(responseBuffer.toString());
          continue;
        }

        if (response is gemma.ThinkingResponse && shouldHandleThinking) {
          thinkingBuffer.write(response.content);
          ref
              .read(chatDraftThinkingProvider.notifier)
              .setDraft(thinkingBuffer.toString());
        }
      }
    } finally {
      ref.read(chatGeneratingProvider.notifier).setGenerating(false);
    }

    final responseText = responseBuffer.toString().trim();
    if (responseText.isNotEmpty) {
      await database
          .into(database.messages)
          .insert(
            db.MessagesCompanion.insert(
              chat: parsedChatId,
              role: 'assistant',
              kind: const Value('text'),
              content: responseText,
            ),
          );
    }

    ref.read(chatDraftResponseProvider.notifier).clear();
    ref.read(chatDraftThinkingProvider.notifier).clear();
  }

  Future<void> stopGeneration() async {
    final isGenerating = ref.read(chatGeneratingProvider);
    if (!isGenerating) return;

    final session = await ref.read(activeGemmaChatProvider.future);
    if (session == null) return;

    try {
      await session.chat.stopGeneration();
    } finally {
      ref.read(chatGeneratingProvider.notifier).setGenerating(false);
      ref.read(chatDraftThinkingProvider.notifier).clear();
    }
  }

  Future<_ContextWindowPlan> _planContextWindow({
    required gemma.InferenceChat chat,
    required List<db.Message> storedMessages,
    required int settingsMaxTokens,
    required int requestedOutputReserve,
  }) async {
    final reservedOutputTokens = _resolveOutputReserve(
      maxTokens: settingsMaxTokens,
      requested: requestedOutputReserve,
    );
    final promptBudget = math.max(1, settingsMaxTokens - reservedOutputTokens);

    final entries = <_ReplayEntry>[];

    for (final row in storedMessages) {
      final message = await _toReplayMessage(row);
      final tokens = await _estimateTokens(chat: chat, message: message);
      entries.add(_ReplayEntry(message: message, tokens: tokens));
    }

    var totalPromptTokens = entries.fold<int>(0, (sum, e) => sum + e.tokens);
    var compactedMessages = 0;
    const minMessagesToKeep = 2;

    while (totalPromptTokens > promptBudget && entries.length > minMessagesToKeep) {
      final removed = entries.removeAt(0);
      totalPromptTokens -= removed.tokens;
      compactedMessages += 1;
    }

    final replayHistory = entries.map((e) => e.message).toList(growable: false);
    final remainingTokens = math.max(0, settingsMaxTokens - totalPromptTokens);

    return _ContextWindowPlan(
      replayHistory: replayHistory,
      promptTokens: totalPromptTokens,
      reservedOutputTokens: reservedOutputTokens,
      remainingTokens: remainingTokens,
      compactedMessages: compactedMessages,
    );
  }

  int _resolveOutputReserve({
    required int maxTokens,
    required int requested,
  }) {
    if (maxTokens <= 2) return 1;
    return requested.clamp(1, maxTokens - 1);
  }

  Future<gemma.Message> _buildUserMessage({
    required String text,
    String? imagePath,
  }) async {
    if (imagePath == null || imagePath.isEmpty) {
      return gemma.Message.text(text: text, isUser: true);
    }
    final imageFile = File(imagePath);
    final bytes = await imageFile.readAsBytes();
    if (text.isEmpty) {
      return gemma.Message.imageOnly(imageBytes: bytes, isUser: true);
    }
    return gemma.Message.withImage(
      text: text,
      imageBytes: bytes,
      isUser: true,
    );
  }

  Future<gemma.Message> _toReplayMessage(db.Message row) async {
    if (row.kind == 'image' && row.mediaPath != null) {
      final imageFile = File(row.mediaPath!);
      if (await imageFile.exists()) {
        final bytes = await imageFile.readAsBytes();
        final trimmed = row.content.trim();
        if (trimmed.isEmpty) {
          return gemma.Message.imageOnly(
            imageBytes: bytes,
            isUser: row.role == 'user',
          );
        }
        return gemma.Message.withImage(
          text: row.content,
          imageBytes: bytes,
          isUser: row.role == 'user',
        );
      }
    }

    return gemma.Message.text(
      text: row.content,
      isUser: row.role == 'user',
    );
  }

  Future<int> _estimateTokens({
    required gemma.InferenceChat chat,
    required gemma.Message message,
  }) async {
    var total = 0;
    final text = message.text.trim();
    if (text.isNotEmpty) {
      try {
        total += await chat.session.sizeInTokens(text);
      } catch (_) {
        total += _fallbackTokenEstimate(text);
      }
    }
    if (message.hasImage) {
      final imageCount = message.images.isNotEmpty ? message.images.length : 1;
      total += imageCount * 257;
    }
    if (message.hasAudio) {
      total += 512;
    }
    return total;
  }

  int _fallbackTokenEstimate(String text) {
    return math.max(1, (text.length / 4).ceil());
  }

  bool _supportsThinkingModel(gemma.ModelType modelType) {
    return switch (modelType) {
      gemma.ModelType.deepSeek => true,
      gemma.ModelType.qwen => true,
      gemma.ModelType.qwen3 => true,
      gemma.ModelType.gemmaIt => true,
      gemma.ModelType.gemma4 => true,
      _ => false,
    };
  }
}

class _ReplayEntry {
  final gemma.Message message;
  final int tokens;

  const _ReplayEntry({
    required this.message,
    required this.tokens,
  });
}

class _ContextWindowPlan {
  final List<gemma.Message> replayHistory;
  final int promptTokens;
  final int reservedOutputTokens;
  final int remainingTokens;
  final int compactedMessages;

  const _ContextWindowPlan({
    required this.replayHistory,
    required this.promptTokens,
    required this.reservedOutputTokens,
    required this.remainingTokens,
    required this.compactedMessages,
  });
}
