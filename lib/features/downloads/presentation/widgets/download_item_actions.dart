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
    final canDownload = !isDownloading && !isRemote && !isInstalled;
    return Row(
      children: [
        if (canDownload)
          Tooltip(
            message: 'Download model',
            child: FilledButton.tonalIcon(
              key: const ValueKey('model-primary-download'),
              onPressed: onDownload,
              icon: isNetworkSource
                  ? const HugeIcon(
                      icon: HugeIcons.strokeRoundedDownload01,
                      size: 18,
                    )
                  : const HugeIcon(
                      icon: HugeIcons.strokeRoundedComputerAdd,
                      size: 18,
                    ),
              label: Text(isNetworkSource ? 'Download' : 'Choose file'),
            ),
          )
        else
          const Spacer(),
        if (canDownload) const Spacer(),
        PopupMenuButton<_ModelAction>(
          key: const ValueKey('model-more-actions'),
          tooltip: 'More model actions',
          enabled: !isDownloading,
          onSelected: (action) {
            switch (action) {
              case _ModelAction.edit:
                onEdit();
              case _ModelAction.deleteFile:
                onDeleteDownloadedFile();
              case _ModelAction.remove:
                onRemove();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _ModelAction.edit,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit_outlined),
                title: Text('Edit details'),
              ),
            ),
            if (canDeleteDownloadedFile)
              const PopupMenuItem(
                value: _ModelAction.deleteFile,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_sweep_outlined),
                  title: Text('Delete downloaded file'),
                ),
              ),
            if (canRemove)
              const PopupMenuItem(
                value: _ModelAction.remove,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline),
                  title: Text('Remove model'),
                ),
              ),
          ],
          icon: const Icon(Icons.more_vert_rounded),
        ),
      ],
    );
  }
}

enum _ModelAction { edit, deleteFile, remove }
