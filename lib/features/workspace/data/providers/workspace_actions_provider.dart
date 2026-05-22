import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/core/prompt.dart';
import 'package:gena/features/chat/data/providers/selected_chat_provider.dart';
import 'package:gena/features/workspace/data/providers/workspace_rag_actions_provider.dart';
import 'package:gena/features/workspace/data/providers/selected_workspace_provider.dart';
import 'package:gena/features/workspace/data/providers/workspace_drawer_state_provider.dart';

final workspaceActionsProvider = Provider<WorkspaceActions>(
  (ref) => WorkspaceActions(ref),
);

class WorkspaceGuardException implements Exception {
  final String message;
  const WorkspaceGuardException(this.message);

  @override
  String toString() => message;
}

class WorkspaceActions {
  final Ref ref;
  WorkspaceActions(this.ref);

  Future<String> createWorkspace(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      throw const WorkspaceGuardException('Workspace name is required');
    }

    final database = ref.read(genaDatabaseProvider);
    final id = await database
        .into(database.workspaces)
        .insert(
          db.WorkspacesCompanion.insert(
            name: name,
            generalInstruction: const Value(systemPrompt),
          ),
        );

    final workspaceId = id.toString();
    ref.read(selectedWorkspaceIdProvider.notifier).selectWorkspace(workspaceId);
    await ref
        .read(selectedChatIdProvider.notifier)
        .ensureSelectionForWorkspace(workspaceId);
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

    final database = ref.read(genaDatabaseProvider);
    await (database.update(database.workspaces)
          ..where((t) => t.id.equals(parsedId)))
        .write(db.WorkspacesCompanion(name: Value(name)));
  }

  Future<void> updateGeneralInstruction({
    required String workspaceId,
    required String instruction,
  }) async {
    final parsedId = int.tryParse(workspaceId);
    if (parsedId == null) return;

    final database = ref.read(genaDatabaseProvider);
    await (database.update(
      database.workspaces,
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

    final database = ref.read(genaDatabaseProvider);
    await (database.update(database.workspaces)
          ..where((t) => t.id.equals(parsedId)))
        .write(db.WorkspacesCompanion(ragEnabled: Value(enabled)));
  }

  Future<void> deleteWorkspace(String workspaceId) async {
    final parsedId = int.tryParse(workspaceId);
    if (parsedId == null) return;

    final database = ref.read(genaDatabaseProvider);
    final workspaceCount = await database.countAllWorkspaces();
    if (workspaceCount <= 1) {
      throw const WorkspaceGuardException(
        'You must keep at least one workspace.',
      );
    }

    final chatsInWorkspace = await (database.select(
      database.chats,
    )..where((t) => t.workspace.equals(parsedId))).get();
    final chatIds = chatsInWorkspace.map((chat) => chat.id).toList();

    final selectedChatId = ref.read(selectedChatIdProvider);
    final selectedWorkspaceId = ref.read(selectedWorkspaceIdProvider);

    await database.transaction(() async {
      if (chatIds.isNotEmpty) {
        await (database.delete(
          database.messages,
        )..where((t) => t.chat.isIn(chatIds))).go();
      }
      await (database.delete(
        database.chats,
      )..where((t) => t.workspace.equals(parsedId))).go();
      await (database.delete(
        database.workspaceDocuments,
      )..where((t) => t.workspace.equals(parsedId))).go();
      await (database.delete(
        database.workspaces,
      )..where((t) => t.id.equals(parsedId))).go();
    });

    await ref.read(workspaceRagActionsProvider).rebuildAllDocumentsIndex();

    ref.read(workspaceDrawerStateProvider.notifier).remove(workspaceId);

    final shouldReselectWorkspace = selectedWorkspaceId == workspaceId;
    if (shouldReselectWorkspace) {
      final fallbackWorkspace =
          await (database.select(database.workspaces)
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
                ..limit(1))
              .getSingleOrNull();
      final fallbackWorkspaceId = fallbackWorkspace?.id.toString();
      ref
          .read(selectedWorkspaceIdProvider.notifier)
          .selectWorkspace(fallbackWorkspaceId);
      if (fallbackWorkspaceId != null) {
        await ref
            .read(selectedChatIdProvider.notifier)
            .ensureSelectionForWorkspace(fallbackWorkspaceId);
      }
      return;
    }

    if (selectedChatId != null) {
      final parsedChatId = int.tryParse(selectedChatId);
      if (parsedChatId != null && chatIds.contains(parsedChatId)) {
        final activeWorkspaceId = await ref
            .read(selectedWorkspaceIdProvider.notifier)
            .ensureWorkspace();
        await ref
            .read(selectedChatIdProvider.notifier)
            .ensureSelectionForWorkspace(activeWorkspaceId);
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
