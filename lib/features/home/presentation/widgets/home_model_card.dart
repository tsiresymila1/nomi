import 'package:flutter/material.dart';
import 'package:gena/features/downloads/data/model_readiness.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';

class HomeModelCard extends StatelessWidget {
  const HomeModelCard({
    required this.models,
    required this.installedModels,
    required this.selectedModelId,
    required this.embedderStatus,
    required this.selectedEmbedderModel,
    required this.onResetSeed,
    required this.onOpenModels,
    required this.onSelectModel,
    required this.onClearModel,
    required this.onSelectEmbedder,
    required this.onInstallOrCheckEmbedder,
    super.key,
  });

  final List<ModelInfo> models;
  final List<String> installedModels;
  final int? selectedModelId;
  final String embedderStatus;
  final String selectedEmbedderModel;
  final VoidCallback onResetSeed;
  final VoidCallback onOpenModels;
  final Future<void> Function(ModelInfo model) onSelectModel;
  final Future<void> Function() onClearModel;
  final ValueChanged<String> onSelectEmbedder;
  final Future<void> Function() onInstallOrCheckEmbedder;

  @override
  Widget build(BuildContext context) {
    final readyModels = models
        .where(
          (model) =>
              model.provider == ModelProviderType.remote ||
              isModelReady(model, installedModels),
        )
        .toList(growable: false);

    ModelInfo? selected;
    for (final model in readyModels) {
      if (model.id == selectedModelId) {
        selected = model;
        break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Model Defaults',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: onResetSeed,
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text(
                    'Reset Seed',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: onOpenModels,
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Models', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.smart_toy_outlined),
              title: const Text(
                'Default chat model',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                selected == null
                    ? 'No model selected'
                    : '${selected.name} (${selected.provider == ModelProviderType.remote ? "Remote" : "Local"})',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () => _showChatModelPicker(context, readyModels),
            ),
            const Divider(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.memory_outlined),
              title: const Text(
                'Embedder model',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                selectedEmbedderModel == 'embeddinggemma_300m'
                    ? 'EmbeddingGemma 300M'
                    : selectedEmbedderModel,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () => _showEmbedderPicker(context),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    embedderStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onInstallOrCheckEmbedder,
                  child: const Text(
                    'Install/Check',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChatModelPicker(
    BuildContext context,
    List<ModelInfo> readyModels,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Select Chat Model',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text(
                'No model selected',
                style: TextStyle(fontSize: 13),
              ),
              trailing: selectedModelId == null
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () async {
                await onClearModel();
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
            for (final model in readyModels)
              ListTile(
                title: Text(model.name, style: const TextStyle(fontSize: 14)),
                subtitle: Text(
                  model.provider == ModelProviderType.remote
                      ? 'Remote'
                      : 'Local',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: selectedModelId == model.id
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () async {
                  await onSelectModel(model);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _showEmbedderPicker(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Select Embedder Model',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text(
                'EmbeddingGemma 300M',
                style: TextStyle(fontSize: 14),
              ),
              trailing: selectedEmbedderModel == 'embeddinggemma_300m'
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () {
                onSelectEmbedder('embeddinggemma_300m');
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
