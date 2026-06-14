import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/database/gena_database.dart';

void main() {
  test('schemaVersion is 16', () {
    final database = GenaDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    expect(database.schemaVersion, 16);
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
}
