import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/presentation/cubit/selected_model_cubit.dart';
import 'package:gena/features/chat/data/services/chat_page_actions_service.dart';
import 'package:gena/features/downloads/data/model_readiness.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/data/services/model_catalog_insights_service.dart';
import 'package:gena/features/downloads/data/services/download_notifier_service.dart';
import 'package:gena/features/downloads/presentation/widgets/model_device_summary_card.dart';
import 'package:go_router/go_router.dart';

class ChatModelSelectionSheet extends StatelessWidget {
  const ChatModelSelectionSheet({super.key});

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

    final downloadsCubit = sl<DownloadsCubit>();
    final selectedModelCubit = sl<SelectedModelCubit>();
    final insightsService = sl<ModelCatalogInsightsService>();

    return BlocBuilder<SelectedModelCubit, int?>(
      bloc: selectedModelCubit,
      builder: (context, selectedId) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Row(
                children: [
                  Text(
                    "Models",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).pop();
                      router.pushNamed('download');
                    },
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Manage'),
                  ),
                ],
              ),
              FutureBuilder(
                future: insightsService.getDeviceInfo(),
                builder: (context, deviceSnapshot) {
                  final deviceInfo = deviceSnapshot.data;
                  return StreamBuilder<DownloadsState>(
                    initialData: downloadsCubit.state,
                    stream: downloadsCubit.stream,
                    builder: (context, snapshot) {
                      final state = snapshot.data ?? downloadsCubit.state;
                      final models = <_ChatSelectableModel>[];
                      for (final model in state.models) {
                        final insight = deviceInfo == null
                            ? null
                            : insightsService.describeLlmModel(
                                model,
                                deviceInfo: deviceInfo,
                              );
                        if (insight != null && !insight.compatible) {
                          continue;
                        }
                        models.add(
                          _ChatSelectableModel(model: model, insight: insight),
                        );
                      }
                      models.sort((a, b) {
                        final aRecommended = a.insight?.recommended == true
                            ? 0
                            : 1;
                        final bRecommended = b.insight?.recommended == true
                            ? 0
                            : 1;
                        if (aRecommended != bRecommended) {
                          return aRecommended.compareTo(bRecommended);
                        }
                        return a.model.name.compareTo(b.model.name);
                      });
                      final installedModels = state.installedModels;
                      final downloads = state.progressByKey;
                      final activeInstall = state.activeInstall;
                      if (models.isEmpty) {
                        return reveal(
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'No compatible chat models. Add one from Download page.',
                              ),
                            ),
                          ),
                        );
                      }
                      return Expanded(
                        child: Column(
                          children: [
                            if (deviceInfo != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ModelDeviceSummaryCard(
                                  deviceInfo: deviceInfo,
                                  compact: true,
                                ),
                              ),
                            Expanded(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: models.length,
                                itemBuilder: (context, index) {
                                  final item = models[index];
                                  final model = item.model;
                                  final isReady = isModelReady(
                                    model,
                                    installedModels,
                                  );
                                  final installKey = downloadsCubit
                                      .installKeyForModel(model);
                                  final progress = downloads[installKey];
                                  final isActiveInstallingThisModel =
                                      activeInstall?.key == installKey;
                                  final isDownloading =
                                      model.provider ==
                                          ModelProviderType.local &&
                                      (isActiveInstallingThisModel ||
                                          (progress != null &&
                                              progress >= 0 &&
                                              progress < 1));
                                  final isSelected = selectedId == model.id;
                                  final downloadProgress = progress ?? 0.0;
                                  final localNotReady =
                                      model.provider ==
                                          ModelProviderType.local &&
                                      !isReady;
                                  final isSelectable =
                                      !localNotReady && !isDownloading;
                                  final statusLabel =
                                      model.provider == ModelProviderType.remote
                                      ? 'Ready'
                                      : item.insight?.recommended == true
                                      ? 'Recommended'
                                      : isActiveInstallingThisModel
                                      ? 'Installing...'
                                      : isDownloading
                                      ? 'Downloading ${(downloadProgress * 100).toStringAsFixed(0)}%'
                                      : localNotReady
                                      ? 'Not installed'
                                      : 'Ready';
                                  return ListTile(
                                        enabled: isSelectable,
                                        selected: isSelected,
                                        title: Text(
                                          model.name,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        subtitle: Text(
                                          '${model.provider == ModelProviderType.remote ? "Remote API" : "Local"} · $statusLabel',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        trailing: isSelected
                                            ? const Icon(Icons.check_rounded)
                                            : isActiveInstallingThisModel
                                            ? IconButton(
                                                tooltip: 'Cancel download',
                                                icon: const Icon(
                                                  Icons.cancel_outlined,
                                                ),
                                                onPressed: () async {
                                                  await downloadsCubit
                                                      .cancelDownload(model);
                                                },
                                              )
                                            : isDownloading
                                            ? SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      value: progress,
                                                    ),
                                              )
                                            : const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          if (isActiveInstallingThisModel) {
                                            await downloadsCubit.cancelDownload(
                                              model,
                                            );
                                            return;
                                          }
                                          if (isDownloading) {
                                            await AppToast.show(
                                              'Model is downloading. Please wait until install is complete.',
                                              type: AppToastType.info,
                                            );
                                            return;
                                          }
                                          if (localNotReady) {
                                            await AppToast.show(
                                              'Model is not installed yet. Install it from Manage.',
                                              type: AppToastType.info,
                                            );
                                            return;
                                          }
                                          final actions = sl<ChatPageActions>();
                                          Navigator.of(context).pop();
                                          unawaited(actions.selectModel(model));
                                        },
                                      )
                                      .animate()
                                      .fadeIn(
                                        duration: 300.ms,
                                        delay: (index * 30).ms,
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
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatSelectableModel {
  const _ChatSelectableModel({required this.model, required this.insight});

  final ModelInfo model;
  final ModelCatalogInsight? insight;
}
