import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/workspace/data/cubits/workspace_drawer_cubit.dart';
import 'package:gena/features/workspace/data/models/workspace_chat_group.dart';
import 'package:gena/features/workspace/presentation/services/workspace_chat_section_actions.dart';
import 'package:hugeicons/hugeicons.dart';

class WorkspaceChatSectionHeader extends StatelessWidget {
  const WorkspaceChatSectionHeader({
    super.key,
    required this.group,
    required this.expanded,
    required this.isSelectedWorkspace,
  });

  final WorkspaceChatGroup group;
  final bool expanded;
  final bool isSelectedWorkspace;

  @override
  Widget build(BuildContext context) {
    final workspaceId = group.workspace.id;
    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => sl<WorkspaceDrawerCubit>().toggle(workspaceId),
          icon: Icon(
            expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
            size: 18,
          ),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => unawaited(
              WorkspaceChatSectionActions.selectWorkspace(context, workspaceId),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
          ),
        ),
        PopupMenuButton<WorkspaceMenuAction>(
          tooltip: 'Workspace actions',
          onSelected: (action) => WorkspaceChatSectionActions.onMenuActionSelected(
            context,
            group,
            action,
          ),
          itemBuilder: (context) => const [
            PopupMenuItem<WorkspaceMenuAction>(
              value: WorkspaceMenuAction.newThread,
              child: Row(
                children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedPencilEdit02),
                  SizedBox(width: 8),
                  Text('New thread'),
                ],
              ),
            ),
            PopupMenuItem<WorkspaceMenuAction>(
              value: WorkspaceMenuAction.rename,
              child: Row(
                children: [
                  Icon(Icons.edit_outlined),
                  SizedBox(width: 8),
                  Text('Rename workspace'),
                ],
              ),
            ),
            PopupMenuItem<WorkspaceMenuAction>(
              value: WorkspaceMenuAction.delete,
              child: Row(
                children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedDelete02),
                  SizedBox(width: 8),
                  Text('Delete workspace'),
                ],
              ),
            ),
            PopupMenuItem<WorkspaceMenuAction>(
              value: WorkspaceMenuAction.setting,
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
    );
  }
}
