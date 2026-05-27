import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/core/widgets/confirm_action_sheet.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gena/features/chat/data/models/chat_entity.dart';
import 'package:hugeicons/hugeicons.dart';

class ChatHistoryTile extends ConsumerWidget {
  final ChatEntity chat;
  const ChatHistoryTile({super.key, required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChatId = ref.watch(selectedChatIdProvider);
    final isSelected = selectedChatId == chat.id;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (context.mounted) {
            Navigator.pop(context);
          }
          unawaited(ref.read(chatPageActionsProvider).selectChat(chat.id));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: isSelected
                    ? HugeIcons.strokeRoundedMessageDone01
                    : HugeIcons.strokeRoundedMessage01,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(chat.updatedAt),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete03),
                tooltip: 'Archive chat',
                visualDensity: VisualDensity.compact,
                onPressed: () => unawaited(_onArchivePressed(context, ref)),
              ),
            ],
          ),
        ),
      ),
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
    final shouldArchive = await showConfirmActionSheet(
      context,
      title: 'Delete Thread',
      message:
          'This will delete this thread and all its messages from the database. Continue?',
      confirmLabel: 'Delete',
    );

    if (!shouldArchive || !context.mounted) return;

    try {
      ref
          .read(chatHistoryActionsProvider)
          .archiveChat(chat.id)
          .then((_) {
            if (!context.mounted) return;
            AppToast.show('Chat archived', type: AppToastType.success);
          })
          .catchError((e) {
            if (!context.mounted) return;
            AppToast.show('Archive failed: $e', type: AppToastType.error);
          });
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show('Archive failed: $e', type: AppToastType.error);
    }
  }
}
