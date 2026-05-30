import 'dart:async';

import 'package:gena/core/logger.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/cubits/chat_ui_cubits.dart';
import 'package:gena/features/chat/data/cubits/selected_chat_cubit.dart';
import 'package:gena/features/chat/data/cubits/selected_model_cubit.dart';
import 'package:gena/features/chat/data/providers/chat_session_provider.dart';
import 'package:gena/features/chat/data/providers/chat_thread_actions_provider.dart';
import 'package:gena/features/chat/data/providers/active_model_info_provider.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/data/providers/download_notifier.dart';
import 'package:gena/features/workspace/data/cubits/selected_workspace_cubit.dart';

class ChatPageActions {
  ChatPageActions({
    required SelectedChatCubit selectedChatCubit,
    required SelectedWorkspaceCubit selectedWorkspaceCubit,
    required ChatThreadActions chatThreadActions,
    required DownloadsCubit downloadsCubit,
    required ChatModelSwitchingCubit chatModelSwitchingCubit,
    required SelectedModelCubit selectedModelCubit,
    required ActiveModelInfoResolver activeModelInfoResolver,
    required ModelInstallerService modelInstallerService,
    required ChatSessionController chatSessionController,
  }) : _selectedChatCubit = selectedChatCubit,
       _selectedWorkspaceCubit = selectedWorkspaceCubit,
       _chatThreadActions = chatThreadActions,
       _downloadsCubit = downloadsCubit,
       _chatModelSwitchingCubit = chatModelSwitchingCubit,
       _selectedModelCubit = selectedModelCubit,
       _activeModelInfoResolver = activeModelInfoResolver,
       _modelInstallerService = modelInstallerService,
       _chatSessionController = chatSessionController;

  final SelectedChatCubit _selectedChatCubit;
  final SelectedWorkspaceCubit _selectedWorkspaceCubit;
  final ChatThreadActions _chatThreadActions;
  final DownloadsCubit _downloadsCubit;
  final ChatModelSwitchingCubit _chatModelSwitchingCubit;
  final SelectedModelCubit _selectedModelCubit;
  final ActiveModelInfoResolver _activeModelInfoResolver;
  final ModelInstallerService _modelInstallerService;
  final ChatSessionController _chatSessionController;

  Future<void> createNewThread() async {
    _requestStopGenerationInBackground();
    await _selectedChatCubit.createNewThread();
    _warmupLocalSessionInBackground();
  }

  Future<void> createNewThreadInWorkspace(String workspaceId) async {
    _requestStopGenerationInBackground();
    _selectedWorkspaceCubit.selectWorkspace(workspaceId);
    await _selectedChatCubit.createNewThread(workspaceId: workspaceId);
    _warmupLocalSessionInBackground();
  }

  Future<void> selectChat(String chatId) async {
    _requestStopGenerationInBackground();
    _selectedChatCubit.selectChat(chatId);
    _warmupLocalSessionInBackground();
  }

  Future<void> selectWorkspace(String workspaceId) async {
    _requestStopGenerationInBackground();
    _selectedWorkspaceCubit.selectWorkspace(workspaceId);
    await _selectedChatCubit.ensureSelectionForWorkspace(workspaceId);
    _warmupLocalSessionInBackground();
  }

  Future<void> installModel(ModelInfo model) async {
    final hasActiveInstall = _downloadsCubit.state.activeInstall != null;
    final isSwitching = _chatModelSwitchingCubit.state;
    if (hasActiveInstall || isSwitching) {
      await AppToast.show(
        'Model is already installing/loading. Please wait.',
        type: AppToastType.info,
      );
      return;
    }

    _chatModelSwitchingCubit.start();
    try {
      await _chatThreadActions.stopGeneration();
      if (model.provider == ModelProviderType.local) {
        await _downloadsCubit.installModel(model);
      }
      await _setModelAsActive(model.id);
    } catch (error) {
      await AppToast.show(
        'Failed to install model: $error',
        type: AppToastType.error,
      );
      rethrow;
    } finally {
      _chatModelSwitchingCubit.stop();
    }
  }

  Future<void> selectModel(ModelInfo model) async {
    final hasActiveInstall = _downloadsCubit.state.activeInstall != null;
    final isSwitching = _chatModelSwitchingCubit.state;
    if (hasActiveInstall || isSwitching) {
      await AppToast.show(
        'Model is already installing/loading. Please wait.',
        type: AppToastType.info,
      );
      return;
    }

    if (model.provider == ModelProviderType.local) {
      final installedModels = await _modelInstallerService
          .listInstalledModels();
      final isReady =
          installedModels.contains(model.modelId) ||
          installedModels.any(
            (entry) =>
                entry.toLowerCase() ==
                model.source.split(RegExp(r'[/\\]')).last.toLowerCase(),
          );
      if (!isReady) {
        await AppToast.show(
          'Model is not installed yet. Install it from Manage.',
          type: AppToastType.info,
        );
        return;
      }
    }

    _chatModelSwitchingCubit.start();
    try {
      await _chatThreadActions.stopGeneration();
      await _setModelAsActive(model.id);
    } catch (error) {
      await AppToast.show(
        'Failed to switch model: $error',
        type: AppToastType.error,
      );
      rethrow;
    } finally {
      _chatModelSwitchingCubit.stop();
    }
  }

  Future<void> _setModelAsActive(int modelId) async {
    await _selectedModelCubit.selectModel(modelId);
    await _activeModelInfoResolver.getActiveModelInfo();
    _chatSessionController.resetRuntime();
    _chatSessionController.resetActiveChatSession();
    _warmupLocalSessionInBackground();
  }

  void _warmupLocalSessionInBackground() {
    unawaited(_warmupLocalSessionWithLoadingIndicator());
  }

  Future<void> _warmupLocalSessionWithLoadingIndicator() async {
    if (_downloadsCubit.state.activeInstall != null) return;
    final model = await _activeModelInfoResolver.getActiveModelInfo();
    if (model == null || model.provider != ModelProviderType.local) return;

    _chatModelSwitchingCubit.start();
    try {
      await _warmupLocalSession();
    } catch (error, stackTrace) {
      logger.w(
        'Local model warm-up skipped/failed: $error',
        stackTrace: stackTrace,
      );
    } finally {
      _chatModelSwitchingCubit.stop();
    }
  }

  Future<void> _warmupLocalSession() async {
    if (_downloadsCubit.state.activeInstall != null) return;
    final model = await _activeModelInfoResolver.getActiveModelInfo();
    if (model == null || model.provider != ModelProviderType.local) return;
    await _chatSessionController.getRuntime();
    await _chatSessionController.getActiveChatSession();
  }

  void _requestStopGenerationInBackground() {
    unawaited(
      _chatThreadActions
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
