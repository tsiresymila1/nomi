import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gena/features/chat/presentation/widgets/chat_model_selection_sheet.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/providers/download_notifier.dart';
import 'package:hugeicons/hugeicons.dart';

class ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final Color gradColor;

  const ChatAppBar({super.key, required this.gradColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeModel = ref.watch(activeModelInfoProvider);
    final activeGemmaChat = ref.watch(activeGemmaChatProvider);
    final activeRuntime = ref.watch(activeGemmaModelRuntimeProvider);
    final hasActiveInstall = ref.watch(activeModelInstallProvider) != null;
    final isSwitchingModel = ref.watch(chatModelSwitchingProvider);
    final usesLocalRuntime = activeModel?.provider == 'local';
    final isModelLoading =
        isSwitchingModel ||
        hasActiveInstall ||
        (usesLocalRuntime &&
            (activeRuntime.isLoading || activeGemmaChat.isLoading));
    final modelLabel = _resolveModelLabel(activeModel, isModelLoading);
    final modelColor = usesLocalRuntime
        ? activeGemmaChat.maybeWhen(
            data: (session) =>
                isModelLoading ? null : (session == null ? Colors.red : null),
            orElse: () => null,
          )
        : null;

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

  String _resolveModelLabel(ModelInfo? activeModel, bool isModelLoading) {
    if (isModelLoading) {
      return 'Model loading...';
    }
    if (activeModel == null) {
      return 'No active model';
    }
    final providerLabel = activeModel.provider == 'remote' ? 'Remote' : 'Local';
    return '$providerLabel · ${activeModel.name}';
  }
}
