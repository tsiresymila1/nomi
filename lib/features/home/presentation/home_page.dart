import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/core/widgets/confirm_action_sheet.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gena/features/downloads/data/model_readiness.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/presentation/widgets/field_wrapper.dart';
import 'package:gena/features/workspace/data/providers/workspace_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String _selectedEmbedderModel = _defaultEmbedderModel;
  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _showContent = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(workspaceChatGroupsProvider);
    final modelsAsync = ref.watch(modelRepositoryProvider);
    final installedAsync = ref.watch(modelInstallerProvider);
    final selectedModelId = ref.watch(selectedModelIdProvider);
    final embedderState = ref.watch(workspaceEmbedderInstallStateProvider);

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
                Row(children: [Text("Models", style: TextStyle(fontSize: 12))]),
                const SizedBox(height: 4),
                modelsAsync.when(
                  data: (models) => installedAsync.when(
                    data: (installedModels) => _buildModelSection(
                      context: context,
                      models: models,
                      installedModels: installedModels,
                      selectedModelId: selectedModelId,
                      embedderStatus: embedderState.message,
                    ).animate().fadeIn(duration: 220.ms, delay: 40.ms),
                    loading: () => const _LoadingCard(),
                    error: (error, _) => _ErrorCard(message: '$error'),
                  ),
                  loading: () => const _LoadingCard(),
                  error: (error, _) => _ErrorCard(message: '$error'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text("Workspaces", style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: groupsAsync.when(
                    data: (groups) {
                      if (groups.isEmpty) {
                        return const Center(child: Text('No workspace yet'));
                      }
                      return ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final delayMs = index * 50;
                          final threadCount = group.chats.length;
                          return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ExpansionTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide.none,
                                  ),
                                  collapsedShape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide.none,
                                  ),
                                  title: Text(
                                    group.workspace.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$threadCount thread${threadCount == 1 ? '' : 's'}',
                                  ),
                                  children: [
                                    if (group.chats.isEmpty)
                                      const ListTile(
                                        dense: true,
                                        title: Text('No thread yet'),
                                      )
                                    else
                                      for (final chat in group.chats.take(5))
                                        ListTile(
                                          dense: true,
                                          leading: HugeIcon(
                                            icon: HugeIcons.strokeRoundedChat01,
                                            size: 16,
                                          ),
                                          title: Text(
                                            chat.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ListTile(
                                      leading: HugeIcon(
                                        icon: HugeIcons.strokeRoundedLink01,
                                      ),
                                      title: const Text(
                                        'Open Workspace Chat',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      onTap: () => unawaited(
                                        _openWorkspaceChat(group.workspace.id),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .animate()
                              .fade(duration: 500.ms, delay: delayMs.ms)
                              .scale(
                                delay: (delayMs + 120).ms,
                                duration: 260.ms,
                                begin: const Offset(0.98, 0.98),
                                end: const Offset(1, 1),
                                curve: Curves.easeOutCubic,
                              );
                        },
                      );
                    },
                    loading: () => Center(
                      child: SizedBox(
                        width: 40,
                        height: 18,
                        child: SpinKitThreeBounce(
                          size: 18,
                          color: Theme.of(context).colorScheme.primaryContainer,
                        ),
                      ),
                    ),
                    error: (error, _) =>
                        Center(child: Text('Workspace error: $error')),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => unawaited(_showCreateWorkspaceDialog()),
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
  }

  Widget _buildModelSection({
    required BuildContext context,
    required List<ModelInfo> models,
    required List<String> installedModels,
    required int? selectedModelId,
    required String embedderStatus,
  }) {
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
                  onPressed: () => unawaited(_resetSeededModels()),
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text(
                    'Reset Seed',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.pushNamed('download'),
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
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () => unawaited(_showChatModelPicker(readyModels)),
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
                _selectedEmbedderModel == _defaultEmbedderModel
                    ? 'EmbeddingGemma 300M'
                    : _selectedEmbedderModel,
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () => unawaited(_showEmbedderPicker()),
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
                  onPressed: () => unawaited(_installOrCheckEmbedder()),
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

  Future<void> _showChatModelPicker(List<ModelInfo> readyModels) async {
    final selectedId = ref.read(selectedModelIdProvider);
    await showModalBottomSheet<void>(
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
              trailing: selectedId == null
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () async {
                await ref
                    .read(selectedModelIdProvider.notifier)
                    .clearSelection();
                ref.invalidate(activeGemmaModelRuntimeProvider);
                ref.invalidate(activeGemmaChatProvider);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
            for (final model in readyModels)
              ListTile(
                title: Text(model.name, style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  model.provider == ModelProviderType.remote
                      ? 'Remote'
                      : 'Local',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: selectedId == model.id
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () async {
                  await ref.read(chatPageActionsProvider).selectModel(model);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _showEmbedderPicker() async {
    await showModalBottomSheet<void>(
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
              trailing: _selectedEmbedderModel == _defaultEmbedderModel
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () {
                setState(() => _selectedEmbedderModel = _defaultEmbedderModel);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _installOrCheckEmbedder() async {
    try {
      await ref
          .read(workspaceEmbedderInstallStateProvider.notifier)
          .ensureInstalled();
      await AppToast.show('Embedder is ready', type: AppToastType.success);
    } catch (e) {
      await AppToast.show(
        'Embedder install failed: $e',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _resetSeededModels() async {
    final shouldReset = await showConfirmActionSheet(
      context,
      title: 'Reset model seeds',
      message:
          'This will remove all model rows from the database and inject the default seeded list again.',
      confirmLabel: 'Reset',
    );

    if (!shouldReset) return;

    try {
      await ref
          .read(modelRepositoryActionsProvider)
          .clearAndReseedDefaultModels();
      await ref.read(selectedModelIdProvider.notifier).clearSelection();
      ref.invalidate(modelInstallerProvider);
      ref.invalidate(activeGemmaModelRuntimeProvider);
      ref.invalidate(activeGemmaChatProvider);
      await AppToast.show('Seed list re-injected.', type: AppToastType.success);
    } catch (e) {
      await AppToast.show('Reset failed: $e', type: AppToastType.error);
    }
  }

  Future<void> _openWorkspaceChat(String workspaceId) async {
    await ref.read(chatPageActionsProvider).selectWorkspace(workspaceId);
    if (!mounted) return;
    context.goNamed('chat');
  }

  Future<void> _showCreateWorkspaceDialog() async {
    final controller = TextEditingController();
    final shouldCreate = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 400),
        reverseDuration: Duration(milliseconds: 200),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New workspace',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              FieldWrapper(
                label: 'Name',
                field: TextField(
                  controller: controller,
                  maxLength: 64,
                  decoration: const InputDecoration(
                    hintText: 'My workspace',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Create'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (shouldCreate != true) return;
    try {
      await ref.read(workspaceActionsProvider).createWorkspace(controller.text);
      if (!mounted) return;
      context.goNamed('chat');
    } catch (e) {
      await AppToast.show('$e', type: AppToastType.error);
    }
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
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
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
    );
  }
}

const String _defaultEmbedderModel = 'embeddinggemma_300m';
