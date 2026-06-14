import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/workspace/presentation/cubit/selected_workspace_cubit.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../../support/in_memory_hydrated_storage.dart';

/// Waits for the async hydration in the cubit constructor to settle.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late db.GenaDatabase database;

  setUp(() {
    HydratedBloc.storage = InMemoryHydratedStorage();
    database = db.GenaDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('initial hydration', () {
    test('creates a default workspace when none exist', () async {
      final cubit = SelectedWorkspaceCubit(database);
      addTearDown(cubit.close);
      await _settle();

      expect(cubit.state, isNotNull);
      final workspaces = await database.select(database.workspaces).get();
      expect(workspaces, hasLength(1));
      expect(workspaces.single.name, defaultWorkspaceName);
      expect(cubit.state, workspaces.single.id.toString());
    });

    test('selects the earliest existing workspace by createdAt', () async {
      final firstId = await database
          .into(database.workspaces)
          .insert(db.WorkspacesCompanion.insert(
            name: 'First',
            createdAt: Value(DateTime(2020, 1, 1)),
          ));
      await database.into(database.workspaces).insert(
            db.WorkspacesCompanion.insert(
              name: 'Second',
              createdAt: Value(DateTime(2021, 1, 1)),
            ),
          );

      final cubit = SelectedWorkspaceCubit(database);
      addTearDown(cubit.close);
      await _settle();

      expect(cubit.state, firstId.toString());
      // No extra workspace was created.
      final workspaces = await database.select(database.workspaces).get();
      expect(workspaces, hasLength(2));
    });

    test('keeps an already-hydrated selection from storage', () async {
      final storage = InMemoryHydratedStorage();
      HydratedBloc.storage = storage;
      await storage.write(
        'SelectedWorkspaceCubit',
        <String, dynamic>{'workspaceId': '99'},
      );

      final cubit = SelectedWorkspaceCubit(database);
      addTearDown(cubit.close);
      await _settle();

      expect(cubit.state, '99');
      // Nothing is created when a selection is restored.
      final workspaces = await database.select(database.workspaces).get();
      expect(workspaces, isEmpty);
    });
  });

  group('ensureWorkspace', () {
    test('returns existing selection without creating a workspace', () async {
      final existingId = await database.into(database.workspaces).insert(
            db.WorkspacesCompanion.insert(name: 'Existing'),
          );

      final cubit = SelectedWorkspaceCubit(database);
      addTearDown(cubit.close);
      await _settle();

      final result = await cubit.ensureWorkspace();
      expect(result, existingId.toString());
      expect(cubit.state, existingId.toString());
    });
  });

  group('selectWorkspace', () {
    test('emits a new selection', () async {
      final cubit = SelectedWorkspaceCubit(database);
      addTearDown(cubit.close);
      await _settle();

      cubit.selectWorkspace('42');
      expect(cubit.state, '42');
    });

    test('ignores a re-selection of the current workspace', () async {
      final cubit = SelectedWorkspaceCubit(database);
      addTearDown(cubit.close);
      await _settle();
      cubit.selectWorkspace('42');

      final emitted = <String?>[];
      final sub = cubit.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      cubit.selectWorkspace('42');
      expect(emitted, isEmpty);
    });
  });

  group('serialization', () {
    test('toJson omits empty/null selections', () async {
      final cubit = SelectedWorkspaceCubit(database);
      addTearDown(cubit.close);
      await _settle();
      expect(cubit.toJson(null), isEmpty);
      expect(cubit.toJson('   '), isEmpty);
      expect(cubit.toJson('7'), <String, dynamic>{'workspaceId': '7'});
    });

    test('fromJson rejects blank ids', () async {
      final cubit = SelectedWorkspaceCubit(database);
      addTearDown(cubit.close);
      await _settle();
      expect(cubit.fromJson(<String, dynamic>{'workspaceId': '   '}), isNull);
      expect(cubit.fromJson(<String, dynamic>{'workspaceId': null}), isNull);
      expect(cubit.fromJson(<String, dynamic>{'workspaceId': '7'}), '7');
    });
  });
}
