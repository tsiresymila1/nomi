import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/chat/data/cubits/selected_chat_cubit.dart';
import 'package:gena/features/workspace/data/cubits/selected_workspace_cubit.dart';
import 'package:gena/features/workspace/data/cubits/workspace_drawer_cubit.dart';
import 'package:gena/features/workspace/presentation/services/workspace_rag_ingestion_controller.dart';

class WorkspaceActionException implements Exception {
  const WorkspaceActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WorkspaceLocalChatActions {
  WorkspaceLocalChatActions({
    required db.GenaDatabase database,
    required SelectedWorkspaceCubit selectedWorkspaceCubit,
    required SelectedChatCubit selectedChatCubit,
    required WorkspaceDrawerCubit drawerCubit,
    required WorkspaceRagIngestionController ingestionController,
  }) : _database = database,
       _selectedWorkspaceCubit = selectedWorkspaceCubit,
       _selectedChatCubit = selectedChatCubit,
       _drawerCubit = drawerCubit,
       _ingestionController = ingestionController;

  final db.GenaDatabase _database;
  final SelectedWorkspaceCubit _selectedWorkspaceCubit;
  final SelectedChatCubit _selectedChatCubit;
  final WorkspaceDrawerCubit _drawerCubit;
  final WorkspaceRagIngestionController _ingestionController;

  Future<void> selectWorkspace(String workspaceId) async {
    _selectedWorkspaceCubit.selectWorkspace(workspaceId);
    await _selectedChatCubit.ensureSelectionForWorkspace(workspaceId);
  }

  Future<void> createNewThreadInWorkspace(String workspaceId) async {
    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) {
      throw const WorkspaceActionException('Invalid workspace selected');
    }

    _selectedWorkspaceCubit.selectWorkspace(workspaceId);
    await _selectedChatCubit.createNewThread(workspaceId: workspaceId);
  }

  Future<void> renameWorkspace({
    required String workspaceId,
    required String rawName,
  }) async {
    final parsedId = int.tryParse(workspaceId);
    final name = rawName.trim();
    if (parsedId == null) return;
    if (name.isEmpty) {
      throw const WorkspaceActionException('Workspace name is required');
    }

    await (_database.update(_database.workspaces)
          ..where((t) => t.id.equals(parsedId)))
        .write(db.WorkspacesCompanion(name: Value(name)));
  }

  Future<void> deleteWorkspace(String workspaceId) async {
    final parsedId = int.tryParse(workspaceId);
    if (parsedId == null) return;

    final workspaceCount = await _countAllWorkspaces();
    if (workspaceCount <= 1) {
      throw const WorkspaceActionException(
        'You must keep at least one workspace.',
      );
    }

    final chatsInWorkspace = await (_database.select(
      _database.chats,
    )..where((t) => t.workspace.equals(parsedId))).get();
    final chatIds = chatsInWorkspace.map((chat) => chat.id).toList();

    await _database.transaction(() async {
      if (chatIds.isNotEmpty) {
        await (_database.delete(
          _database.messages,
        )..where((t) => t.chat.isIn(chatIds))).go();
      }
      await (_database.delete(
        _database.chats,
      )..where((t) => t.workspace.equals(parsedId))).go();
      await (_database.delete(
        _database.workspaceDocuments,
      )..where((t) => t.workspace.equals(parsedId))).go();
      await (_database.delete(
        _database.workspaces,
      )..where((t) => t.id.equals(parsedId))).go();
    });

    await _ingestionController.rebuildReadyIndex();
    _drawerCubit.remove(workspaceId);

    if (_selectedWorkspaceCubit.state == workspaceId) {
      final fallbackWorkspace =
          await (_database.select(_database.workspaces)
                ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
                ..limit(1))
              .getSingleOrNull();
      _selectedWorkspaceCubit.selectWorkspace(fallbackWorkspace?.id.toString());
    }
  }

  Future<int> _countAllWorkspaces() async {
    return _database
        .customSelect('SELECT COUNT(*) AS c FROM workspaces')
        .getSingle()
        .then((row) => row.read<int>('c'));
  }
}
