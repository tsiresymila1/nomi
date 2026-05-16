import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/chat_provider.dart';
import 'package:gena/features/chat/domain/entities/chat_entity.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatHistoryTile extends ConsumerWidget {
  final ChatEntity chat;
  const ChatHistoryTile({super.key, required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChatId = ref.watch(selectedChatIdProvider);
    final isSelected = selectedChatId == chat.id;

    return ListTile(
      leading: Icon(
        isSelected
            ? LucideIcons.messageCircleMore500
            : LucideIcons.messageCircle500,
      ),
      title: Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        _formatDate(chat.updatedAt),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.archive_outlined),
        tooltip: 'Archive chat',
        onPressed: () => _onArchivePressed(context, ref),
      ),
      selected: isSelected,
      onTap: () {
        ref.read(selectedChatIdProvider.notifier).selectChat(chat.id);
        Navigator.pop(context);
      },
      dense: true,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _onArchivePressed(BuildContext context, WidgetRef ref) async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Archive Chat'),
          content: const Text(
            'This will delete this chat and all its messages from the database. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Archive'),
            ),
          ],
        );
      },
    );

    if (shouldArchive != true || !context.mounted) return;

    try {
      await ref.read(chatHistoryActionsProvider).archiveChat(chat.id);
      if (!context.mounted) return;
      AppToast.show('Chat archived', type: AppToastType.success);
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show('Archive failed: $e', type: AppToastType.error);
    }
  }
}
