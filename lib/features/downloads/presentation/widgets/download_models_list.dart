import 'dart:io';

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
    return const _DownloadModelsListBody();
  }
}

class _DownloadModelsListBody extends ConsumerStatefulWidget {
  const _DownloadModelsListBody();

  @override
  ConsumerState<_DownloadModelsListBody> createState() =>
      _DownloadModelsListState();
}

class _DownloadModelsListState extends ConsumerState<_DownloadModelsListBody> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _hideLocal = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          data: (installed) {
            final filteredModels = models
                .where((model) {
                  if (_hideLocal && model.provider == ModelProviderType.local) {
                    return false;
                  }

                  final query = _searchQuery.trim().toLowerCase();
                  if (query.isEmpty) return true;

                  return model.name.toLowerCase().contains(query) ||
                      model.description.toLowerCase().contains(query) ||
                      model.modelType.toLowerCase().contains(query);
                })
                .toList(growable: false);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search models',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchQuery.trim().isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilterChip(
                          label: const Text('Hide local models'),
                          selected: _hideLocal,
                          onSelected: (selected) {
                            setState(() => _hideLocal = selected);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredModels.isNotEmpty
                      ? ListView.builder(
                          itemCount: filteredModels.length,
                          itemBuilder: (context, index) {
                            final model = filteredModels[index];
                            final installKey = downloadNotifier
                                .installKeyForModel(model);
                            final progress = downloads[installKey];
                            final installedId = downloadNotifier
                                .installedIdForModel(model);
                            final hasSourceFile =
                                model.sourceType == 'file' &&
                                File(model.source).existsSync();
                            final localInstalled =
                                installed.contains(installedId) ||
                                progress == 1.0;
                            final isInstalled =
                                model.provider == ModelProviderType.remote ||
                                (hasSourceFile && localInstalled);
                            final isStatic = isDefaultStaticModel(model);
                            final canRemove = !isStatic;
                            final canDeleteDownloadedFile =
                                isStatic && hasSourceFile;
                            return DownloadItem(
                                  model: model,
                                  progress: progress,
                                  isInstalled: isInstalled,
                                  canRemove: canRemove,
                                  canDeleteDownloadedFile:
                                      canDeleteDownloadedFile,
                                  onDownload: () {
                                    ref
                                        .read(downloadProvider.notifier)
                                        .installModel(model);
                                  },
                                  onEdit: () {
                                    context.pushNamed(
                                      'add-model',
                                      extra: model,
                                    );
                                  },
                                  onRemove: () {
                                    ref
                                        .read(downloadProvider.notifier)
                                        .removeModel(model);
                                  },
                                  onCancelDownload: () {
                                    ref
                                        .read(downloadProvider.notifier)
                                        .cancelDownload(model);
                                  },
                                  onDeleteDownloadedFile: () {
                                    ref
                                        .read(downloadProvider.notifier)
                                        .deleteDownloadedFileForStaticModel(
                                          model,
                                        );
                                  },
                                )
                                .animate()
                                .fadeIn(
                                  duration: 220.ms,
                                  delay: (index * 35).ms,
                                )
                                .slideY(begin: 0.06, end: 0);
                          },
                        )
                      : const Center(
                          child: Text(
                            'No models match your search/filter',
                            style: TextStyle(fontSize: 13),
                          ),
                        ).animate().fade(duration: 500.ms).scale(delay: 500.ms),
                ),
              ],
            );
          },
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
