import 'package:flutter/material.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:hugeicons/hugeicons.dart';

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
      elevation: 0,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        leading: HugeIcon(
          icon: HugeIcons.strokeRoundedCpu,
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _capabilityChip(
                  context,
                  label: 'Type: ${model.modelType}',
                  enabled: true,
                ),
                _capabilityChip(
                  context,
                  label: 'Image',
                  enabled: model.supportImage,
                ),
                _capabilityChip(
                  context,
                  label: 'Audio',
                  enabled: model.supportAudio,
                ),
                _capabilityChip(
                  context,
                  label: 'Functions',
                  enabled: model.supportsFunctionCalls,
                ),
                _capabilityChip(
                  context,
                  label: 'Thinking',
                  enabled: model.isThinking,
                ),
              ],
            ),
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
              const HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle03,
                color: Colors.green,
              )
            else if (isNetworkSource)
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Download model',
                onPressed: onDownload,
              )
            else
              IconButton(
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedComputerAdd),
                tooltip: 'Install model',
                onPressed: onDownload,
              ),
            IconButton(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedDelete02),
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

  Widget _capabilityChip(
    BuildContext context, {
    required String label,
    required bool enabled,
  }) {
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
