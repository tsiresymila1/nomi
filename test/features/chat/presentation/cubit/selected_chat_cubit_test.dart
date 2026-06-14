import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/chat/presentation/cubit/selected_chat_cubit.dart';
import 'package:gena/features/workspace/presentation/cubit/selected_workspace_cubit.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../../support/in_memory_hydrated_storage.dart';

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

  Future<int> insertWorkspace([String name = 'WS']) {
    return database
        .into(database.workspaces)
        .insert(db.WorkspacesCompanion.insert(name: name));
  }

  Future<int> insertChat(int workspaceId,
      {String title = 'New chat', DateTime? createdAt}) {
    return database.into(database.chats).insert(
          db.ChatsCompanion.insert(
            title: title,
            workspace: workspaceId,
            createdAt:
                createdAt == null ? const Value.absent() : Value(createdAt),
          ),
        );
  }

  test('selects the most recent existing chat for the active workspace',
      () async {
    final workspaceId = await insertWorkspace();
    await insertChat(workspaceId,
        title: 'Older one', createdAt: DateTime(2020));
    final newerChatId = await insertChat(workspaceId,
        title: 'Newer one', createdAt: DateTime(2022));

    final workspaceCubit = SelectedWorkspaceCubit(database);
    addTearDown(workspaceCubit.close);
    await _settle();
    workspaceCubit.selectWorkspace(workspaceId.toString());

    final cubit = SelectedChatCubit(
      database: database,
      selectedWorkspaceCubit: workspaceCubit,
    );
    addTearDown(cubit.close);
    await _settle();

    expect(cubit.state, newerChatId.toString());
  });

  test('creates a new chat when the workspace has none', () async {
    final workspaceId = await insertWorkspace();

    final workspaceCubit = SelectedWorkspaceCubit(database);
    addTearDown(workspaceCubit.close);
    await _settle();
    workspaceCubit.selectWorkspace(workspaceId.toString());

    final cubit = SelectedChatCubit(
      database: database,
      selectedWorkspaceCubit: workspaceCubit,
    );
    addTearDown(cubit.close);
    await _settle();

    expect(cubit.state, isNotNull);
    final chats = await database.select(database.chats).get();
    expect(chats, hasLength(1));
    expect(chats.single.workspace, workspaceId);
    expect(cubit.state, chats.single.id.toString());
  });

  test('keeps a valid current selection when the workspace re-syncs',
      () async {
    final workspaceId = await insertWorkspace();
    final chatId = await insertChat(workspaceId, title: 'Existing chat');

    final workspaceCubit = SelectedWorkspaceCubit(database);
    addTearDown(workspaceCubit.close);
    await _settle();
    workspaceCubit.selectWorkspace(workspaceId.toString());

    final cubit = SelectedChatCubit(
      database: database,
      selectedWorkspaceCubit: workspaceCubit,
    );
    addTearDown(cubit.close);
    await _settle();
    expect(cubit.state, chatId.toString());

    // Re-running selection for the same workspace must not create a new chat.
    await cubit.ensureSelectionForWorkspace(workspaceId.toString());
    final chats = await database.select(database.chats).get();
    expect(chats, hasLength(1));
    expect(cubit.state, chatId.toString());
  });

  test('createNewThread inserts a chat and selects it', () async {
    final workspaceId = await insertWorkspace();

    final workspaceCubit = SelectedWorkspaceCubit(database);
    addTearDown(workspaceCubit.close);
    await _settle();

    final cubit = SelectedChatCubit(
      database: database,
      selectedWorkspaceCubit: workspaceCubit,
    );
    addTearDown(cubit.close);
    await _settle();

    final initialChats = await database.select(database.chats).get();

    final newId = await cubit.createNewThread(
      workspaceId: workspaceId.toString(),
    );
    expect(cubit.state, newId);
    final chats = await database.select(database.chats).get();
    expect(chats.length, initialChats.length + 1);
  });

  test('createNewThread throws on an unparseable workspace id', () async {
    final workspaceCubit = SelectedWorkspaceCubit(database);
    addTearDown(workspaceCubit.close);
    await _settle();

    final cubit = SelectedChatCubit(
      database: database,
      selectedWorkspaceCubit: workspaceCubit,
    );
    addTearDown(cubit.close);
    await _settle();

    expect(
      () => cubit.createNewThread(workspaceId: 'not-a-number'),
      throwsA(isA<StateError>()),
    );
  });

  test('selectChat emits and ignores duplicate selections', () async {
    final workspaceCubit = SelectedWorkspaceCubit(database);
    addTearDown(workspaceCubit.close);
    await _settle();

    final cubit = SelectedChatCubit(
      database: database,
      selectedWorkspaceCubit: workspaceCubit,
    );
    addTearDown(cubit.close);
    await _settle();

    cubit.selectChat('5');
    expect(cubit.state, '5');

    final emitted = <String?>[];
    final sub = cubit.stream.listen(emitted.add);
    addTearDown(sub.cancel);
    cubit.selectChat('5');
    expect(emitted, isEmpty);

    cubit.clearSelection();
    expect(cubit.state, isNull);
  });
}
