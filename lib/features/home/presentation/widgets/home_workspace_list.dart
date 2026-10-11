import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gena/features/workspace/data/models/workspace_chat_group.dart';
import 'package:hugeicons/hugeicons.dart';

class HomeWorkspaceList extends StatelessWidget {
  const HomeWorkspaceList({
    required this.groups,
    required this.onOpenChat,
    required this.onOpenWorkspaceChat,
    required this.onOpenWorkspaceSettings,
    super.key,
  });

  final List<WorkspaceChatGroup> groups;
  final void Function(String workspaceId, String chatId) onOpenChat;
  final ValueChanged<String> onOpenWorkspaceChat;
  final ValueChanged<String> onOpenWorkspaceSettings;

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
        final visibleChats = group.chats.take(5);
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
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.workspace.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('workspace-settings-${group.workspace.id}'),
                      tooltip: 'Workspace settings',
                      visualDensity: VisualDensity.compact,
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedSettings02,
                        size: 18,
                      ),
                      onPressed: () =>
                          onOpenWorkspaceSettings(group.workspace.id),
                    ),
                  ],
                ),
                subtitle: Text(
                  '$threadCount thread${threadCount == 1 ? '' : 's'}',
                ),
                children: [
                  if (group.chats.isEmpty)
                    ListTile(
                      key: ValueKey(
                        'workspace-start-chat-${group.workspace.id}',
                      ),
                      dense: true,
                      leading: const HugeIcon(
                        icon: HugeIcons.strokeRoundedChatAdd01,
                        size: 18,
                      ),
                      title: const Text('Start a chat'),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => onOpenWorkspaceChat(group.workspace.id),
                    )
                  else
                    for (final chat in visibleChats)
                      ListTile(
                        key: ValueKey('home-chat-${chat.id}'),
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
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => onOpenChat(group.workspace.id, chat.id),
                      ),
                  if (group.chats.length > 5)
                    ListTile(
                      dense: true,
                      leading: const HugeIcon(
                        icon: HugeIcons.strokeRoundedMoreHorizontalCircle01,
                        size: 18,
                      ),
                      title: const Text(
                        'View all chats',
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
