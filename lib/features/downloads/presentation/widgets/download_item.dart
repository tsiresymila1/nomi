import 'package:flutter/material.dart';
import 'package:gena/features/downloads/domain/model_info.dart';

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

    return Card(
      child: ListTile(
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
        trailing: isDownloading
            ? SizedBox(
                width: 48,
                child: Text(
                  '${((progress ?? 0) * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 12),
                ),
              )
            : isInstalled
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove model',
                    onPressed: onRemove,
                  ),
                ],
              )
            : IconButton(
                icon: const Icon(Icons.download),
                onPressed: onDownload,
              ),
      ),
    );
  }
}
