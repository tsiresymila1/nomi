import 'dart:async';

import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/chat/data/models/chat_entity.dart';
import 'package:gena/features/workspace/data/cubits/selected_workspace_cubit.dart';
import 'package:gena/features/workspace/data/models/workspace_chat_group.dart';
import 'package:gena/features/workspace/data/models/workspace_entity.dart';

class WorkspaceQueriesService {
  WorkspaceQueriesService({
    required db.GenaDatabase database,
    required SelectedWorkspaceCubit selectedWorkspaceCubit,
  }) : _database = database,
       _selectedWorkspaceCubit = selectedWorkspaceCubit;

  final db.GenaDatabase _database;
  final SelectedWorkspaceCubit _selectedWorkspaceCubit;

  Stream<List<WorkspaceEntity>> watchWorkspaces() {
    final query = _database.select(_database.workspaces)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);

    return query.watch().map(
      (rows) => rows.map(_workspaceFromRow).toList(growable: false),
    );
  }

  Stream<List<WorkspaceChatGroup>> watchWorkspaceChatGroups() {
    final joinQuery = _database.select(_database.workspaces).join([
      leftOuterJoin(
        _database.chats,
        _database.chats.workspace.equalsExp(_database.workspaces.id),
      ),
    ])..orderBy([
      OrderingTerm.asc(_database.workspaces.createdAt),
      OrderingTerm.desc(_database.chats.createdAt),
    ]);

    return joinQuery.watch().map((rows) {
      final grouped = <int, WorkspaceChatGroup>{};

      for (final row in rows) {
        final workspaceRow = row.readTable(_database.workspaces);
        final workspaceId = workspaceRow.id;
        final currentGroup = grouped[workspaceId];
        final workspace = _workspaceFromRow(workspaceRow);

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
    return _selectedWorkspaceCubit.stream.asyncMap(
      (_) => resolveActiveWorkspace(),
    ).asyncMap((workspace) async {
      if (workspace != null) return workspace;
      return resolveActiveWorkspace();
    });
  }

  Future<WorkspaceEntity?> resolveActiveWorkspace() async {
    final selectedWorkspaceId = _selectedWorkspaceCubit.state;
    if (selectedWorkspaceId == null) return null;

    final parsedWorkspaceId = int.tryParse(selectedWorkspaceId);
    if (parsedWorkspaceId == null) return null;

    final row =
        await (_database.select(_database.workspaces)
              ..where((t) => t.id.equals(parsedWorkspaceId))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return _workspaceFromRow(row);
  }

  Future<WorkspaceEntity?> resolveWorkspaceById(String workspaceId) async {
    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) return null;
    final row =
        await (_database.select(_database.workspaces)
              ..where((t) => t.id.equals(parsedWorkspaceId))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return _workspaceFromRow(row);
  }

  WorkspaceEntity _workspaceFromRow(db.Workspace row) {
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
}
