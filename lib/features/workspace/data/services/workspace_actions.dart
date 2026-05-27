import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/prompt.dart';
import 'package:gena/features/chat/data/cubits/selected_chat_cubit.dart';
import 'package:gena/features/workspace/data/cubits/selected_workspace_cubit.dart';
import 'package:gena/features/workspace/data/cubits/workspace_drawer_cubit.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_actions.dart';

class WorkspaceGuardException implements Exception {
  const WorkspaceGuardException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WorkspaceActions {
  WorkspaceActions({
    required db.GenaDatabase database,
    required SelectedWorkspaceCubit selectedWorkspaceCubit,
    required SelectedChatCubit selectedChatCubit,
    required WorkspaceDrawerCubit workspaceDrawerCubit,
    required WorkspaceRagActions workspaceRagActions,
  }) : _database = database,
       _selectedWorkspaceCubit = selectedWorkspaceCubit,
       _selectedChatCubit = selectedChatCubit,
       _workspaceDrawerCubit = workspaceDrawerCubit,
       _workspaceRagActions = workspaceRagActions;

  final db.GenaDatabase _database;
  final SelectedWorkspaceCubit _selectedWorkspaceCubit;
  final SelectedChatCubit _selectedChatCubit;
  final WorkspaceDrawerCubit _workspaceDrawerCubit;
  final WorkspaceRagActions _workspaceRagActions;

  Future<String> createWorkspace(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      throw const WorkspaceGuardException('Workspace name is required');
    }

    final id = await _database
        .into(_database.workspaces)
        .insert(
          db.WorkspacesCompanion.insert(
            name: name,
            generalInstruction: const Value(systemPrompt),
            nativeToolsEnabled: const Value(true),
            nativeOpenUrlEnabled: const Value(true),
            nativeOpenAppEnabled: const Value(true),
            nativeSendEmailEnabled: const Value(true),
            nativeFlashlightEnabled: const Value(true),
          ),
        );

    final workspaceId = id.toString();
    _selectedWorkspaceCubit.selectWorkspace(workspaceId);
    await _selectedChatCubit.ensureSelectionForWorkspace(workspaceId);
    return workspaceId;
  }

  Future<void> renameWorkspace({
    required String workspaceId,
    required String rawName,
  }) async {
    final parsedId = int.tryParse(workspaceId);
    final name = rawName.trim();
    if (parsedId == null) return;
    if (name.isEmpty) {
      throw const WorkspaceGuardException('Workspace name is required');
    }

    await (_database.update(_database.workspaces)
          ..where((t) => t.id.equals(parsedId)))
        .write(db.WorkspacesCompanion(name: Value(name)));
  }

  Future<void> updateGeneralInstruction({
    required String workspaceId,
    required String instruction,
  }) async {
    final parsedId = int.tryParse(workspaceId);
    if (parsedId == null) return;

    await (_database.update(
      _database.workspaces,
    )..where((t) => t.id.equals(parsedId))).write(
      db.WorkspacesCompanion(
        generalInstruction: Value(
          instruction.trim().isEmpty ? systemPrompt : instruction.trim(),
        ),
      ),
    );
  }

  Future<void> updateRagEnabled({
    required String workspaceId,
    required bool enabled,
  }) async {
    final parsedId = int.tryParse(workspaceId);
    if (parsedId == null) return;

    await (_database.update(_database.workspaces)
          ..where((t) => t.id.equals(parsedId)))
        .write(db.WorkspacesCompanion(ragEnabled: Value(enabled)));
  }

  Future<void> updateNativeToolsEnabled({
    required String workspaceId,
    required bool enabled,
  }) async {
    final parsedId = int.tryParse(workspaceId);
    if (parsedId == null) return;

    await (_database.update(_database.workspaces)
          ..where((t) => t.id.equals(parsedId)))
        .write(db.WorkspacesCompanion(nativeToolsEnabled: Value(enabled)));
  }

  Future<void> updateNativeToolPermissions({
    required String workspaceId,
    required bool openUrlEnabled,
    required bool openAppEnabled,
    required bool sendEmailEnabled,
    required bool flashlightEnabled,
  }) async {
    final parsedId = int.tryParse(workspaceId);
    if (parsedId == null) return;

    await (_database.update(
      _database.workspaces,
    )..where((t) => t.id.equals(parsedId))).write(
      db.WorkspacesCompanion(
        nativeOpenUrlEnabled: Value(openUrlEnabled),
        nativeOpenAppEnabled: Value(openAppEnabled),
        nativeSendEmailEnabled: Value(sendEmailEnabled),
        nativeFlashlightEnabled: Value(flashlightEnabled),
      ),
    );
  }

  Future<void> deleteWorkspace(String workspaceId) async {
    final parsedId = int.tryParse(workspaceId);
    if (parsedId == null) return;

    final workspaceCount = await _database.countAllWorkspaces();
    if (workspaceCount <= 1) {
      throw const WorkspaceGuardException(
        'You must keep at least one workspace.',
      );
    }

    final chatsInWorkspace = await (_database.select(
      _database.chats,
    )..where((t) => t.workspace.equals(parsedId))).get();
    final chatIds = chatsInWorkspace.map((chat) => chat.id).toList();

    final selectedChatId = _selectedChatCubit.state;
    final selectedWorkspaceId = _selectedWorkspaceCubit.state;

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

    await _workspaceRagActions.rebuildAllDocumentsIndex();
    _workspaceDrawerCubit.remove(workspaceId);

    if (selectedWorkspaceId == workspaceId) {
      final fallbackWorkspace =
          await (_database.select(_database.workspaces)
                ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
                ..limit(1))
              .getSingleOrNull();
      final fallbackWorkspaceId = fallbackWorkspace?.id.toString();
      _selectedWorkspaceCubit.selectWorkspace(fallbackWorkspaceId);
      if (fallbackWorkspaceId != null) {
        await _selectedChatCubit.ensureSelectionForWorkspace(
          fallbackWorkspaceId,
        );
      }
      return;
    }

    if (selectedChatId != null) {
      final parsedChatId = int.tryParse(selectedChatId);
      if (parsedChatId != null && chatIds.contains(parsedChatId)) {
        final activeWorkspaceId = await _selectedWorkspaceCubit
            .ensureWorkspace();
        await _selectedChatCubit.ensureSelectionForWorkspace(activeWorkspaceId);
      }
    }
  }
}

extension on db.GenaDatabase {
  Future<int> countAllWorkspaces() {
    return customSelect(
      'SELECT COUNT(*) AS c FROM workspaces',
    ).getSingle().then((row) => row.read<int>('c'));
  }
}
