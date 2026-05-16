import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/features/chat/data/providers/selected_chat_provider.dart';

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

    await database.transaction(() async {
      await (database.delete(
        database.messages,
      )..where((t) => t.chat.equals(parsedChatId))).go();
      await (database.delete(
        database.chats,
      )..where((t) => t.id.equals(parsedChatId))).go();
    });

    if (isActiveChat) {
      await ref.read(selectedChatIdProvider.notifier).createNewThread();
    }
  }
}
