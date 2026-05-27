import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/workspace/data/cubits/selected_workspace_cubit.dart';
import 'package:gena/features/workspace/data/cubits/workspace_drawer_cubit.dart';
import 'package:gena/features/workspace/data/models/workspace_chat_group.dart';
import 'package:gena/features/workspace/presentation/widgets/workspace_chat_section_header.dart';
import 'package:gena/features/workspace/presentation/widgets/workspace_chat_section_threads.dart';

class WorkspaceChatSection extends StatelessWidget {
  const WorkspaceChatSection({super.key, required this.group});

  final WorkspaceChatGroup group;

  @override
  Widget build(BuildContext context) {
    final workspaceId = group.workspace.id;

    return BlocBuilder<SelectedWorkspaceCubit, String?>(
      bloc: sl<SelectedWorkspaceCubit>(),
      buildWhen: (previous, current) =>
          previous == workspaceId || current == workspaceId,
      builder: (context, selectedWorkspaceId) {
        final isSelectedWorkspace = selectedWorkspaceId == workspaceId;

        return BlocBuilder<WorkspaceDrawerCubit, Map<String, bool>>(
          bloc: sl<WorkspaceDrawerCubit>(),
          buildWhen: (previous, current) =>
              previous[workspaceId] != current[workspaceId],
          builder: (context, drawerState) {
            final expanded = drawerState[workspaceId] ?? false;
            return Card(
              color: Colors.transparent,
              elevation: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WorkspaceChatSectionHeader(
                    group: group,
                    expanded: expanded,
                    isSelectedWorkspace: isSelectedWorkspace,
                  ),
                  if (expanded)
                    WorkspaceChatSectionThreads(
                      group: group,
                    ).animate().fade(duration: 200.ms),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
