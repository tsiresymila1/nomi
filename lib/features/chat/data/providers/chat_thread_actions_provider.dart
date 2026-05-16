import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/features/chat/data/providers/chat_session_provider.dart';
import 'package:gena/features/chat/data/providers/chat_ui_state_provider.dart';
import 'package:gena/features/chat/data/providers/selected_chat_provider.dart';

final chatThreadActionsProvider = Provider<ChatThreadActions>(
  (ref) => ChatThreadActions(ref),
);

class ChatThreadActions {
  final Ref ref;
  ChatThreadActions(this.ref);

  Future<void> sendMessage(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return;

    var chatId = ref.read(selectedChatIdProvider);
    chatId ??= await ref
        .read(selectedChatIdProvider.notifier)
        .createNewThread();

    final parsedChatId = int.tryParse(chatId);
    if (parsedChatId == null) return;

    final session = await ref.read(activeGemmaChatProvider.future);
    if (session == null) return;

    final database = ref.read(genaDatabaseProvider);

    await database
        .into(database.messages)
        .insert(
          db.MessagesCompanion.insert(
            chat: parsedChatId,
            role: 'user',
            content: text,
          ),
        );

    await session.chat.addQueryChunk(
      gemma.Message.text(text: text, isUser: true),
    );

    ref.read(chatGeneratingProvider.notifier).setGenerating(true);
    ref.read(chatDraftResponseProvider.notifier).setDraft('');

    final responseBuffer = StringBuffer();
    try {
      await for (final response in session.chat.generateChatResponseAsync()) {
        if (response is gemma.TextResponse) {
          responseBuffer.write(response.token);
          ref
              .read(chatDraftResponseProvider.notifier)
              .setDraft(responseBuffer.toString());
        }
      }
    } finally {
      ref.read(chatGeneratingProvider.notifier).setGenerating(false);
    }

    final responseText = responseBuffer.toString().trim();
    if (responseText.isNotEmpty) {
      await database
          .into(database.messages)
          .insert(
            db.MessagesCompanion.insert(
              chat: parsedChatId,
              role: 'assistant',
              content: responseText,
            ),
          );
    }

    ref.read(chatDraftResponseProvider.notifier).clear();
  }
}
