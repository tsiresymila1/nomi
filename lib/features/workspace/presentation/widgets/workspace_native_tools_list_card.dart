import 'package:flutter/material.dart';
import 'package:gena/features/workspace/presentation/widgets/workspace_tool_list_row.dart';

class WorkspaceNativeToolsListCard extends StatelessWidget {
  const WorkspaceNativeToolsListCard({
    super.key,
    required this.allEnabled,
    required this.openUrlEnabled,
    required this.openAppEnabled,
    required this.sendEmailEnabled,
    required this.flashlightEnabled,
  });

  final bool allEnabled;
  final bool openUrlEnabled;
  final bool openAppEnabled;
  final bool sendEmailEnabled;
  final bool flashlightEnabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabledColor = colorScheme.onSurfaceVariant;

    bool enabled(bool featureEnabled) => allEnabled && featureEnabled;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Native tools list',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          WorkspaceToolListRow(
            label: 'Open URL',
            enabled: enabled(openUrlEnabled),
            disabledColor: disabledColor,
          ),
          WorkspaceToolListRow(
            label: 'Open app / deep link',
            enabled: enabled(openAppEnabled),
            disabledColor: disabledColor,
          ),
          WorkspaceToolListRow(
            label: 'Phone call',
            enabled: enabled(openAppEnabled),
            disabledColor: disabledColor,
          ),
          WorkspaceToolListRow(
            label: 'Contacts (read/search/create)',
            enabled: enabled(openAppEnabled),
            disabledColor: disabledColor,
          ),
          WorkspaceToolListRow(
            label: 'Send SMS',
            enabled: enabled(openAppEnabled),
            disabledColor: disabledColor,
          ),
          WorkspaceToolListRow(
            label: 'Send email',
            enabled: enabled(sendEmailEnabled),
            disabledColor: disabledColor,
          ),
          WorkspaceToolListRow(
            label: 'Flashlight',
            enabled: enabled(flashlightEnabled),
            disabledColor: disabledColor,
          ),
        ],
      ),
    );
  }
}
