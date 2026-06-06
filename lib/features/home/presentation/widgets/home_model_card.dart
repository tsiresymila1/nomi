import 'package:flutter/material.dart';
import 'package:gena/features/chat/presentation/widgets/chat_model_selection_sheet.dart';
import 'package:gena/features/downloads/data/default_embedder_models.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/home/presentation/widgets/embedder_model_selection_sheet.dart';

class HomeModelCard extends StatelessWidget {
  const HomeModelCard({
    required this.models,
    required this.selectedModelId,
    required this.embedderStatus,
    required this.selectedEmbedderModel,
    required this.onResetSeed,
    required this.onOpenModels,
    required this.onSelectEmbedder,
    required this.onInstallOrCheckEmbedder,
    super.key,
  });

  final List<ModelInfo> models;
  final int? selectedModelId;
  final String embedderStatus;
  final String selectedEmbedderModel;
  final VoidCallback onResetSeed;
  final VoidCallback onOpenModels;
  final ValueChanged<String> onSelectEmbedder;
  final Future<void> Function() onInstallOrCheckEmbedder;

  @override
  Widget build(BuildContext context) {
    ModelInfo? selected;
    for (final model in models) {
      if (model.id == selectedModelId) {
        selected = model;
        break;
      }
    }

    final selectedEmbedder = findDefaultEmbedderModel(selectedEmbedderModel);

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
              onTap: () => _showChatModelPicker(context),
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
                selectedEmbedder == null
                    ? selectedEmbedderModel
                    : '${selectedEmbedder.displayName} (${selectedEmbedder.sizeLabel})',
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

  Future<void> _showChatModelPicker(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 400),
        reverseDuration: Duration(milliseconds: 200),
      ),
      builder: (_) => const SafeArea(child: ChatModelSelectionSheet()),
    );
  }

  Future<void> _showEmbedderPicker(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 400),
        reverseDuration: Duration(milliseconds: 200),
      ),
      builder: (context) => EmbedderModelSelectionSheet(
        selectedModelKey: selectedEmbedderModel,
        onSelect: onSelectEmbedder,
      ),
    );
  }
}
