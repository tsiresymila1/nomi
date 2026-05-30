import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/chat/data/providers/chat_page_actions_provider.dart';
import 'package:gena/features/chat/data/cubits/selected_chat_cubit.dart';
import 'package:gena/features/workspace/data/models/workspace_chat_group.dart';
import 'package:hugeicons/hugeicons.dart';

class WorkspaceChatSectionThreads extends StatelessWidget {
  const WorkspaceChatSectionThreads({super.key, required this.group});

  final WorkspaceChatGroup group;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SelectedChatCubit, String?>(
      bloc: sl<SelectedChatCubit>(),
      builder: (context, selectedChatId) {
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              if (group.chats.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      'No threads yet',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  itemCount: group.chats.length,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final chat = group.chats[index];
                    final isSelected = selectedChatId == chat.id;
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      leading: HugeIcon(
                        icon: isSelected
                            ? HugeIcons.strokeRoundedMessageDone01
                            : HugeIcons.strokeRoundedMessage01,
                      ),
                      title: Text(
                        chat.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          fontWeight: isSelected ? FontWeight.w600 : null,
                        ),
                      ),
                      onTap: () async {
                        await sl<ChatPageActions>().selectWorkspace(
                          chat.workspaceId,
                        );
                        await sl<ChatPageActions>().selectChat(chat.id);
                        if (context.mounted && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
