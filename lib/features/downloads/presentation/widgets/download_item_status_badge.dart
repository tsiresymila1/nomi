import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class DownloadItemStatusBadge extends StatelessWidget {
  const DownloadItemStatusBadge({
    required this.isDownloading,
    required this.progress,
    required this.isInstalled,
    super.key,
  });

  final bool isDownloading;
  final double? progress;
  final bool isInstalled;

  @override
  Widget build(BuildContext context) {
    if (isDownloading) {
      return SizedBox(
        width: 50,
        child: Text(
          '${((progress ?? 0) * 100).toStringAsFixed(0)}%',
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 12),
        ),
      );
    }

    if (isInstalled) {
      return const HugeIcon(
        icon: HugeIcons.strokeRoundedCheckmarkCircle03,
        color: Colors.green,
        size: 18,
      );
    }

    return Text(
      'Not installed',
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
