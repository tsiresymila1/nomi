import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gena/features/chat/presentation/widgets/chat_history_list.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

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
                   Expanded(
                    child: Row(
                      children: [
                        Image.asset("assets/images/logo.png", width: 50,),
                        Text(
                          'Nomi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
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
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedPencilEdit02),
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
                spacing: 12,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedCpu,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.pushNamed('download');
                    },
                    label: Text("Models"),
                  ),
                  IconButton(
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedSettings02),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.pushNamed('setting');
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
