import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/model_readiness.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/data/providers/download_notifier.dart';
import 'package:go_router/go_router.dart';

class ChatModelSelectionSheet extends ConsumerWidget {
  const ChatModelSelectionSheet({super.key});

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
    final installedAsync = ref.watch(modelInstallerProvider);
    final downloads = ref.watch(downloadProvider);
    final downloadNotifier = ref.read(downloadProvider.notifier);
    final selectedId = ref.watch(selectedModelIdProvider);
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
          modelsAsync.when(
            data: (models) => installedAsync.when(
              data: (installedModels) {
                if (models.isEmpty) {
                  return reveal(
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('No models. Add one from Download page.'),
                      ),
                    ),
                  );
                }
                return Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: models.length,
                    itemBuilder: (context, index) {
                      final model = models[index];
                      final isReady = isModelReady(model, installedModels);
                      final installKey = downloadNotifier.installKeyForModel(
                        model,
                      );
                      final progress = downloads[installKey];
                      final isDownloading =
                          model.provider == ModelProviderType.local &&
                          progress != null &&
                          progress >= 0 &&
                          progress < 1;
                      final isSelected = selectedId == model.id;
                      final localNotReady =
                          model.provider == ModelProviderType.local && !isReady;
                      final isSelectable = !localNotReady && !isDownloading;
                      final statusLabel =
                          model.provider == ModelProviderType.remote
                          ? 'Ready'
                          : isDownloading
                          ? 'Downloading ${(progress * 100).toStringAsFixed(0)}%'
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
                                : isDownloading
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: progress,
                                    ),
                                  )
                                : const Icon(Icons.chevron_right),
                            onTap: () async {
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
                              final actions = ref.read(chatPageActionsProvider);
                              Navigator.of(context).pop();
                              unawaited(actions.selectModel(model));
                            },
                          )
                          .animate()
                          .fadeIn(duration: 300.ms, delay: (index * 30).ms)
                          .slideY(begin: 0.06, end: 0);
                    },
                  ),
                );
              },
              loading: () => reveal(
                const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 4),
                  ),
                ),
              ),
              error: (err, stack) => reveal(Center(child: Text('Error: $err'))),
            ),
            loading: () => reveal(
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 4),
                ),
              ),
            ),
            error: (err, stack) => reveal(Center(child: Text('Error: $err'))),
          ),
        ],
      ),
    );
  }
}
