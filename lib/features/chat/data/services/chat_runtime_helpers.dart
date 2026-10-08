import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/chat/data/models/chat_attachment.dart';

/// Provider-neutral helpers shared by the chat runtime. These are independent
/// of any specific local inference engine.

/// Builds the system instruction, appending current local date context.
String buildSystemInstruction(String basePrompt) {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  const weekdayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final weekday = weekdayNames[now.weekday - 1];
  final dateContext = [
    'CURRENT LOCAL DATE CONTEXT',
    '- Today is $weekday, ${now.year}-$month-$day.',
    '- Local timezone: ${now.timeZoneName}.',
  ].join('\n');

  if (basePrompt.trim().isEmpty) return dateContext;
  return '${basePrompt.trim()}\n\n$dateContext';
}

/// Persists the latest user message (and optional image attachment), returning
/// its exact row ID so retries never need a race-prone "latest message" query.
Future<int> storeUserMessage({
  required db.GenaDatabase database,
  required int chatId,
  required String text,
  required bool hasImage,
  required String? imagePath,
  List<PreparedChatAttachment> attachments = const [],
}) async {
  return database.transaction(() async {
    final messageId = await database
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
    for (final attachment in attachments) {
      await database
          .into(database.messageAttachments)
          .insert(
            db.MessageAttachmentsCompanion.insert(
              message: messageId,
              kind: attachment.kind.name,
              name: attachment.name,
              sourceType: attachment.sourceType,
              path: attachment.appPath,
              sizeBytes: attachment.sizeBytes,
              extractedText: Value(attachment.extractedText),
            ),
          );
    }
    return messageId;
  });
}

/// Generates and stores an AI/fallback title for a brand-new thread.
Future<void> updateThreadTitleFromFirstMessage({
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
      final aiTitle = await titleGenerator(normalizedText, hasImage: hasImage);
      final normalizedAiTitle = _sanitizeTitle(aiTitle);
      if (normalizedAiTitle != null) {
        nextTitle = normalizedAiTitle;
      }
    } catch (_) {
      // Keep fallback title.
    }
  }

  await (database.update(database.chats)..where((t) => t.id.equals(chatId)))
      .write(db.ChatsCompanion(title: Value(nextTitle)));
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
  normalized = normalized.replaceAll(
    RegExp(r'^[\p{P}\p{S}]+', unicode: true),
    '',
  );
  normalized = normalized.replaceAll(
    RegExp(r'[\p{P}\p{S}]+$', unicode: true),
    '',
  );

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
