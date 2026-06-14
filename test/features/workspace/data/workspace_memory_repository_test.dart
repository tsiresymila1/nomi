import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/database/gena_database.dart';
import 'package:gena/features/workspace/data/workspace_memory_repository.dart';

void main() {
  late GenaDatabase database;

  setUp(() {
    database = GenaDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<String> createWorkspace(String name) async {
    final id = await database
        .into(database.workspaces)
        .insert(WorkspacesCompanion.insert(name: name));
    return id.toString();
  }

  test('add then list returns the stored memory for the workspace', () async {
    final repository = WorkspaceMemoryRepository(database: database);
    final workspaceId = await createWorkspace('ws');

    final result = await repository.addMemory(
      workspaceId,
      'User prefers dark mode',
    );
    expect(result.status, WorkspaceMemoryAddStatus.stored);
    expect(result.memory?.content, 'User prefers dark mode');

    final memories = await repository.listMemories(workspaceId);
    expect(memories, hasLength(1));
    expect(memories.single.content, 'User prefers dark mode');
    expect(memories.single.workspaceId, workspaceId);
  });

  test('delete removes the stored memory', () async {
    final repository = WorkspaceMemoryRepository(database: database);
    final workspaceId = await createWorkspace('ws');

    final result = await repository.addMemory(workspaceId, 'fact');
    final id = result.memory!.id;

    final removed = await repository.deleteMemory(id);
    expect(removed, 1);
    expect(await repository.listMemories(workspaceId), isEmpty);
  });

  test('deleteByContent matches normalized content', () async {
    final repository = WorkspaceMemoryRepository(database: database);
    final workspaceId = await createWorkspace('ws');

    await repository.addMemory(workspaceId, 'Likes   coffee');

    final removed = await repository.deleteByContent(
      workspaceId,
      'likes coffee',
    );
    expect(removed, 1);
    expect(await repository.listMemories(workspaceId), isEmpty);
  });

  test('dedupes near-identical content (case + whitespace)', () async {
    final repository = WorkspaceMemoryRepository(database: database);
    final workspaceId = await createWorkspace('ws');

    final first = await repository.addMemory(workspaceId, 'Loves hiking');
    expect(first.status, WorkspaceMemoryAddStatus.stored);

    final dup = await repository.addMemory(workspaceId, '  loves   HIKING ');
    expect(dup.status, WorkspaceMemoryAddStatus.duplicate);

    final memories = await repository.listMemories(workspaceId);
    expect(memories, hasLength(1));
  });

  test('cap enforced: oldest trimmed beyond the cap', () async {
    final repository = WorkspaceMemoryRepository(
      database: database,
      maxMemoriesPerWorkspace: 3,
    );
    final workspaceId = await createWorkspace('ws');

    // Insert with deterministic increasing createdAt so ordering is stable.
    for (var i = 0; i < 4; i++) {
      await database
          .into(database.workspaceMemories)
          .insert(
            WorkspaceMemoriesCompanion.insert(
              workspace: int.parse(workspaceId),
              content: 'fact $i',
              createdAt: Value(DateTime(2026, 1, 1, 0, i)),
            ),
          );
    }

    // Adding a 5th triggers cap enforcement, trimming the oldest.
    final result = await repository.addMemory(workspaceId, 'fact newest');
    expect(result.status, WorkspaceMemoryAddStatus.storedWithTrim);

    final memories = await repository.listMemories(workspaceId);
    expect(memories, hasLength(3));
    final contents = memories.map((m) => m.content).toList();
    // Newest-first ordering; oldest 'fact 0' and 'fact 1' trimmed.
    expect(contents, contains('fact newest'));
    expect(contents, isNot(contains('fact 0')));
    expect(contents, isNot(contains('fact 1')));
  });

  test('workspace isolation: memories do not leak across workspaces', () async {
    final repository = WorkspaceMemoryRepository(database: database);
    final wsA = await createWorkspace('A');
    final wsB = await createWorkspace('B');

    await repository.addMemory(wsA, 'A fact');
    await repository.addMemory(wsB, 'B fact');

    final aMemories = await repository.listMemories(wsA);
    final bMemories = await repository.listMemories(wsB);
    expect(aMemories.map((m) => m.content), ['A fact']);
    expect(bMemories.map((m) => m.content), ['B fact']);
  });

  test('watchMemories emits the current list', () async {
    final repository = WorkspaceMemoryRepository(database: database);
    final workspaceId = await createWorkspace('ws');

    final stream = repository.watchMemories(workspaceId);
    await repository.addMemory(workspaceId, 'watched');
    final emitted = await stream.firstWhere((list) => list.isNotEmpty);
    expect(emitted.single.content, 'watched');
  });

  test('empty content is rejected', () async {
    final repository = WorkspaceMemoryRepository(database: database);
    final workspaceId = await createWorkspace('ws');

    final result = await repository.addMemory(workspaceId, '   ');
    expect(result.status, WorkspaceMemoryAddStatus.empty);
    expect(await repository.listMemories(workspaceId), isEmpty);
  });
}
