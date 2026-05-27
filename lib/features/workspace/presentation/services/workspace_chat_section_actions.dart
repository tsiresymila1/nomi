import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/core/widgets/confirm_action_sheet.dart';
import 'package:gena/features/workspace/data/cubits/workspace_drawer_cubit.dart';
import 'package:gena/features/workspace/data/models/workspace_chat_group.dart';
import 'package:gena/features/workspace/presentation/services/workspace_local_chat_actions.dart';
import 'package:gena/presentation/widgets/field_wrapper.dart';
import 'package:go_router/go_router.dart';

class WorkspaceChatSectionActions {
  const WorkspaceChatSectionActions._();

  static Future<void> onMenuActionSelected(
    BuildContext context,
    WorkspaceChatGroup group,
    WorkspaceMenuAction action,
  ) async {
    switch (action) {
      case WorkspaceMenuAction.newThread:
        await sl<WorkspaceLocalChatActions>().createNewThreadInWorkspace(
          group.workspace.id,
        );
      case WorkspaceMenuAction.rename:
        await _showRenameDialog(context, group);
      case WorkspaceMenuAction.delete:
        await _showDeleteDialog(context, group);
      case WorkspaceMenuAction.setting:
        if (!context.mounted) return;
        context.pop();
        context.pushNamed(
          'workspace-config',
          pathParameters: {'workspaceId': group.workspace.id},
        );
    }
  }

  static Future<void> selectWorkspace(
    BuildContext context,
    String workspaceId,
  ) async {
    await sl<WorkspaceLocalChatActions>().selectWorkspace(workspaceId);
    sl<WorkspaceDrawerCubit>().toggle(workspaceId);
  }

  static Future<void> _showRenameDialog(
    BuildContext context,
    WorkspaceChatGroup group,
  ) async {
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
                  decoration: const InputDecoration(hintText: 'My workspace'),
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
      await sl<WorkspaceLocalChatActions>().renameWorkspace(
        workspaceId: group.workspace.id,
        rawName: controller.text,
      );
    } on WorkspaceActionException catch (error) {
      await AppToast.show(error.message, type: AppToastType.error);
    } finally {
      controller.dispose();
    }
  }

  static Future<void> _showDeleteDialog(
    BuildContext context,
    WorkspaceChatGroup group,
  ) async {
    final shouldDelete = await showConfirmActionSheet(
      context,
      title: 'Delete Workspace',
      message:
          'Delete "${group.workspace.name}" and all its threads/messages?',
      confirmLabel: 'Delete',
    );
    if (!shouldDelete) return;

    try {
      await sl<WorkspaceLocalChatActions>().deleteWorkspace(group.workspace.id);
    } on WorkspaceActionException catch (error) {
      await AppToast.show(error.message, type: AppToastType.info);
    }
  }
}

enum WorkspaceMenuAction { newThread, rename, delete, setting }
