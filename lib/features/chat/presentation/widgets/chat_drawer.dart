import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gena/presentation/widgets/field_wrapper.dart';
import 'package:gena/features/workspace/data/providers/workspace_provider.dart';
import 'package:gena/features/workspace/presentation/widgets/workspace_chat_section.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

class ChatDrawer extends ConsumerWidget {
  const ChatDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(workspaceChatGroupsProvider);

    return Drawer(
      width: 350,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => context.goNamed("home"),
                      child: Row(
                        children: [
                          Image.asset('assets/images/logo.png', width: 40),
                          const Text(
                            'Nomi',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'New workspace',
                    onPressed: () => _showCreateWorkspaceDialog(context, ref),
                    icon: const Icon(Icons.create_new_folder_outlined),
                  ),
                  IconButton(
                    tooltip: 'New thread',
                    onPressed: () async {
                      await ref.read(chatPageActionsProvider).createNewThread();
                      if (context.mounted) {
                        context.pop();
                      }
                    },
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedPencilEdit02,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return const Center(child: Text('No workspace'));
                  }
                  return ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) =>
                        WorkspaceChatSection(group: groups[index]),
                  );
                },
                loading: () => const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    spacing: 12,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedCpu,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () async {
                          await ref
                              .read(chatThreadActionsProvider)
                              .stopGeneration(
                                triggerLocalModelCancel: false,
                                waitForLocalModelCancel: false,
                              );
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          context.pushNamed('download');
                        },
                        label: const Text('Models'),
                      ),
                      IconButton(
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedSettings02,
                        ),
                        onPressed: () async {
                          await ref
                              .read(chatThreadActionsProvider)
                              .stopGeneration(
                                triggerLocalModelCancel: false,
                                waitForLocalModelCancel: false,
                              );
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          context.pushNamed('setting');
                        },
                      ),
                    ],
                  ),
                  Opacity(
                    opacity: 0.5,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Made with ❤️ by ',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Tsiresy Milà',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateWorkspaceDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    final shouldCreate = await showModalBottomSheet<bool>(
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
                'New workspace',
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
                  child: const Text('Create'),
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

    if (shouldCreate != true) {
      controller.dispose();
      return;
    }

    try {
      await ref.read(workspaceActionsProvider).createWorkspace(controller.text);
    } on WorkspaceGuardException catch (e) {
      await AppToast.show(e.message, type: AppToastType.error);
    }
    controller.dispose();
  }
}
