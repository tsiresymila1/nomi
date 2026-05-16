import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/presentation/providers/download_notifier.dart';
import 'package:gena/features/downloads/presentation/widgets/download_item.dart';

class DownloadModelsList extends ConsumerWidget {
  const DownloadModelsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(modelRepositoryProvider);
    final downloads = ref.watch(downloadProvider);
    final installedModels = ref.watch(modelInstallerProvider);
    final downloadNotifier = ref.read(downloadProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: modelsAsync.when(
        data: (models) => installedModels.when(
          data: (installed) => models.length > 0 ?  ListView.builder(
            itemCount: models.length,
            itemBuilder: (context, index) {
              final model = models[index];
              final installKey = downloadNotifier.installKeyForModel(model);
              final progress = downloads[installKey];
              final installedId = downloadNotifier.installedIdForModel(model);
              final isInstalled =
                  installed.contains(installedId) || progress == 1.0;
              return DownloadItem(
                model: model,
                progress: progress,
                isInstalled: isInstalled,
                onDownload: () {
                  ref.read(downloadProvider.notifier).installModel(model);
                },
                onRemove: () {
                  ref.read(downloadProvider.notifier).removeModel(model);
                },
              );
            },
          ): Center(child: Text("No models, Please add new", style: TextStyle(fontSize: 13),),),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
