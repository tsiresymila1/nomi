import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:gena/core/database/gena_database.dart' as db;

Future<void> replayStoredMessages({
  required db.GenaDatabase database,
  required int chatId,
  required gemma.InferenceChat chat,
}) async {
  final storedMessages =
      await (database.select(database.messages)
            ..where(
              (t) =>
                  t.chat.equals(chatId) &
                  t.role.isIn(const <String>['user', 'assistant']) &
                  t.kind.isIn(const <String>['text', 'image']),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  for (final message in storedMessages) {
    if (!_isContextMessage(message)) continue;

    if (message.kind == 'image' && message.mediaPath != null) {
      final imageFile = File(message.mediaPath!);
      if (await imageFile.exists()) {
        final bytes = await imageFile.readAsBytes();
        final text = message.content.trim();
        await chat.addQueryChunk(
          text.isEmpty
              ? gemma.Message.imageOnly(
                  imageBytes: bytes,
                  isUser: message.role == 'user',
                )
              : gemma.Message.withImage(
                  text: text,
                  imageBytes: bytes,
                  isUser: message.role == 'user',
                ),
        );
        continue;
      }
    }

    await chat.addQueryChunk(
      gemma.Message.text(text: message.content, isUser: message.role == 'user'),
    );
  }
}

bool _isContextMessage(db.Message message) {
  final isConversationRole =
      message.role == 'user' || message.role == 'assistant';
  final isConversationKind = message.kind == 'text' || message.kind == 'image';
  return isConversationRole && isConversationKind;
}
