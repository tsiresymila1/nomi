import 'package:flutter/material.dart';
import 'package:gena/core/services/device_system_info_service.dart';
import 'package:gena/features/downloads/data/services/model_catalog_insights_service.dart';

class ModelDeviceSummaryCard extends StatelessWidget {
  const ModelDeviceSummaryCard({
    required this.deviceInfo,
    this.storageInsights,
    this.compact = false,
    super.key,
  });

  final DeviceSystemInfo deviceInfo;
  final StorageInsights? storageInsights;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget statChip(String label, String value, IconData icon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              '$label $value',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              compact ? 'Device' : 'Device Capacity',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                statChip(
                  'RAM',
                  _formatBytes(deviceInfo.totalRamBytes),
                  Icons.memory,
                ),
                statChip(
                  'CPU',
                  '${deviceInfo.cpuCores} cores',
                  Icons.developer_board,
                ),
                statChip(
                  'GPU',
                  _truncate(deviceInfo.gpuModel),
                  Icons.videogame_asset_outlined,
                ),
                if (storageInsights != null)
                  statChip(
                    'Model storage',
                    _formatBytes(storageInsights!.modelFilesBytes),
                    Icons.folder_outlined,
                  ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 10),
              Text(
                'CPU: ${deviceInfo.cpuModel}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'GPU: ${deviceInfo.gpuModel}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (storageInsights != null)
                Text(
                  'Models on disk: ${storageInsights!.modelFileCount} file(s), ${_formatBytes(storageInsights!.modelFilesBytes)} used, ${_formatBytes(storageInsights!.freeStorageBytes)} free.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return 'Unknown';
    const gb = 1024 * 1024 * 1024;
    const mb = 1024 * 1024;
    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(1)}GB';
    }
    return '${(bytes / mb).toStringAsFixed(0)}MB';
  }

  String _truncate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == 'Unknown GPU') return 'Unknown';
    if (trimmed.length <= 22) return trimmed;
    return '${trimmed.substring(0, 22)}...';
  }
}
