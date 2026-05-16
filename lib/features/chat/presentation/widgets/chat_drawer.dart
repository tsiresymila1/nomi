import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/chat_provider.dart';
import 'package:gena/features/chat/presentation/widgets/chat_history_list.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatDrawer extends ConsumerWidget {
  const ChatDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'History',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      await ref.read(chatPageActionsProvider).createNewThread();
                      if (context.mounted) {
                        context.pop();
                      }
                    },
                    icon: const Icon(LucideIcons.squarePen500, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(),
            const Expanded(child: ChatHistoryList()),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                spacing: 8,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.cpu),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.pushNamed('download');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.pushNamed('model-setting');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
