import 'package:flutter/material.dart';

class WorkspaceToolListRow extends StatelessWidget {
  const WorkspaceToolListRow({
    super.key,
    required this.label,
    required this.enabled,
    required this.disabledColor,
  });

  final String label;
  final bool enabled;
  final Color disabledColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.remove_circle_outline,
            size: 16,
            color: enabled ? Colors.green : disabledColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: enabled ? null : disabledColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
