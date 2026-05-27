import 'package:flutter/material.dart';

class DownloadItemCapabilityChip extends StatelessWidget {
  const DownloadItemCapabilityChip({
    required this.label,
    required this.enabled,
    super.key,
  });

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: enabled
            ? colorScheme.primary.withValues(alpha: 0.15)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        enabled ? label : '$label: No',
        style: TextStyle(
          fontSize: 11,
          color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
