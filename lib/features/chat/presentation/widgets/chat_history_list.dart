import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gena/features/chat/presentation/widgets/chat_history_tile.dart';

class ChatHistoryList extends ConsumerWidget {
  const ChatHistoryList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatListProvider);

    return chatsAsync.when(
      data: (chats) => chats.isEmpty
          ? const Center(
              child: Text(
                'No chat history',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) =>
                  ChatHistoryTile(chat: chats[index]),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
