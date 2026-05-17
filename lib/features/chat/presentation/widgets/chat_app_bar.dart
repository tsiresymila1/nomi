import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gena/features/chat/presentation/widgets/chat_model_selection_sheet.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/providers/download_notifier.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

class ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final Color gradColor;

  const ChatAppBar({super.key, required this.gradColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGemmaChat = ref.watch(activeGemmaChatProvider);
    final modelsAsync = ref.watch(modelRepositoryProvider);
    final activeRuntime = ref.watch(activeGemmaModelRuntimeProvider);
    final hasActiveInstall = ref.watch(activeModelInstallProvider) != null;
    final isSwitchingModel = ref.watch(chatModelSwitchingProvider);
    final modelLabel = _resolveModelLabel(
      modelsAsync,
      activeGemmaChat,
      activeRuntime,
      isSwitchingModel: isSwitchingModel,
      hasActiveInstall: hasActiveInstall,
    );
    final modelColor = activeGemmaChat.maybeWhen(
      data: (session) => session == null ? Colors.red : null,
      orElse: () => null,
    );

    return AppBar(
      scrolledUnderElevation: 0,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              gradColor.withAlpha(0),
              gradColor.withAlpha(125),
              gradColor.withAlpha(250),
            ],
          ),
        ),
      ),
      title: InkWell(
        onTap: () => _showModelSelector(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            // border: Border.all(color: Theme.of(context).highlightColor),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                modelLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: modelColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              HugeIcon(icon: HugeIcons.strokeRoundedArrowDown01),
            ],
          ),
        ),
      ),
      centerTitle: true,
      leading: Builder(
        builder: (context) {
          return IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedMenu02, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          );
        },
      ),
      actions: [
        IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedPencilEdit02,
            size: 28,
          ),
          onPressed: () => ref.read(chatPageActionsProvider).createNewThread(),
        ),
        IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedSlidersHorizontal,
            size: 28,
          ),
          onPressed: () => context.pushNamed('model-setting'),
        ),
      ],
    );
  }

  Future<void> _showModelSelector(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 400),
        reverseDuration: Duration(milliseconds: 200),
      ),
      builder: (context) {
        return const SafeArea(child: ChatModelSelectionSheet());
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  String _resolveModelLabel(
    AsyncValue<dynamic> modelsAsync,
    AsyncValue<GemmaChatSession?> activeGemmaChat,
    AsyncValue<ActiveGemmaModelRuntime?> activeRuntime, {
    required bool isSwitchingModel,
    required bool hasActiveInstall,
  }) {
    if (isSwitchingModel || hasActiveInstall || activeRuntime.isLoading) {
      return 'Model loading...';
    }
    final runtime = activeRuntime.asData?.value;
    if (runtime == null) {
      return 'No active model';
    }

    final activeSpec =
        gemma.FlutterGemmaPlugin.instance.modelManager.activeInferenceModel;
    final activeModelId = activeSpec is gemma.InferenceModelSpec
        ? activeSpec.name
        : null;

    if (activeModelId == null) {
      return activeGemmaChat.maybeWhen(
        data: (session) =>
            session == null ? 'Model not loaded' : 'Unknown model',
        orElse: () => 'Model loading...',
      );
    }

    return modelsAsync.when(
      data: (models) {
        for (final model in models) {
          final modelId = (model.modelId ?? '').trim();
          if (modelId.isNotEmpty &&
              modelId.toLowerCase() == activeModelId.toLowerCase()) {
            return model.name;
          }

          final installedId = _modelSpecNameFromSource(model.source);
          if (installedId.toLowerCase() == activeModelId.toLowerCase()) {
            return model.name;
          }
        }
        return activeModelId;
      },
      loading: () => activeModelId,
      error: (error, stackTrace) => activeModelId,
    );
  }

  String _modelSpecNameFromSource(String source) {
    final parts = source.split(RegExp(r'[/\\]'));
    final filename = parts.isEmpty ? source : parts.last;
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex <= 0) return filename;
    return filename.substring(0, dotIndex);
  }
}
