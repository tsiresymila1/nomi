import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/chat/data/repositories/chat_queries_repository.dart';
import 'package:gena/features/workspace/presentation/cubit/selected_workspace_cubit.dart';

class _SelectedWorkspaceCubitFake extends Fake
    implements SelectedWorkspaceCubit {
  @override
  String? get state => null;

  @override
  Stream<String?> get stream => const Stream<String?>.empty();
}

void main() {
  late db.GenaDatabase database;

  setUp(() {
    database = db.GenaDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test(
    'watchChatMessages groups persisted attachments with their message',
    () async {
      final workspaceId = await database
          .into(database.workspaces)
          .insert(db.WorkspacesCompanion.insert(name: 'Workspace'));
      final chatId = await database
          .into(database.chats)
          .insert(
            db.ChatsCompanion.insert(workspace: workspaceId, title: 'New chat'),
          );
      final messageId = await database
          .into(database.messages)
          .insert(
            db.MessagesCompanion.insert(
              chat: chatId,
              role: 'user',
              content: 'Review these files',
            ),
          );
      final workspaceDocumentId = await database
          .into(database.workspaceDocuments)
          .insert(
            db.WorkspaceDocumentsCompanion.insert(
              workspace: workspaceId,
              name: 'notes.txt',
              sourceType: 'text',
              sourcePath: '/private/notes.txt',
              content: 'Notes',
            ),
          );
      await database.batch((batch) {
        batch.insertAll(database.messageAttachments, [
          db.MessageAttachmentsCompanion.insert(
            message: messageId,
            kind: 'image',
            name: 'photo.png',
            sourceType: 'png',
            path: '/private/photo.png',
            sizeBytes: 42,
          ),
          db.MessageAttachmentsCompanion.insert(
            message: messageId,
            kind: 'document',
            name: 'notes.txt',
            sourceType: 'text',
            path: '/private/notes.txt',
            sizeBytes: 84,
            workspaceDocument: Value(workspaceDocumentId),
          ),
        ]);
      });

      final repository = ChatQueriesRepository(
        database: database,
        selectedWorkspaceCubit: _SelectedWorkspaceCubitFake(),
      );
      final messages = await repository.watchChatMessages('$chatId').first;

      expect(messages, hasLength(1));
      expect(messages.single.attachments, hasLength(2));
      expect(
        messages.single.attachments.map((attachment) => attachment.name),
        orderedEquals(['photo.png', 'notes.txt']),
      );
      expect(
        messages.single.attachments.last.workspaceDocumentId,
        workspaceDocumentId,
      );
    },
  );
}
