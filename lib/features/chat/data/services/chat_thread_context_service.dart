import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:gena/core/database/gena_database.dart' as db;

class ContextWindowPlan {
  final List<gemma.Message> replayHistory;
  final int promptTokens;
  final int reservedOutputTokens;
  final int remainingTokens;
  final int compactedMessages;

  const ContextWindowPlan({
    required this.replayHistory,
    required this.promptTokens,
    required this.reservedOutputTokens,
    required this.remainingTokens,
    required this.compactedMessages,
  });
}

class _ReplayEntry {
  final gemma.Message message;
  final int tokens;

  const _ReplayEntry({required this.message, required this.tokens});
}

Future<ContextWindowPlan> planContextWindow({
  required gemma.InferenceChat chat,
  required List<db.Message> storedMessages,
  required int settingsMaxTokens,
  required int requestedOutputReserve,
}) async {
  final reservedOutputTokens = resolveOutputReserve(
    maxTokens: settingsMaxTokens,
    requested: requestedOutputReserve,
  );
  final promptBudget = math.max(1, settingsMaxTokens - reservedOutputTokens);

  final entries = <_ReplayEntry>[];
  for (final row in storedMessages) {
    final message = await toReplayMessage(row);
    if (message == null) continue;
    final tokens = await estimateTokens(chat: chat, message: message);
    entries.add(_ReplayEntry(message: message, tokens: tokens));
  }

  var totalPromptTokens = entries.fold<int>(0, (sum, e) => sum + e.tokens);
  var compactedMessages = 0;
  const minMessagesToKeep = 2;

  while (totalPromptTokens > promptBudget &&
      entries.length > minMessagesToKeep) {
    final removed = entries.removeAt(0);
    totalPromptTokens -= removed.tokens;
    compactedMessages += 1;
  }

  final replayHistory = entries.map((e) => e.message).toList(growable: false);
  final remainingTokens = math.max(0, settingsMaxTokens - totalPromptTokens);

  return ContextWindowPlan(
    replayHistory: replayHistory,
    promptTokens: totalPromptTokens,
    reservedOutputTokens: reservedOutputTokens,
    remainingTokens: remainingTokens,
    compactedMessages: compactedMessages,
  );
}

int resolveOutputReserve({required int maxTokens, required int requested}) {
  if (maxTokens <= 2) return 1;
  return requested.clamp(1, maxTokens - 1);
}

Future<gemma.Message> buildUserMessage({
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
  return gemma.Message.withImage(text: text, imageBytes: bytes, isUser: true);
}

Future<gemma.Message?> toReplayMessage(db.Message row) async {
  if (!_isContextMessage(row)) {
    return null;
  }
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

  return gemma.Message.text(text: row.content, isUser: row.role == 'user');
}

bool _isContextMessage(db.Message row) {
  final isConversationRole = row.role == 'user' || row.role == 'assistant';
  final isConversationKind = row.kind == 'text' || row.kind == 'image';
  return isConversationRole && isConversationKind;
}

Future<int> estimateTokens({
  required gemma.InferenceChat chat,
  required gemma.Message message,
}) async {
  var total = 0;
  final text = message.text.trim();
  if (text.isNotEmpty) {
    try {
      total += await chat.session.sizeInTokens(text);
    } catch (_) {
      total += fallbackTokenEstimate(text);
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

int fallbackTokenEstimate(String text) {
  return math.max(1, (text.length / 4).ceil());
}

bool supportsThinkingModel(gemma.ModelType modelType) {
  return switch (modelType) {
    gemma.ModelType.deepSeek => true,
    gemma.ModelType.qwen => true,
    gemma.ModelType.qwen3 => true,
    gemma.ModelType.gemmaIt => true,
    gemma.ModelType.gemma4 => true,
    _ => false,
  };
}
