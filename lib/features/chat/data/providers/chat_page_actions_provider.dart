import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/providers/active_model_info_provider.dart';
import 'package:gena/features/chat/data/providers/chat_model_switching_provider.dart';
import 'package:gena/features/chat/data/providers/chat_session_provider.dart';
import 'package:gena/features/chat/data/providers/chat_thread_actions_provider.dart';
import 'package:gena/features/chat/data/providers/selected_chat_provider.dart';
import 'package:gena/features/downloads/data/model_readiness.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/data/providers/download_notifier.dart';
import 'package:gena/features/workspace/data/providers/workspace_provider.dart';

final chatPageActionsProvider = Provider<ChatPageActions>(
  (ref) => ChatPageActions(ref),
);

class ChatPageActions {
  final Ref ref;
  ChatPageActions(this.ref);

  Future<void> createNewThread() async {
    _requestStopGenerationInBackground();
    await ref.read(selectedChatIdProvider.notifier).createNewThread();
  }

  Future<void> createNewThreadInWorkspace(String workspaceId) async {
    _requestStopGenerationInBackground();
    ref.read(selectedWorkspaceIdProvider.notifier).selectWorkspace(workspaceId);
    await ref
        .read(selectedChatIdProvider.notifier)
        .createNewThread(workspaceId: workspaceId);
  }

  Future<void> selectChat(String chatId) async {
    _requestStopGenerationInBackground();
    ref.read(selectedChatIdProvider.notifier).selectChat(chatId);
  }

  Future<void> selectWorkspace(String workspaceId) async {
    _requestStopGenerationInBackground();
    ref.read(selectedWorkspaceIdProvider.notifier).selectWorkspace(workspaceId);
    await ref
        .read(selectedChatIdProvider.notifier)
        .ensureSelectionForWorkspace(workspaceId);
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
      if (model.provider == ModelProviderType.local) {
        await ref.read(downloadProvider.notifier).installModel(model);
      }
      await _setModelAsActive(model.id);
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

  Future<void> selectModel(ModelInfo model) async {
    final hasActiveInstall = ref.read(activeModelInstallProvider) != null;
    final isSwitching = ref.read(chatModelSwitchingProvider);
    if (hasActiveInstall || isSwitching) {
      await AppToast.show(
        'Model is already installing/loading. Please wait.',
        type: AppToastType.info,
      );
      return;
    }

    if (model.provider == ModelProviderType.local) {
      final installedModels = await ref.read(modelInstallerProvider.future);
      if (!isModelReady(model, installedModels)) {
        await AppToast.show(
          'Model is not installed yet. Install it from Manage.',
          type: AppToastType.info,
        );
        return;
      }
    }

    ref.read(chatModelSwitchingProvider.notifier).start();
    try {
      await ref.read(chatThreadActionsProvider).stopGeneration();
      await _setModelAsActive(model.id);
    } catch (e) {
      await AppToast.show(
        'Failed to switch model: $e',
        type: AppToastType.error,
      );
      rethrow;
    } finally {
      ref.read(chatModelSwitchingProvider.notifier).stop();
    }
  }

  Future<void> _setModelAsActive(int modelId) async {
    await ref.read(selectedModelIdProvider.notifier).selectModel(modelId);
    ref.invalidate(activeModelInfoProvider);
    ref.invalidate(activeGemmaModelRuntimeProvider);
    ref.invalidate(activeGemmaChatProvider);
  }

  void _requestStopGenerationInBackground() {
    unawaited(
      ref
          .read(chatThreadActionsProvider)
          .stopGeneration(
            triggerLocalModelCancel: false,
            waitForLocalModelCancel: false,
          )
          .catchError((error) {
            logger.w('Background stopGeneration failed: $error');
          }),
    );
  }
}
