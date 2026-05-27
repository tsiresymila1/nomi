import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class DownloadItemActions extends StatelessWidget {
  const DownloadItemActions({
    required this.isDownloading,
    required this.isRemote,
    required this.isNetworkSource,
    required this.canRemove,
    required this.canDeleteDownloadedFile,
    required this.isInstalled,
    required this.onEdit,
    required this.onDownload,
    required this.onRemove,
    required this.onDeleteDownloadedFile,
    super.key,
  });

  final bool isDownloading;
  final bool isRemote;
  final bool isNetworkSource;
  final bool canRemove;
  final bool canDeleteDownloadedFile;
  final bool isInstalled;
  final VoidCallback onEdit;
  final VoidCallback onDownload;
  final VoidCallback onRemove;
  final VoidCallback onDeleteDownloadedFile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          onPressed: isDownloading || isRemote || isInstalled
              ? null
              : onDownload,
          icon: isRemote
              ? HugeIcon(
                  icon: HugeIcons.strokeRoundedCloudDownload,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                )
              : isNetworkSource
              ? HugeIcon(
                  icon: HugeIcons.strokeRoundedDownload01,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                )
              : const HugeIcon(
                  icon: HugeIcons.strokeRoundedComputerAdd,
                  size: 18,
                ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Delete downloaded file',
          onPressed: canDeleteDownloadedFile && !isDownloading
              ? onDeleteDownloadedFile
              : null,
          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: canRemove ? 'Remove model' : 'Static default model',
          onPressed: !canRemove || isDownloading ? null : onRemove,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete02, size: 18),
        ),
      ],
    );
  }
}
