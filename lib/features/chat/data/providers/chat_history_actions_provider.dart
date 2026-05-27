import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/chat/data/cubits/selected_chat_cubit.dart';
import 'package:gena/features/chat/data/providers/chat_thread_actions_provider.dart';
import 'package:gena/features/workspace/data/cubits/selected_workspace_cubit.dart';

class ChatHistoryActions {
  ChatHistoryActions({
    required db.GenaDatabase database,
    required SelectedChatCubit selectedChatCubit,
    required SelectedWorkspaceCubit selectedWorkspaceCubit,
    required ChatThreadActions chatThreadActions,
  }) : _database = database,
       _selectedChatCubit = selectedChatCubit,
       _selectedWorkspaceCubit = selectedWorkspaceCubit,
       _chatThreadActions = chatThreadActions;

  final db.GenaDatabase _database;
  final SelectedChatCubit _selectedChatCubit;
  final SelectedWorkspaceCubit _selectedWorkspaceCubit;
  final ChatThreadActions _chatThreadActions;

  Future<void> archiveChat(String chatId) async {
    final parsedChatId = int.tryParse(chatId);
    if (parsedChatId == null) return;

    final selectedChatId = _selectedChatCubit.state;
    final isActiveChat = selectedChatId == chatId;
    final chat =
        await (_database.select(_database.chats)
              ..where((t) => t.id.equals(parsedChatId))
              ..limit(1))
            .getSingleOrNull();
    if (chat == null) return;
    final selectedWorkspaceId = _selectedWorkspaceCubit.state;
    final isInSelectedWorkspace =
        selectedWorkspaceId == chat.workspace.toString();

    await _database.transaction(() async {
      await (_database.delete(
        _database.messages,
      )..where((t) => t.chat.equals(parsedChatId))).go();
      await (_database.delete(
        _database.chats,
      )..where((t) => t.id.equals(parsedChatId))).go();
    });

    if (isActiveChat || isInSelectedWorkspace) {
      await _chatThreadActions.stopGeneration();
      await _selectedChatCubit.ensureSelectionForWorkspace(
        chat.workspace.toString(),
      );
    }
  }
}
