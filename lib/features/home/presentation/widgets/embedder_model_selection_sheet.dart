import 'package:flutter/material.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/downloads/data/default_embedder_models.dart';
import 'package:gena/features/downloads/data/services/model_catalog_insights_service.dart';
import 'package:gena/features/downloads/presentation/widgets/model_device_summary_card.dart';

class EmbedderModelSelectionSheet extends StatelessWidget {
  const EmbedderModelSelectionSheet({
    required this.selectedModelKey,
    required this.onSelect,
    super.key,
  });

  final String selectedModelKey;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final insightsService = sl<ModelCatalogInsightsService>();

    return FutureBuilder(
      future: Future.wait([
        insightsService.getDeviceInfo(),
        Future.wait(
          kDefaultEmbedderModels.map(
            (model) => insightsService.describeEmbedderModel(model.key),
          ),
        ),
      ]),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final deviceInfo = data != null && data.isNotEmpty ? data[0] : null;
        final rawInsights = data != null && data.length > 1 ? data[1] : null;
        final insightList = rawInsights is List<ModelCatalogInsight>
            ? rawInsights
            : const <ModelCatalogInsight>[];
        final visibleModels = <_EmbedderItem>[];
        for (var i = 0; i < kDefaultEmbedderModels.length; i++) {
          final model = kDefaultEmbedderModels[i];
          final insight = i < insightList.length ? insightList[i] : null;
          if (insight != null && !insight.compatible) {
            continue;
          }
          visibleModels.add(_EmbedderItem(model: model, insight: insight));
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Embedder Models',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              if (deviceInfo != null) ...[
                ModelDeviceSummaryCard(
                  deviceInfo: deviceInfo as dynamic,
                  compact: true,
                ),
                const SizedBox(height: 8),
              ],
              if (visibleModels.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No compatible embedder models for this device.'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: visibleModels.length,
                    itemBuilder: (context, index) {
                      final item = visibleModels[index];
                      final isSelected = selectedModelKey == item.model.key;
                      return ListTile(
                        selected: isSelected,
                        title: Text(
                          item.model.displayName,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${item.model.sizeLabel} · ${item.insight?.statusLabel ?? "Checking"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_rounded)
                            : const Icon(Icons.chevron_right),
                        onTap: () {
                          onSelect(item.model.key);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EmbedderItem {
  const _EmbedderItem({required this.model, required this.insight});

  final DefaultEmbedderModel model;
  final ModelCatalogInsight? insight;
}
