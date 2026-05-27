import 'dart:async';

import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/chat/data/models/chat_entity.dart';
import 'package:gena/features/workspace/data/cubits/selected_workspace_cubit.dart';
import 'package:gena/features/workspace/data/models/workspace_chat_group.dart';
import 'package:gena/features/workspace/data/models/workspace_entity.dart';

class WorkspaceQueries {
  WorkspaceQueries({
    required db.GenaDatabase database,
    required SelectedWorkspaceCubit selectedWorkspaceCubit,
  }) : _database = database,
       _selectedWorkspaceCubit = selectedWorkspaceCubit;

  final db.GenaDatabase _database;
  final SelectedWorkspaceCubit _selectedWorkspaceCubit;

  Stream<List<WorkspaceEntity>> watchWorkspaceList() {
    final query = _database.select(_database.workspaces)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => WorkspaceEntity(
              id: row.id.toString(),
              name: row.name,
              generalInstruction: row.generalInstruction,
              ragEnabled: row.ragEnabled,
              nativeToolsEnabled: row.nativeToolsEnabled,
              nativeOpenUrlEnabled: row.nativeOpenUrlEnabled,
              nativeOpenAppEnabled: row.nativeOpenAppEnabled,
              nativeSendEmailEnabled: row.nativeSendEmailEnabled,
              nativeFlashlightEnabled: row.nativeFlashlightEnabled,
              createdAt: row.createdAt,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<WorkspaceEntity?> resolveActiveWorkspace({
    List<WorkspaceEntity>? loadedWorkspaces,
  }) async {
    final selectedWorkspaceId = _selectedWorkspaceCubit.state;
    if (selectedWorkspaceId == null) return null;

    if (loadedWorkspaces != null) {
      for (final workspace in loadedWorkspaces) {
        if (workspace.id == selectedWorkspaceId) {
          return workspace;
        }
      }
    }

    final parsedWorkspaceId = int.tryParse(selectedWorkspaceId);
    if (parsedWorkspaceId == null) return null;

    final row =
        await (_database.select(_database.workspaces)
              ..where((t) => t.id.equals(parsedWorkspaceId))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;

    return WorkspaceEntity(
      id: row.id.toString(),
      name: row.name,
      generalInstruction: row.generalInstruction,
      ragEnabled: row.ragEnabled,
      nativeToolsEnabled: row.nativeToolsEnabled,
      nativeOpenUrlEnabled: row.nativeOpenUrlEnabled,
      nativeOpenAppEnabled: row.nativeOpenAppEnabled,
      nativeSendEmailEnabled: row.nativeSendEmailEnabled,
      nativeFlashlightEnabled: row.nativeFlashlightEnabled,
      createdAt: row.createdAt,
    );
  }

  Stream<List<WorkspaceChatGroup>> watchWorkspaceChatGroups() {
    final joinQuery = _database.select(_database.workspaces).join([
      leftOuterJoin(
        _database.chats,
        _database.chats.workspace.equalsExp(_database.workspaces.id),
      ),
    ])
      ..orderBy([
        OrderingTerm.asc(_database.workspaces.createdAt),
        OrderingTerm.desc(_database.chats.createdAt),
      ]);

    return joinQuery.watch().map((rows) {
      final grouped = <int, WorkspaceChatGroup>{};

      for (final row in rows) {
        final workspaceRow = row.readTable(_database.workspaces);
        final workspaceId = workspaceRow.id;
        final currentGroup = grouped[workspaceId];

        final workspace = WorkspaceEntity(
          id: workspaceRow.id.toString(),
          name: workspaceRow.name,
          generalInstruction: workspaceRow.generalInstruction,
          ragEnabled: workspaceRow.ragEnabled,
          nativeToolsEnabled: workspaceRow.nativeToolsEnabled,
          nativeOpenUrlEnabled: workspaceRow.nativeOpenUrlEnabled,
          nativeOpenAppEnabled: workspaceRow.nativeOpenAppEnabled,
          nativeSendEmailEnabled: workspaceRow.nativeSendEmailEnabled,
          nativeFlashlightEnabled: workspaceRow.nativeFlashlightEnabled,
          createdAt: workspaceRow.createdAt,
        );

        if (currentGroup == null) {
          grouped[workspaceId] = WorkspaceChatGroup(
            workspace: workspace,
            chats: <ChatEntity>[],
          );
        }

        final chatRow = row.readTableOrNull(_database.chats);
        if (chatRow == null) continue;

        grouped[workspaceId]!.chats.add(
          ChatEntity(
            id: chatRow.id.toString(),
            workspaceId: chatRow.workspace.toString(),
            title: chatRow.title,
            createdAt: chatRow.createdAt,
            updatedAt: chatRow.createdAt,
          ),
        );
      }

      return grouped.values.toList(growable: false);
    });
  }

  Stream<WorkspaceEntity?> watchActiveWorkspace() {
    late final StreamController<WorkspaceEntity?> controller;
    StreamSubscription<List<WorkspaceEntity>>? listSub;
    StreamSubscription<String?>? selectedSub;
    List<WorkspaceEntity> cached = const <WorkspaceEntity>[];

    Future<void> emitCurrent() async {
      final current = await resolveActiveWorkspace(loadedWorkspaces: cached);
      if (!controller.isClosed) {
        controller.add(current);
      }
    }

    controller = StreamController<WorkspaceEntity?>.broadcast(
      onListen: () {
        listSub = watchWorkspaceList().listen((items) {
          cached = items;
          unawaited(emitCurrent());
        });
        selectedSub = _selectedWorkspaceCubit.stream.listen((_) {
          unawaited(emitCurrent());
        });
        unawaited(emitCurrent());
      },
      onCancel: () async {
        await listSub?.cancel();
        await selectedSub?.cancel();
      },
    );

    return controller.stream;
  }
}
