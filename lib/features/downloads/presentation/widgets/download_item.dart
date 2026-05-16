import 'package:flutter/material.dart';
import 'package:gena/features/downloads/domain/model_info.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DownloadItem extends StatelessWidget {
  final ModelInfo model;
  final double? progress;
  final bool isInstalled;
  final VoidCallback onDownload;
  final VoidCallback onRemove;

  const DownloadItem({
    super.key,
    required this.model,
    required this.progress,
    required this.isInstalled,
    required this.onDownload,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloading = progress != null && progress! < 1.0;
    final isNetworkSource =
        model.sourceType == 'network' ||
        model.source.startsWith('http://') ||
        model.source.startsWith('https://');

    return Card(
      child: ListTile(
        leading: Icon(
          LucideIcons.cpu,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          model.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(model.description, style: const TextStyle(fontSize: 13)),
            if (isDownloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDownloading)
              SizedBox(
                width: 48,
                child: Text(
                  '${((progress ?? 0) * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 12),
                ),
              )
            else if (isInstalled)
              const Icon(Icons.check_circle, color: Colors.green)
            else if (isNetworkSource)
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Download model',
                onPressed: onDownload,
              )
            else
              IconButton(
                icon: const Icon(Icons.install_desktop_outlined),
                tooltip: 'Install model',
                onPressed: onDownload,
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove model',
              onPressed: () => _confirmRemove(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Model'),
          content: Text(
            'Remove "${model.name}" from your device and database?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (shouldRemove == true) {
      onRemove();
    }
  }
}
