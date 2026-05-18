import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/providers/active_model_info_provider.dart';
import 'package:gena/features/chat/data/providers/chat_model_switching_provider.dart';
import 'package:gena/features/chat/data/providers/chat_session_provider.dart';
import 'package:gena/features/chat/data/providers/chat_thread_actions_provider.dart';
import 'package:gena/features/chat/data/providers/selected_chat_provider.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/providers/download_notifier.dart';

final chatPageActionsProvider = Provider<ChatPageActions>(
  (ref) => ChatPageActions(ref),
);

class ChatPageActions {
  final Ref ref;
  ChatPageActions(this.ref);

  Future<void> createNewThread() async {
    await ref.read(chatThreadActionsProvider).stopGeneration();
    await ref.read(selectedChatIdProvider.notifier).createNewThread();
  }

  Future<void> selectChat(String chatId) async {
    await ref.read(chatThreadActionsProvider).stopGeneration();
    ref.read(selectedChatIdProvider.notifier).selectChat(chatId);
  }

  Future<void> installModel(ModelInfo model) async {
    final hasActiveInstall = ref.read(activeModelInstallProvider) != null;
    final isSwitching = ref.read(chatModelSwitchingProvider);
    if (hasActiveInstall || isSwitching) {
      await AppToast.show(
        'Model is already installing/loading. Please wait.',
        type: AppToastType.info,
      );
      return;
    }

    ref.read(chatModelSwitchingProvider.notifier).start();
    try {
      await ref.read(chatThreadActionsProvider).stopGeneration();
      await ref.read(downloadProvider.notifier).installModel(model);
      ref.invalidate(activeModelInfoProvider);
      ref.invalidate(activeGemmaModelRuntimeProvider);
      ref.invalidate(activeGemmaChatProvider);
    } catch (e) {
      await AppToast.show(
        'Failed to install model: $e',
        type: AppToastType.error,
      );
      rethrow;
    } finally {
      ref.read(chatModelSwitchingProvider.notifier).stop();
    }
  }
}
