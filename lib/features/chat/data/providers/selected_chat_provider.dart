import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/features/workspace/data/providers/selected_workspace_provider.dart';

final selectedChatIdProvider =
    NotifierProvider<SelectedChatIdNotifier, String?>(
      SelectedChatIdNotifier.new,
    );

class SelectedChatIdNotifier extends Notifier<String?> {
  Future<void>? _activeSync;

  @override
  String? build() {
    final workspaceId = ref.watch(selectedWorkspaceIdProvider);
    unawaited(_syncSelectionForWorkspace(workspaceId));
    return stateOrNull;
  }

  Future<void> ensureSelectionForWorkspace(String workspaceId) {
    return _syncSelectionForWorkspace(workspaceId);
  }

  Future<void> _syncSelectionForWorkspace(String? workspaceId) async {
    if (workspaceId == null) return;

    final inFlightSync = _activeSync;
    if (inFlightSync != null) {
      await inFlightSync;
    }

    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) return;

    final syncCompleter = Completer<void>();
    _activeSync = syncCompleter.future;
    try {
      final database = ref.read(genaDatabaseProvider);
      final currentChatId = state;
      if (currentChatId != null) {
        final parsedCurrentChatId = int.tryParse(currentChatId);
        if (parsedCurrentChatId != null) {
          final currentChat =
              await (database.select(database.chats)
                    ..where(
                      (t) =>
                          t.id.equals(parsedCurrentChatId) &
                          t.workspace.equals(parsedWorkspaceId),
                    )
                    ..limit(1))
                  .getSingleOrNull();
          if (currentChat != null) {
            return;
          }
        }
      }

      final firstChatInWorkspace =
          await (database.select(database.chats)
                ..where((t) => t.workspace.equals(parsedWorkspaceId))
                ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
                ..limit(1))
              .getSingleOrNull();

      if (firstChatInWorkspace != null) {
        state = firstChatInWorkspace.id.toString();
        return;
      }

      await createNewThread(workspaceId: workspaceId);
    } finally {
      syncCompleter.complete();
      if (identical(_activeSync, syncCompleter.future)) {
        _activeSync = null;
      }
    }
  }

  Future<String> createNewThread({String? workspaceId}) async {
    final resolvedWorkspaceId =
        workspaceId ??
        await ref.read(selectedWorkspaceIdProvider.notifier).ensureWorkspace();
    final parsedWorkspaceId = int.tryParse(resolvedWorkspaceId);
    if (parsedWorkspaceId == null) {
      throw StateError('Invalid workspace id: $resolvedWorkspaceId');
    }

    final database = ref.read(genaDatabaseProvider);
    final createdId = await database
        .into(database.chats)
        .insert(
          db.ChatsCompanion.insert(
            title: 'New chat',
            workspace: parsedWorkspaceId,
          ),
        );

    final selectedId = createdId.toString();
    state = selectedId;
    return selectedId;
  }

  void selectChat(String? chatId) {
    if (chatId == state) return;
    state = chatId;
  }

  void clearSelection() {
    state = null;
  }
}
