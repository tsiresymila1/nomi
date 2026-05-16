import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/features/chat/data/models/chat_entity.dart';
import 'package:gena/features/chat/data/models/message_entity.dart';

final chatListProvider = StreamProvider<List<ChatEntity>>((ref) {
  final database = ref.watch(genaDatabaseProvider);
  final query = database.select(database.chats)
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

  return query.watch().map(
    (rows) => rows
        .map(
          (row) => ChatEntity(
            id: row.id.toString(),
            title: row.title,
            createdAt: row.createdAt,
            updatedAt: row.createdAt,
          ),
        )
        .toList(),
  );
});

final chatMessagesProvider = StreamProvider.family<List<MessageEntity>, String>(
  (ref, chatId) {
    final database = ref.watch(genaDatabaseProvider);
    final parsedChatId = int.tryParse(chatId);
    if (parsedChatId == null) {
      return Stream.value(const <MessageEntity>[]);
    }

    final query = database.select(database.messages)
      ..where((t) => t.chat.equals(parsedChatId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => MessageEntity(
              id: row.id.toString(),
              chatId: row.chat.toString(),
              role: row.role,
              kind: row.kind,
              content: row.content,
              mediaPath: row.mediaPath,
              createdAt: row.createdAt,
            ),
          )
          .toList(),
    );
  },
);
