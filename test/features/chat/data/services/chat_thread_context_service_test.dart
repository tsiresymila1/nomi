import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/chat/data/services/chat_thread_context_service.dart';

/// Fake token counter: 1 token per word (whitespace-split), 0 for empty.
Future<int> _wordCount(String text) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).length;
}

db.Message _message({
  required int id,
  required String role,
  required String content,
  String kind = 'text',
  String? mediaPath,
}) {
  return db.Message(
    id: id,
    createdAt: DateTime.fromMillisecondsSinceEpoch(id * 1000),
    chat: 1,
    role: role,
    kind: kind,
    content: content,
    mediaPath: mediaPath,
  );
}

db.MessageAttachment _attachment({
  required int id,
  required int messageId,
  required String kind,
  String? extractedText,
}) {
  return db.MessageAttachment(
    id: id,
    createdAt: DateTime.fromMillisecondsSinceEpoch(id * 1000),
    message: messageId,
    kind: kind,
    name: kind == 'image' ? 'photo.png' : 'notes.txt',
    sourceType: kind == 'image' ? 'png' : 'text',
    path: '/tmp/$id',
    sizeBytes: 10,
    extractedText: extractedText,
  );
}

void main() {
  group('planStoredMessagesWindow', () {
    test('respects output reserve and keeps everything under budget', () async {
      final messages = [
        _message(id: 1, role: 'user', content: 'one two three'),
        _message(id: 2, role: 'assistant', content: 'four five'),
      ];

      final plan = await planStoredMessagesWindow(
        countTokens: _wordCount,
        storedMessages: messages,
        settingsMaxTokens: 100,
        requestedOutputReserve: 30,
      );

      expect(plan.reservedOutputTokens, 30);
      expect(plan.keptMessages.length, 2);
      expect(plan.promptTokens, 5); // 3 + 2 words
      expect(plan.compactedMessages, 0);
      expect(plan.remainingTokens, 100 - 5);
    });

    test('compacts oldest messages when over the prompt budget', () async {
      final messages = [
        _message(id: 1, role: 'user', content: 'a a a a a a'), // 6
        _message(id: 2, role: 'assistant', content: 'b b b b b b'), // 6
        _message(id: 3, role: 'user', content: 'c c c'), // 3
      ];

      // maxTokens 12, reserve 4 -> prompt budget = 8. Total = 15.
      final plan = await planStoredMessagesWindow(
        countTokens: _wordCount,
        storedMessages: messages,
        settingsMaxTokens: 12,
        requestedOutputReserve: 4,
      );

      // Drops oldest (6) -> 9 still > 8, drops next (6) -> 3 <= budget 8.
      expect(plan.compactedMessages, 2);
      expect(plan.keptMessages.length, 1);
      expect(plan.keptMessages.single.id, 3);
      expect(plan.promptTokens, 3);
    });

    test('honors minMessagesToKeep even when still over budget', () async {
      final messages = [
        _message(id: 1, role: 'user', content: 'a a a a'), // 4
        _message(id: 2, role: 'assistant', content: 'b b b b'), // 4
        _message(id: 3, role: 'user', content: 'c c c c'), // 4
      ];

      // Budget far below total; keep at least 2 newest.
      final plan = await planStoredMessagesWindow(
        countTokens: _wordCount,
        storedMessages: messages,
        settingsMaxTokens: 5,
        requestedOutputReserve: 1,
        minMessagesToKeep: 2,
      );

      expect(plan.keptMessages.length, 2);
      expect(plan.keptMessages.map((m) => m.id), [2, 3]);
      expect(plan.compactedMessages, 1);
    });

    test('adds image and audio heuristic token costs', () async {
      final messages = [
        _message(
          id: 1,
          role: 'user',
          content: 'hello',
          kind: 'image',
          mediaPath: '/tmp/pic.png',
        ),
      ];

      final plan = await planStoredMessagesWindow(
        countTokens: _wordCount,
        storedMessages: messages,
        settingsMaxTokens: 5000,
        requestedOutputReserve: 100,
      );

      // 1 word + 257 image tokens.
      expect(plan.promptTokens, 1 + 257);
      expect(plan.keptMessages.length, 1);
    });

    test('counts persisted image and document attachments', () async {
      final message = _message(id: 1, role: 'user', content: 'hello');

      final plan = await planStoredMessagesWindow(
        countTokens: _wordCount,
        storedMessages: [message],
        storedAttachmentsByMessageId: {
          1: [
            _attachment(id: 1, messageId: 1, kind: 'image'),
            _attachment(
              id: 2,
              messageId: 1,
              kind: 'document',
              extractedText: 'one two three',
            ),
          ],
        },
        settingsMaxTokens: 5000,
        requestedOutputReserve: 100,
      );

      expect(plan.promptTokens, 1 + 257 + 3);
    });

    test('extraPromptTokens count toward the prompt budget', () async {
      final messages = [
        _message(id: 1, role: 'user', content: 'one two'), // 2
      ];

      final plan = await planStoredMessagesWindow(
        countTokens: _wordCount,
        storedMessages: messages,
        settingsMaxTokens: 100,
        requestedOutputReserve: 10,
        extraPromptTokens: 50,
      );

      expect(plan.promptTokens, 52);
      expect(plan.remainingTokens, 100 - 52);
    });
  });
}
