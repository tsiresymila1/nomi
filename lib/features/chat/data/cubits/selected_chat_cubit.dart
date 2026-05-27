import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/workspace/data/cubits/selected_workspace_cubit.dart';

class SelectedChatCubit extends Cubit<String?> {
  SelectedChatCubit({
    required db.GenaDatabase database,
    required SelectedWorkspaceCubit selectedWorkspaceCubit,
  }) : _database = database,
       _selectedWorkspaceCubit = selectedWorkspaceCubit,
       super(null) {
    _workspaceSubscription = _selectedWorkspaceCubit.stream.listen((workspaceId) {
      unawaited(_syncSelectionForWorkspace(workspaceId));
    });
    unawaited(_syncSelectionForWorkspace(_selectedWorkspaceCubit.state));
  }

  final db.GenaDatabase _database;
  final SelectedWorkspaceCubit _selectedWorkspaceCubit;
  StreamSubscription<String?>? _workspaceSubscription;
  Future<void>? _activeSync;

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
      final currentChatId = state;
      if (currentChatId != null) {
        final parsedCurrentChatId = int.tryParse(currentChatId);
        if (parsedCurrentChatId != null) {
          final currentChat =
              await (_database.select(_database.chats)
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
          await (_database.select(_database.chats)
                ..where((t) => t.workspace.equals(parsedWorkspaceId))
                ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
                ..limit(1))
              .getSingleOrNull();

      if (firstChatInWorkspace != null) {
        emit(firstChatInWorkspace.id.toString());
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
        workspaceId ?? await _selectedWorkspaceCubit.ensureWorkspace();
    final parsedWorkspaceId = int.tryParse(resolvedWorkspaceId);
    if (parsedWorkspaceId == null) {
      throw StateError('Invalid workspace id: $resolvedWorkspaceId');
    }

    final createdId = await _database.into(_database.chats).insert(
      db.ChatsCompanion.insert(title: 'New chat', workspace: parsedWorkspaceId),
    );

    final selectedId = createdId.toString();
    emit(selectedId);
    return selectedId;
  }

  void selectChat(String? chatId) {
    if (chatId == state) return;
    emit(chatId);
  }

  void clearSelection() {
    emit(null);
  }

  @override
  Future<void> close() async {
    await _workspaceSubscription?.cancel();
    return super.close();
  }
}
