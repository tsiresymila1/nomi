import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gena/features/chat/presentation/widgets/chat_model_selection_sheet.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const ChatAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGemmaChat = ref.watch(activeGemmaChatProvider);
    final modelsAsync = ref.watch(modelRepositoryProvider);
    final modelLabel = _resolveModelLabel(modelsAsync, activeGemmaChat);
    final modelColor = activeGemmaChat.maybeWhen(
      data: (session) => session == null ? Colors.red : null,
      orElse: () => null,
    );
    final primaryColor = Theme.of(context).colorScheme.primary.withAlpha(5);

    return AppBar(
      scrolledUnderElevation: 0,
      elevation: 0,
      backgroundColor: primaryColor,
      surfaceTintColor: primaryColor,
      shadowColor: primaryColor,
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
                style: TextStyle(fontSize: 12, color: modelColor),
              ),
              Icon(Icons.arrow_drop_down)
            ],
          ),
        ),
      ),
      centerTitle: true,
      leading: Builder(
        builder: (context) {
          return IconButton(
            icon: const Icon(LucideIcons.textAlignStart600),
            onPressed: () => Scaffold.of(context).openDrawer(),
          );
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(LucideIcons.squarePen500, size: 20),
          onPressed: () => ref.read(chatPageActionsProvider).createNewThread(),
        ),
        IconButton(
          icon: const Icon(LucideIcons.slidersHorizontal),
          onPressed: () => context.pushNamed('model-setting'),
        ),
      ],
    );
  }

  Future<void> _showModelSelector(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
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
  ) {
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
