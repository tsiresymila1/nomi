import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/chat/data/models/chat_entity.dart';
import 'package:gena/features/chat/data/models/message_entity.dart';
import 'package:gena/features/workspace/data/cubits/selected_workspace_cubit.dart';

class ChatQueriesRepository {
  ChatQueriesRepository({
    required db.GenaDatabase database,
    required SelectedWorkspaceCubit selectedWorkspaceCubit,
  }) : _database = database,
       _selectedWorkspaceCubit = selectedWorkspaceCubit;

  final db.GenaDatabase _database;
  final SelectedWorkspaceCubit _selectedWorkspaceCubit;

  Stream<List<ChatEntity>> watchChatList() {
    return _selectedWorkspaceCubit.stream
        .startWith(_selectedWorkspaceCubit.state)
        .asyncExpand((selectedWorkspaceId) {
          final parsedWorkspaceId = int.tryParse(selectedWorkspaceId ?? '');
          if (parsedWorkspaceId == null) {
            return Stream<List<ChatEntity>>.value(const <ChatEntity>[]);
          }

          final query = _database.select(_database.chats)
            ..where((t) => t.workspace.equals(parsedWorkspaceId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

          return query.watch().map(
            (rows) => rows
                .map(
                  (row) => ChatEntity(
                    id: row.id.toString(),
                    workspaceId: row.workspace.toString(),
                    title: row.title,
                    createdAt: row.createdAt,
                    updatedAt: row.createdAt,
                  ),
                )
                .toList(growable: false),
          );
        });
  }

  Stream<List<MessageEntity>> watchChatMessages(String chatId) {
    final parsedChatId = int.tryParse(chatId);
    if (parsedChatId == null) {
      return Stream<List<MessageEntity>>.value(const <MessageEntity>[]);
    }

    final query = _database.select(_database.messages)
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
          .toList(growable: false),
    );
  }
}

extension<T> on Stream<T> {
  Stream<T> startWith(T initial) async* {
    yield initial;
    yield* this;
  }
}
