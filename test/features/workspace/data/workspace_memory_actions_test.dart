import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/database/gena_database.dart';
import 'package:gena/features/workspace/data/services/workspace_memory_actions.dart';
import 'package:gena/features/workspace/data/workspace_memory_repository.dart';

void main() {
  late GenaDatabase database;
  late WorkspaceMemoryRepository repository;
  late WorkspaceMemoryActions actions;

  setUp(() {
    database = GenaDatabase(NativeDatabase.memory());
    repository = WorkspaceMemoryRepository(database: database);
    actions = WorkspaceMemoryActions(repository: repository);
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

  group('runRememberTool / runForgetTool', () {
    test('remember stores to the active workspace without approval', () async {
      final workspaceId = await createWorkspace('ws');

      final result = await actions.runRememberTool(
        workspaceId: workspaceId,
        content: 'User is named Ada',
      );
      expect(result['status'], 'success');
      expect(result['stored'], isTrue);

      final stored = await repository.listMemories(workspaceId);
      expect(stored.single.content, 'User is named Ada');
    });

    test('forget removes a matching memory', () async {
      final workspaceId = await createWorkspace('ws');
      await actions.runRememberTool(
        workspaceId: workspaceId,
        content: 'Likes tea',
      );

      final result = await actions.runForgetTool(
        workspaceId: workspaceId,
        content: 'likes tea',
      );
      expect(result['status'], 'success');
      expect(result['removed'], 1);
      expect(await repository.listMemories(workspaceId), isEmpty);
    });

    test('remember/forget are scoped to the workspace', () async {
      final wsA = await createWorkspace('A');
      final wsB = await createWorkspace('B');

      await actions.runRememberTool(workspaceId: wsA, content: 'A only');
      final forgetB = await actions.runForgetTool(
        workspaceId: wsB,
        content: 'A only',
      );
      expect(forgetB['removed'], 0);
      expect((await repository.listMemories(wsA)).single.content, 'A only');
    });

    test('empty remember content returns an error', () async {
      final workspaceId = await createWorkspace('ws');
      final result = await actions.runRememberTool(
        workspaceId: workspaceId,
        content: '   ',
      );
      expect(result['status'], 'error');
    });
  });

  group('memory block injection', () {
    test('contains remembered facts newest-first', () async {
      final block = WorkspaceMemoryActions.composeMemoryBlock(
        contents: ['Newest fact', 'Older fact'],
      );
      expect(block, contains(WorkspaceMemoryActions.memoryBlockHeader));
      expect(block, contains('Newest fact'));
      expect(block, contains('Older fact'));
      expect(
        block.indexOf('Newest fact'),
        lessThan(block.indexOf('Older fact')),
      );
    });

    test('returns empty string when there are no facts', () {
      expect(
        WorkspaceMemoryActions.composeMemoryBlock(contents: const []),
        isEmpty,
      );
    });

    test('is bounded by the char budget, keeping the newest', () {
      final long = List<String>.generate(
        50,
        (i) => 'Fact number $i with some padding text to add length',
      );
      const budget = 200;
      final block = WorkspaceMemoryActions.composeMemoryBlock(
        contents: long,
        charBudget: budget,
      );
      expect(block.length, lessThanOrEqualTo(budget));
      // Newest entry (index 0) is kept.
      expect(block, contains('Fact number 0 '));
    });

    test('buildMemoryBlock reads newest-first from the repository', () async {
      final workspaceId = await createWorkspace('ws');
      await database
          .into(database.workspaceMemories)
          .insert(
            WorkspaceMemoriesCompanion.insert(
              workspace: int.parse(workspaceId),
              content: 'older',
              createdAt: Value(DateTime(2026, 1, 1, 0, 0)),
            ),
          );
      await database
          .into(database.workspaceMemories)
          .insert(
            WorkspaceMemoriesCompanion.insert(
              workspace: int.parse(workspaceId),
              content: 'newer',
              createdAt: Value(DateTime(2026, 1, 1, 0, 5)),
            ),
          );

      final block = await actions.buildMemoryBlock(workspaceId: workspaceId);
      expect(block.indexOf('newer'), lessThan(block.indexOf('older')));
    });
  });
}
