import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/downloads/data/default_static_models.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/data/providers/download_notifier.dart';
import 'package:gena/features/downloads/presentation/widgets/download_item.dart';
import 'package:go_router/go_router.dart';

class DownloadModelsList extends ConsumerWidget {
  const DownloadModelsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget reveal(Widget child, {int delayMs = 0}) {
      return child
          .animate()
          .fade(duration: 500.ms, delay: delayMs.ms)
          .scale(
            delay: (delayMs + 120).ms,
            duration: 260.ms,
            begin: const Offset(0.98, 0.98),
            end: const Offset(1, 1),
            curve: Curves.easeOutCubic,
          );
    }

    final modelsAsync = ref.watch(modelRepositoryProvider);
    final downloads = ref.watch(downloadProvider);
    final installedModels = ref.watch(modelInstallerProvider);
    final downloadNotifier = ref.read(downloadProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(4),
      child: modelsAsync.when(
        data: (models) => installedModels.when(
          data: (installed) => models.isNotEmpty
              ? ListView.builder(
                  itemCount: models.length,
                  itemBuilder: (context, index) {
                    final model = models[index];
                    final installKey = downloadNotifier.installKeyForModel(
                      model,
                    );
                    final progress = downloads[installKey];
                    final installedId = downloadNotifier.installedIdForModel(
                      model,
                    );
                    final isInstalled =
                        model.provider == ModelProviderType.remote ||
                        installed.contains(installedId) ||
                        progress == 1.0;
                    final canRemove = !isDefaultStaticModel(model);
                    return DownloadItem(
                          model: model,
                          progress: progress,
                          isInstalled: isInstalled,
                          canRemove: canRemove,
                          onDownload: () {
                            ref
                                .read(downloadProvider.notifier)
                                .installModel(model);
                          },
                          onEdit: () {
                            context.pushNamed('add-model', extra: model);
                          },
                          onRemove: () {
                            ref
                                .read(downloadProvider.notifier)
                                .removeModel(model);
                          },
                        )
                        .animate()
                        .fadeIn(duration: 220.ms, delay: (index * 35).ms)
                        .slideY(begin: 0.06, end: 0);
                  },
                )
              : const Center(
                  child: Text(
                    'No models, please add a new one',
                    style: TextStyle(fontSize: 13),
                  ),
                ).animate().fade(duration: 500.ms).scale(delay: 500.ms),
          loading: () =>
              reveal(const Center(child: CircularProgressIndicator())),
          error: (err, stack) => reveal(Center(child: Text('Error: $err'))),
        ),
        loading: () => reveal(const Center(child: CircularProgressIndicator())),
        error: (err, stack) => reveal(Center(child: Text('Error: $err'))),
      ),
    );
  }
}
