import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gena/features/workspace/data/models/workspace_chat_group.dart';
import 'package:hugeicons/hugeicons.dart';

class HomeWorkspaceList extends StatelessWidget {
  const HomeWorkspaceList({
    required this.groups,
    required this.onOpenWorkspaceChat,
    super.key,
  });

  final List<WorkspaceChatGroup> groups;
  final ValueChanged<String> onOpenWorkspaceChat;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Center(child: Text('No workspace yet'));
    }

    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final delayMs = index * 50;
        final threadCount = group.chats.length;
        return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ExpansionTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide.none,
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide.none,
                ),
                title: Text(
                  group.workspace.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '$threadCount thread${threadCount == 1 ? '' : 's'}',
                ),
                children: [
                  if (group.chats.isEmpty)
                    const ListTile(dense: true, title: Text('No thread yet'))
                  else
                    for (final chat in group.chats.take(5))
                      ListTile(
                        dense: true,
                        leading: const HugeIcon(
                          icon: HugeIcons.strokeRoundedChat01,
                          size: 16,
                        ),
                        title: Text(
                          chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ListTile(
                    leading: const HugeIcon(
                      icon: HugeIcons.strokeRoundedLink01,
                    ),
                    title: const Text(
                      'Open Workspace Chat',
                      style: TextStyle(fontSize: 13),
                    ),
                    onTap: () => onOpenWorkspaceChat(group.workspace.id),
                  ),
                ],
              ),
            )
            .animate()
            .fade(duration: 500.ms, delay: delayMs.ms)
            .scale(
              delay: (delayMs + 120).ms,
              duration: 260.ms,
              begin: const Offset(0.98, 0.98),
              end: const Offset(1, 1),
              curve: Curves.easeOutCubic,
            );
      },
    );
  }
}
