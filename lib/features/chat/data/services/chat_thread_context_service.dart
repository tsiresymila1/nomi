import 'dart:math' as math;

import 'package:gena/core/database/gena_database.dart' as db;

class StoredContextWindowPlan {
  final List<db.Message> keptMessages;
  final int promptTokens;
  final int reservedOutputTokens;
  final int remainingTokens;
  final int compactedMessages;

  const StoredContextWindowPlan({
    required this.keptMessages,
    required this.promptTokens,
    required this.reservedOutputTokens,
    required this.remainingTokens,
    required this.compactedMessages,
  });
}

class _StoredEntry {
  final db.Message row;
  final int tokens;

  const _StoredEntry({required this.row, required this.tokens});
}

/// Plans which stored messages fit within the model context window.
///
/// [countTokens] estimates the token cost of a piece of text. Image and audio
/// attachments add fixed heuristic costs on top of their text content.
Future<StoredContextWindowPlan> planStoredMessagesWindow({
  required Future<int> Function(String text) countTokens,
  required List<db.Message> storedMessages,
  required int settingsMaxTokens,
  required int requestedOutputReserve,
  Map<int, List<db.MessageAttachment>> storedAttachmentsByMessageId = const {},
  int minMessagesToKeep = 1,
  int extraPromptTokens = 0,
}) async {
  final reservedOutputTokens = resolveOutputReserve(
    maxTokens: settingsMaxTokens,
    requested: requestedOutputReserve,
  );
  final promptBudget = math.max(1, settingsMaxTokens - reservedOutputTokens);

  final entries = <_StoredEntry>[];
  for (final row in storedMessages) {
    if (!_isContextMessage(row)) continue;
    entries.add(
      _StoredEntry(
        row: row,
        tokens: await _estimateRowTokens(
          row,
          countTokens,
          storedAttachmentsByMessageId[row.id] ?? const [],
        ),
      ),
    );
  }

  final normalizedMinMessagesToKeep = minMessagesToKeep.clamp(
    0,
    entries.length,
  );
  var totalPromptTokens =
      extraPromptTokens + entries.fold<int>(0, (sum, e) => sum + e.tokens);
  var compactedMessages = 0;

  while (totalPromptTokens > promptBudget &&
      entries.length > normalizedMinMessagesToKeep) {
    final removed = entries.removeAt(0);
    totalPromptTokens -= removed.tokens;
    compactedMessages += 1;
  }

  final remainingTokens = math.max(0, settingsMaxTokens - totalPromptTokens);
  final keptMessages = entries
      .map((entry) => entry.row)
      .toList(growable: false);

  return StoredContextWindowPlan(
    keptMessages: keptMessages,
    promptTokens: totalPromptTokens,
    reservedOutputTokens: reservedOutputTokens,
    remainingTokens: remainingTokens,
    compactedMessages: compactedMessages,
  );
}

Future<int> _estimateRowTokens(
  db.Message row,
  Future<int> Function(String text) countTokens,
  List<db.MessageAttachment> attachments,
) async {
  var total = 0;
  final text = row.content.trim();
  if (text.isNotEmpty) {
    total += await countTokens(text);
  }
  if (row.kind == 'image' && (row.mediaPath ?? '').trim().isNotEmpty) {
    total += 257;
  }
  if (row.kind == 'audio') {
    total += 512;
  }
  for (final attachment in attachments) {
    if (attachment.kind == 'image') {
      total += 257;
      continue;
    }
    if (attachment.kind == 'document') {
      final text = attachment.extractedText?.trim() ?? '';
      if (text.isNotEmpty) total += await countTokens(text);
    }
  }
  return total;
}

bool _isContextMessage(db.Message row) {
  final isConversationRole = row.role == 'user' || row.role == 'assistant';
  final isConversationKind = row.kind == 'text' || row.kind == 'image';
  return isConversationRole && isConversationKind;
}

int resolveOutputReserve({required int maxTokens, required int requested}) {
  if (maxTokens <= 2) return 1;
  return requested.clamp(1, maxTokens - 1);
}
