import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/chat_provider.dart';
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

    return AppBar(
      scrolledUnderElevation: 2,
      elevation: 2,
      title: InkWell(
        onTap: () => _showModelSelector(context, ref),
        child: Column(
          children: [
            const Text(
              'Gena',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).highlightColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                modelLabel,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: modelColor),
              ),
            ),
          ],
        ),
      ),
      centerTitle: true,
      leading: Builder(
        builder: (context) {
          return IconButton(
            icon: const Icon(Icons.menu),
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
          icon: const Icon(Icons.settings),
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
          final installedId = _installedModelIdFromSource(model.source);
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

  String _installedModelIdFromSource(String source) {
    final parts = source.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? source : parts.last;
  }
}
