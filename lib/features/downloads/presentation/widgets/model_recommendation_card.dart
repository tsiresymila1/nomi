import 'package:flutter/material.dart';
import 'package:gena/core/services/device_system_info_service.dart';
import 'package:gena/features/downloads/data/services/model_catalog_insights_service.dart';

class ModelRecommendationCard extends StatelessWidget {
  const ModelRecommendationCard({
    required this.deviceInfo,
    required this.insight,
    super.key,
  });

  final DeviceSystemInfo deviceInfo;
  final ModelCatalogInsight insight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlight = !insight.compatible
        ? colorScheme.error
        : insight.recommended
        ? colorScheme.primary
        : colorScheme.tertiary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Compatibility',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: highlight.withAlpha(24),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    insight.statusLabel,
                    style: TextStyle(
                      color: highlight,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Role: ${insight.usage == ModelUsage.embedder ? "Embedder" : "Chat LLM"}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Estimated model size: ${insight.sizeLabel ?? "Unknown"}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Recommended RAM: ${_formatBytes(insight.recommendedRamBytes)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Device RAM: ${_formatBytes(deviceInfo.totalRamBytes)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
}
