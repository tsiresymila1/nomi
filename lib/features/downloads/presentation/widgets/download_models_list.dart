import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/core/services/device_system_info_service.dart';
import 'package:gena/features/downloads/data/default_static_models.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/data/services/model_catalog_insights_service.dart';
import 'package:gena/features/downloads/data/services/download_notifier_service.dart';
import 'package:gena/features/downloads/presentation/widgets/model_device_summary_card.dart';
import 'package:gena/features/downloads/presentation/widgets/download_item.dart';
import 'package:go_router/go_router.dart';

class DownloadModelsList extends StatefulWidget {
  const DownloadModelsList({super.key});

  @override
  State<DownloadModelsList> createState() => _DownloadModelsListState();
}

class _DownloadModelsListState extends State<DownloadModelsList> {
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

    return BlocBuilder<DownloadsCubit, DownloadsState>(
      builder: (context, state) {
        if (state.loading) {
          return reveal(const Center(child: CircularProgressIndicator()));
        }
        if (state.errorMessage != null && state.models.isEmpty) {
          return reveal(Center(child: Text('Error: ${state.errorMessage}')));
        }

        final cubit = context.read<DownloadsCubit>();
        final insightsService = sl<ModelCatalogInsightsService>();

        return FutureBuilder(
          future: Future.wait([
            insightsService.getDeviceInfo(),
            insightsService.getStorageInsights(),
          ]),
          builder: (context, snapshot) {
            final data = snapshot.data;
            final deviceInfo = data != null && data.isNotEmpty
                ? data[0] as DeviceSystemInfo
                : null;
            final storageInsights = data != null && data.length > 1
                ? data[1] as StorageInsights
                : null;

            final visibleModels = <_VisibleModel>[];
            var hiddenIncompatible = 0;
            for (final model in state.models) {
              if (_hideLocal && model.provider == ModelProviderType.local) {
                continue;
              }
              final query = _searchQuery.trim().toLowerCase();
              if (query.isNotEmpty &&
                  !model.name.toLowerCase().contains(query) &&
                  !model.description.toLowerCase().contains(query) &&
                  !model.modelType.toLowerCase().contains(query)) {
                continue;
              }
              final insight = deviceInfo == null
                  ? null
                  : insightsService.describeLlmModel(
                      model,
                      deviceInfo: deviceInfo,
                    );
              if (insight != null && !insight.compatible) {
                hiddenIncompatible += 1;
                continue;
              }
              visibleModels.add(_VisibleModel(model: model, insight: insight));
            }

            visibleModels.sort((a, b) {
              final aRecommended = a.insight?.recommended == true ? 0 : 1;
              final bRecommended = b.insight?.recommended == true ? 0 : 1;
              if (aRecommended != bRecommended) {
                return aRecommended.compareTo(bRecommended);
              }
              return a.model.name.toLowerCase().compareTo(
                b.model.name.toLowerCase(),
              );
            });

            return Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                    child: Column(
                      children: [
                        if (deviceInfo != null)
                          ModelDeviceSummaryCard(
                            deviceInfo: deviceInfo,
                            storageInsights: storageInsights,
                            compact: true,
                          ),
                        if (deviceInfo != null) const SizedBox(height: 8),
                        TextField(
                          controller: _searchController,
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
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
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                label: const Text('Hide local models'),
                                selected: _hideLocal,
                                onSelected: (selected) {
                                  setState(() => _hideLocal = selected);
                                },
                              ),
                              if (hiddenIncompatible > 0)
                                Chip(
                                  label: Text(
                                    '$hiddenIncompatible incompatible hidden',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: visibleModels.isEmpty
                        ? const Center(
                            child: Text(
                              'No compatible models match your search/filter',
                              style: TextStyle(fontSize: 13),
                            ),
                          ).animate().fade(duration: 500.ms).scale(delay: 500.ms)
                        : ListView.builder(
                            itemCount: visibleModels.length,
                            itemBuilder: (context, index) {
                              final item = visibleModels[index];
                              final model = item.model;
                              final installKey = cubit.installKeyForModel(
                                model,
                              );
                              final progress = state.progressByKey[installKey];
                              final installedId = cubit.installedIdForModel(
                                model,
                              );
                              final hasSourceFile =
                                  model.sourceType == 'file' &&
                                  File(model.source).existsSync();
                              final localInstalled =
                                  state.installedModels.contains(installedId) ||
                                  progress == 1.0;
                              final isInstalled =
                                  model.provider == ModelProviderType.remote ||
                                  (hasSourceFile && localInstalled);
                              final isStatic = isDefaultStaticModel(model);
                              return DownloadItem(
                                    model: model,
                                    insight: item.insight,
                                    progress: progress,
                                    isInstalled: isInstalled,
                                    canRemove: !isStatic,
                                    canDeleteDownloadedFile:
                                        isStatic && hasSourceFile,
                                    onDownload: () => cubit.installModel(model),
                                    onEdit: () {
                                      context.pushNamed(
                                        'add-model',
                                        extra: model,
                                      );
                                    },
                                    onRemove: () => cubit.removeModel(model),
                                    onCancelDownload: () {
                                      cubit.cancelDownload(model);
                                    },
                                    onDeleteDownloadedFile: () {
                                      cubit.deleteDownloadedFileForStaticModel(
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
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _VisibleModel {
  const _VisibleModel({required this.model, required this.insight});

  final ModelInfo model;
  final ModelCatalogInsight? insight;
}
