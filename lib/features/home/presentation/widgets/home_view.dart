import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/core/widgets/confirm_action_sheet.dart';
import 'package:gena/features/home/presentation/cubit/home_cubit.dart';
import 'package:gena/features/home/presentation/cubit/home_state.dart';
import 'package:gena/features/home/presentation/widgets/create_workspace_sheet.dart';
import 'package:gena/features/home/presentation/widgets/home_model_card.dart';
import 'package:gena/features/home/presentation/widgets/home_workspace_list.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showContent = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/logo.png', width: 40, height: 40),
                const SizedBox(width: 8),
                const Text(
                  'Nomi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedSettings02),
                  tooltip: 'Settings',
                  onPressed: () => context.pushNamed('setting'),
                ),
              ),
            ],
          ),
          body: AnimatedOpacity(
            opacity: _showContent ? 1 : 0,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            child: AnimatedSlide(
              offset: _showContent ? Offset.zero : const Offset(0, 0.08),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Text('Models', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (state.loading && state.models.isEmpty)
                      _loadingCard(context)
                    else
                      HomeModelCard(
                        models: state.models,
                        installedModels: state.installedModels,
                        selectedModelId: state.selectedModelId,
                        embedderStatus: state.embedderStatus,
                        selectedEmbedderModel: state.selectedEmbedderModel,
                        onResetSeed: () => _resetSeededModels(context),
                        onOpenModels: () => context.pushNamed('download'),
                        onSelectModel: (model) async {
                          await context.read<HomeCubit>().setSelectedModel(
                            model.id,
                          );
                        },
                        onClearModel: () async {
                          await context.read<HomeCubit>().setSelectedModel(
                            null,
                          );
                        },
                        onSelectEmbedder: (value) {
                          context.read<HomeCubit>().setSelectedEmbedderModel(
                            value,
                          );
                        },
                        onInstallOrCheckEmbedder: () async {
                          try {
                            await context
                                .read<HomeCubit>()
                                .installOrCheckEmbedder();
                            await AppToast.show(
                              'Embedder is ready',
                              type: AppToastType.success,
                            );
                          } catch (error) {
                            await AppToast.show(
                              'Embedder install failed: $error',
                              type: AppToastType.error,
                            );
                          }
                        },
                      ).animate().fadeIn(duration: 220.ms, delay: 40.ms),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Text('Workspaces', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: state.loading && state.groups.isEmpty
                          ? Center(
                              child: SizedBox(
                                width: 40,
                                height: 18,
                                child: SpinKitThreeBounce(
                                  size: 18,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                ),
                              ),
                            )
                          : HomeWorkspaceList(
                              groups: state.groups,
                              onOpenWorkspaceChat: (workspaceId) async {
                                await context
                                    .read<HomeCubit>()
                                    .ensureWorkspaceChatSelection(workspaceId);
                                if (context.mounted) context.goNamed('chat');
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              unawaited(_showCreateWorkspaceDialog(context)),
                          icon: const Icon(Icons.add_business_outlined),
                          label: const Text('Create New Workspace'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _loadingCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 40,
            height: 18,
            child: SpinKitThreeBounce(
              size: 18,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resetSeededModels(BuildContext context) async {
    final homeCubit = context.read<HomeCubit>();
    final shouldReset = await showConfirmActionSheet(
      context,
      title: 'Reset model seeds',
      message:
          'This will remove all model rows from the database and inject the default seeded list again.',
      confirmLabel: 'Reset',
    );
    if (!shouldReset) return;
    try {
      await homeCubit.resetSeededModels();
      if (!context.mounted) return;
      await AppToast.show('Seed list re-injected.', type: AppToastType.success);
    } catch (error) {
      if (!context.mounted) return;
      await AppToast.show('Reset failed: $error', type: AppToastType.error);
    }
  }

  Future<void> _showCreateWorkspaceDialog(BuildContext context) async {
    final homeCubit = context.read<HomeCubit>();
    final controller = TextEditingController();
    final shouldCreate = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 400),
        reverseDuration: Duration(milliseconds: 200),
      ),
      builder: (context) {
        return CreateWorkspaceSheet(controller: controller);
      },
    );
    if (shouldCreate != true) return;
    try {
      final selection = await homeCubit.createWorkspace(controller.text);
      final workspaceId = selection.split(':').first;
      await homeCubit.ensureWorkspaceChatSelection(workspaceId);
      if (!context.mounted) return;
      if (context.mounted) context.goNamed('chat');
    } catch (error) {
      if (!context.mounted) return;
      await AppToast.show('$error', type: AppToastType.error);
    }
  }
}
