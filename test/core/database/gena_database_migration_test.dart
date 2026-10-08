import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/database/gena_database.dart';

void main() {
  test('schemaVersion is 17', () {
    final database = GenaDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    expect(database.schemaVersion, 17);
  });

  test('fresh database exposes mcp servers table and workspace flag', () async {
    final database = GenaDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    // mcp_servers table is created on a fresh db.
    final id = await database
        .into(database.mcpServers)
        .insert(
          McpServersCompanion.insert(
            name: 'srv',
            url: 'https://example.com/mcp',
          ),
        );
    final row = await (database.select(
      database.mcpServers,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.name, 'srv');
    expect(row.enabled, isTrue);
    expect(row.authHeader, isNull);

    // workspaces.mcp_enabled column exists with a false default.
    final workspaceId = await database
        .into(database.workspaces)
        .insert(WorkspacesCompanion.insert(name: 'ws'));
    final workspace = await (database.select(
      database.workspaces,
    )..where((t) => t.id.equals(workspaceId))).getSingle();
    expect(workspace.mcpEnabled, isFalse);
  });

  test('fresh database exposes workspace memories table and flag', () async {
    final database = GenaDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    // workspaces.memory_enabled column exists with a true default.
    final workspaceId = await database
        .into(database.workspaces)
        .insert(WorkspacesCompanion.insert(name: 'ws'));
    final workspace = await (database.select(
      database.workspaces,
    )..where((t) => t.id.equals(workspaceId))).getSingle();
    expect(workspace.memoryEnabled, isTrue);

    // workspace_memories table is created on a fresh db.
    final memoryId = await database
        .into(database.workspaceMemories)
        .insert(
          WorkspaceMemoriesCompanion.insert(
            workspace: workspaceId,
            content: 'remembered fact',
          ),
        );
    final memory = await (database.select(
      database.workspaceMemories,
    )..where((t) => t.id.equals(memoryId))).getSingle();
    expect(memory.workspace, workspaceId);
    expect(memory.content, 'remembered fact');
  });

  test('fresh database persists typed message attachments', () async {
    final database = GenaDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await database
        .into(database.workspaces)
        .insert(WorkspacesCompanion.insert(name: 'ws'));
    final chatId = await database
        .into(database.chats)
        .insert(
          ChatsCompanion.insert(workspace: workspaceId, title: 'New chat'),
        );
    final messageId = await database
        .into(database.messages)
        .insert(
          MessagesCompanion.insert(
            chat: chatId,
            role: 'user',
            content: 'Review this',
          ),
        );

    final attachmentId = await database
        .into(database.messageAttachments)
        .insert(
          MessageAttachmentsCompanion.insert(
            message: messageId,
            kind: 'document',
            name: 'notes.txt',
            sourceType: 'text',
            path: '/private/notes.txt',
            sizeBytes: 12,
            extractedText: const Value('hello'),
          ),
        );

    final attachment = await (database.select(
      database.messageAttachments,
    )..where((row) => row.id.equals(attachmentId))).getSingle();
    expect(attachment.message, messageId);
    expect(attachment.kind, 'document');
    expect(attachment.extractedText, 'hello');
    expect(attachment.workspaceDocument, isNull);
  });
}
