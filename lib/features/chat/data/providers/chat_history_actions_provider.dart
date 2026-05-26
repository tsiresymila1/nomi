import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/features/chat/data/providers/chat_thread_actions_provider.dart';
import 'package:gena/features/chat/data/providers/selected_chat_provider.dart';
import 'package:gena/features/workspace/data/providers/selected_workspace_provider.dart';

final chatHistoryActionsProvider = Provider<ChatHistoryActions>(
  (ref) => ChatHistoryActions(ref),
);

class ChatHistoryActions {
  final Ref ref;
  ChatHistoryActions(this.ref);

  Future<void> archiveChat(String chatId) async {
    final parsedChatId = int.tryParse(chatId);
    if (parsedChatId == null) return;

    final selectedChatId = ref.read(selectedChatIdProvider);
    final isActiveChat = selectedChatId == chatId;
    final database = ref.read(genaDatabaseProvider);
    final chat =
        await (database.select(database.chats)
              ..where((t) => t.id.equals(parsedChatId))
              ..limit(1))
            .getSingleOrNull();
    if (chat == null) return;
    final selectedWorkspaceId = ref.read(selectedWorkspaceIdProvider);
    final isInSelectedWorkspace =
        selectedWorkspaceId == chat.workspace.toString();

    await database.transaction(() async {
      await (database.delete(
        database.messages,
      )..where((t) => t.chat.equals(parsedChatId))).go();
      await (database.delete(
        database.chats,
      )..where((t) => t.id.equals(parsedChatId))).go();
    });

    if (isActiveChat || isInSelectedWorkspace) {
      await ref.read(chatThreadActionsProvider).stopGeneration();
      await ref
          .read(selectedChatIdProvider.notifier)
          .ensureSelectionForWorkspace(chat.workspace.toString());
    }
  }
}
