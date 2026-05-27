import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/core/widgets/confirm_action_sheet.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gena/features/chat/presentation/widgets/chat_history_tile.dart';
import 'package:gena/presentation/widgets/field_wrapper.dart';
import 'package:gena/features/workspace/data/models/workspace_chat_group.dart';
import 'package:gena/features/workspace/data/providers/workspace_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

enum _WorkspaceMenuAction { newThread, rename, delete, setting }

class WorkspaceChatSection extends ConsumerWidget {
  final WorkspaceChatGroup group;

  const WorkspaceChatSection({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = group.workspace.id;
    final selectedWorkspaceId = ref.watch(selectedWorkspaceIdProvider);
    final isSelectedWorkspace = selectedWorkspaceId == workspaceId;
    final expanded = ref.watch(
      workspaceDrawerStateProvider.select(
        (state) => state[workspaceId] ?? false,
      ),
    );

    return Card(
      color: Colors.transparent,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => ref
                    .read(workspaceDrawerStateProvider.notifier)
                    .toggle(workspaceId),
                icon: Icon(
                  expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 18,
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    unawaited(
                      ref
                          .read(chatPageActionsProvider)
                          .selectWorkspace(workspaceId),
                    );
                    ref
                        .read(workspaceDrawerStateProvider.notifier)
                        .toggle(workspaceId);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.workspace.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isSelectedWorkspace
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              PopupMenuButton<_WorkspaceMenuAction>(
                tooltip: 'Workspace actions',
                onSelected: (action) {
                  switch (action) {
                    case _WorkspaceMenuAction.newThread:
                      unawaited(
                        ref
                            .read(chatPageActionsProvider)
                            .createNewThreadInWorkspace(workspaceId),
                      );
                      break;
                    case _WorkspaceMenuAction.rename:
                      unawaited(_showRenameDialog(context, ref));
                      break;
                    case _WorkspaceMenuAction.delete:
                      unawaited(_showDeleteDialog(context, ref));
                      break;
                    case _WorkspaceMenuAction.setting:
                      context.pop();
                      context.pushNamed(
                        'workspace-config',
                        pathParameters: {'workspaceId': workspaceId},
                      );
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<_WorkspaceMenuAction>(
                    value: _WorkspaceMenuAction.newThread,
                    child: Row(
                      children: [
                        HugeIcon(icon: HugeIcons.strokeRoundedPencilEdit02),
                        SizedBox(width: 8),
                        Text('New thread'),
                      ],
                    ),
                  ),
                  PopupMenuItem<_WorkspaceMenuAction>(
                    value: _WorkspaceMenuAction.rename,
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 8),
                        Text('Rename workspace'),
                      ],
                    ),
                  ),
                  PopupMenuItem<_WorkspaceMenuAction>(
                    value: _WorkspaceMenuAction.delete,
                    child: Row(
                      children: [
                        HugeIcon(icon: HugeIcons.strokeRoundedDelete02),
                        SizedBox(width: 8),
                        Text('Delete workspace'),
                      ],
                    ),
                  ),
                  PopupMenuItem<_WorkspaceMenuAction>(
                    value: _WorkspaceMenuAction.setting,
                    child: Row(
                      children: [
                        HugeIcon(icon: HugeIcons.strokeRoundedSettings03),
                        SizedBox(width: 8),
                        Text('Setting'),
                      ],
                    ),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.more_vert),
                ),
              ),
            ],
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
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
                        return ChatHistoryTile(chat: group.chats[index]);
                      },
                    ),
                ],
              ),
            ).animate().fade(duration: 200.ms),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: group.workspace.name);
    final renamed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 400),
        reverseDuration: Duration(milliseconds: 200),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rename workspace',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              FieldWrapper(
                label: 'Name',
                field: TextField(
                  controller: controller,
                  maxLength: 64,
                  decoration: const InputDecoration(
                    hintText: 'My workspace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (renamed != true) {
      controller.dispose();
      return;
    }

    try {
      await ref
          .read(workspaceActionsProvider)
          .renameWorkspace(
            workspaceId: group.workspace.id,
            rawName: controller.text,
          );
    } on WorkspaceGuardException catch (e) {
      await AppToast.show(e.message, type: AppToastType.error);
    }
    controller.dispose();
  }

  Future<void> _showDeleteDialog(BuildContext context, WidgetRef ref) async {
    final shouldDelete = await showConfirmActionSheet(
      context,
      title: 'Delete Workspace',
      message: 'Delete "${group.workspace.name}" and all its threads/messages?',
      confirmLabel: 'Delete',
    );
    if (!shouldDelete) return;

    try {
      await ref
          .read(workspaceActionsProvider)
          .deleteWorkspace(group.workspace.id);
    } on WorkspaceGuardException catch (e) {
      await AppToast.show(e.message, type: AppToastType.info);
    }
  }
}
