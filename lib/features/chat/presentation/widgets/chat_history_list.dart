import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/chat_provider.dart';
import 'package:gena/features/chat/domain/entities/chat_entity.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
                  _ChatHistoryTile(chat: chats[index]),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

class _ChatHistoryTile extends ConsumerWidget {
  final ChatEntity chat;
  const _ChatHistoryTile({required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChatId = ref.watch(selectedChatIdProvider);
    final isSelected = selectedChatId == chat.id;

    return ListTile(
      leading: Icon(isSelected ? LucideIcons.messageCircleMore500 : LucideIcons.messageCircle500),
      title: Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        _formatDate(chat.updatedAt),
        style: const TextStyle(fontSize: 12),
      ),
      selected: isSelected,
      onTap: () {
        ref.read(selectedChatIdProvider.notifier).selectChat(chat.id);
        Navigator.pop(context);
      },
      dense: true
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }
}
