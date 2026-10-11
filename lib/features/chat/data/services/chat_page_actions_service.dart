import 'dart:async';

import 'package:gena/core/logger.dart';
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/presentation/cubit/chat_ui_cubits.dart';
import 'package:gena/features/chat/presentation/cubit/selected_chat_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/selected_model_cubit.dart';
import 'package:gena/features/chat/data/services/chat_thread_actions_service.dart';
import 'package:gena/features/chat/data/services/local_model_runtime.dart';
import 'package:gena/features/chat/data/services/active_model_info_service.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/model_readiness.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/data/ready_model_selection.dart';
import 'package:gena/features/downloads/data/services/download_notifier_service.dart';
import 'package:gena/features/workspace/presentation/cubit/selected_workspace_cubit.dart';

class ChatPageActions {
  ChatPageActions({
    required SelectedChatCubit selectedChatCubit,
    required SelectedWorkspaceCubit selectedWorkspaceCubit,
    required ChatThreadActions chatThreadActions,
    required DownloadsCubit downloadsCubit,
    required ChatModelSwitchingCubit chatModelSwitchingCubit,
    required SelectedModelCubit selectedModelCubit,
    required ActiveModelInfoResolver activeModelInfoResolver,
    required ModelRepository modelRepository,
    required ModelInstallerService modelInstallerService,
    required LocalModelRuntime localModelRuntime,
    AppCapabilities? capabilities,
  }) : _selectedChatCubit = selectedChatCubit,
       _selectedWorkspaceCubit = selectedWorkspaceCubit,
       _chatThreadActions = chatThreadActions,
       _downloadsCubit = downloadsCubit,
       _chatModelSwitchingCubit = chatModelSwitchingCubit,
       _selectedModelCubit = selectedModelCubit,
       _activeModelInfoResolver = activeModelInfoResolver,
       _modelRepository = modelRepository,
       _modelInstallerService = modelInstallerService,
       _localModelRuntime = localModelRuntime,
       _capabilities = capabilities ?? AppCapabilities.current;

  final SelectedChatCubit _selectedChatCubit;
  final SelectedWorkspaceCubit _selectedWorkspaceCubit;
  final ChatThreadActions _chatThreadActions;
  final DownloadsCubit _downloadsCubit;
  final ChatModelSwitchingCubit _chatModelSwitchingCubit;
  final SelectedModelCubit _selectedModelCubit;
  final ActiveModelInfoResolver _activeModelInfoResolver;
  final ModelRepository _modelRepository;
  final ModelInstallerService _modelInstallerService;
  final LocalModelRuntime _localModelRuntime;
  final AppCapabilities _capabilities;

  Future<void> createNewThread() async {
    _requestStopGenerationInBackground();
    await _selectedChatCubit.createNewThread();
    final preparedSelection = await _ensureModelSelectedIfNeeded();
    if (!preparedSelection) _warmupLocalSessionInBackground();
  }

  Future<void> createNewThreadInWorkspace(String workspaceId) async {
    _requestStopGenerationInBackground();
    _selectedWorkspaceCubit.selectWorkspace(workspaceId);
    await _selectedChatCubit.createNewThread(workspaceId: workspaceId);
    final preparedSelection = await _ensureModelSelectedIfNeeded();
    if (!preparedSelection) _warmupLocalSessionInBackground();
  }

  Future<void> selectChat(String chatId) async {
    _requestStopGenerationInBackground();
    _selectedChatCubit.selectChat(chatId);
    final preparedSelection = await _ensureModelSelectedIfNeeded();
    if (!preparedSelection) _warmupLocalSessionInBackground();
  }

  Future<void> selectWorkspace(String workspaceId) async {
    _requestStopGenerationInBackground();
    _selectedWorkspaceCubit.selectWorkspace(workspaceId);
    await _selectedChatCubit.ensureSelectionForWorkspace(workspaceId);
    final preparedSelection = await _ensureModelSelectedIfNeeded();
    if (!preparedSelection) _warmupLocalSessionInBackground();
  }

  Future<void> installModel(ModelInfo model) async {
    if (await _rejectUnsupportedLocalModel(model)) return;

    final hasActiveInstall = _downloadsCubit.state.activeInstall != null;
    final isSwitching = _chatModelSwitchingCubit.state.isBusy;
    if (hasActiveInstall || isSwitching) {
      await AppToast.show(
        'Model is already installing/loading. Please wait.',
        type: AppToastType.info,
      );
      return;
    }

    try {
      if (model.provider == ModelProviderType.local) {
        await _downloadsCubit.installModel(model);
      }
      final installedModel = await _modelById(model.id) ?? model;
      await _switchToModel(
        installedModel,
        origin: ChatModelSwitchOrigin.installation,
      );
    } catch (error) {
      await AppToast.show(
        'Failed to install model: $error',
        type: AppToastType.error,
      );
      rethrow;
    }
  }

  Future<void> selectModel(
    ModelInfo model, {
    bool remoteConfirmed = false,
  }) async {
    if (await _rejectUnsupportedLocalModel(model)) return;
    if (model.provider == ModelProviderType.remote && !remoteConfirmed) {
      throw RemoteModelConfirmationRequired(model);
    }

    final switchState = _chatModelSwitchingCubit.state;
    if (switchState.isBusy &&
        switchState.origin != ChatModelSwitchOrigin.backgroundWarmup) {
      await AppToast.show(
        'Model is currently loading. Please wait.',
        type: AppToastType.info,
      );
      return;
    }

    if (model.provider == ModelProviderType.local) {
      final installedModels = await _modelInstallerService
          .listInstalledModels();
      final isReady = isModelReady(model, installedModels);
      if (!isReady) {
        await AppToast.show(
          'Model is not installed yet. Install it from Manage.',
          type: AppToastType.info,
        );
        return;
      }
    }

    try {
      await _switchToModel(model, origin: ChatModelSwitchOrigin.selection);
    } catch (error) {
      await AppToast.show(
        'Failed to switch model: $error',
        type: AppToastType.error,
      );
      rethrow;
    }
  }

  Future<void> retryLastModelSwitch() async {
    final failedState = _chatModelSwitchingCubit.state;
    if (failedState.phase != ChatModelSwitchPhase.failed ||
        failedState.modelId == null) {
      return;
    }
    final target = await _modelById(failedState.modelId!);
    if (target == null) {
      await AppToast.show(
        'The model is no longer available.',
        type: AppToastType.info,
      );
      return;
    }
    if (target.provider == ModelProviderType.remote) {
      await AppToast.show(
        'Select the remote model again to review and confirm data sharing.',
        type: AppToastType.info,
      );
      return;
    }
    await selectModel(target);
  }

  Future<void> useConfirmedRemoteFallback(
    RemoteFallbackProposal proposal,
  ) async {
    final target = await _modelById(proposal.modelId);
    if (target == null || target.provider != ModelProviderType.remote) {
      await AppToast.show(
        'The remote model is no longer available.',
        type: AppToastType.info,
      );
      return;
    }

    await selectModel(target, remoteConfirmed: true);
    await _chatThreadActions.retryLastFailedGeneration();
  }

  Future<bool> _ensureModelSelectedIfNeeded() async {
    final models = await _modelRepository.watchModels().first;
    if (models.isEmpty) return false;

    final installedModels = await loadInstalledModelsIfSupported(
      capabilities: _capabilities,
      loadInstalledModels: _modelInstallerService.listInstalledModels,
    );
    final readyModels = readyModelsForCapabilities(
      models: models,
      installedModels: installedModels,
      capabilities: _capabilities,
    );
    if (readyModels.isEmpty) return false;

    final selectedId = _selectedModelCubit.state;
    if (selectedId != null) {
      for (final model in readyModels) {
        if (model.id == selectedId) {
          return false;
        }
      }
    }

    final automaticModel = automaticReadyModelForPlatform(
      readyModels: readyModels,
      supportsLocalModels: _capabilities.supportsLocalModels,
    );
    if (automaticModel == null) return false;

    await _switchToModel(
      automaticModel,
      origin: ChatModelSwitchOrigin.automaticSelection,
    );
    return true;
  }

  Future<void> _switchToModel(
    ModelInfo target, {
    required ChatModelSwitchOrigin origin,
  }) async {
    final previous = await _activeModelInfoResolver.getActiveModelInfo();
    final operationId = _chatModelSwitchingCubit.begin(
      modelId: target.id,
      modelName: target.name,
      origin: origin,
    );

    try {
      await _chatThreadActions.stopGeneration();
      _chatModelSwitchingCubit.advance(
        operationId,
        ChatModelSwitchPhase.unloading,
      );

      if (previous?.provider == ModelProviderType.local) {
        await _localModelRuntime.reset();
      }

      if (target.provider == ModelProviderType.local) {
        _chatModelSwitchingCubit.advance(
          operationId,
          ChatModelSwitchPhase.loading,
        );
        await _localModelRuntime.prepare(target);
      }

      await _selectedModelCubit.selectModel(target.id);
      if (target.provider == ModelProviderType.local) {
        await _chatThreadActions.primeCurrentContext(activeModel: target);
      }
      _chatModelSwitchingCubit.complete(operationId);
    } catch (error, stackTrace) {
      logger.e(
        'Failed to switch model to ${target.name}',
        error: error,
        stackTrace: stackTrace,
      );
      await _restorePreviousModel(previous, targetId: target.id);
      _chatModelSwitchingCubit.fail(
        operationId,
        'Could not load ${target.name}. Try again or choose another model.',
      );
      rethrow;
    }
  }

  Future<void> _restorePreviousModel(
    ModelInfo? previous, {
    required int targetId,
  }) async {
    if (previous == null) return;
    try {
      if (_selectedModelCubit.state == targetId) {
        await _selectedModelCubit.selectModel(previous.id);
      }
      if (previous.provider == ModelProviderType.local) {
        await _localModelRuntime.prepare(previous);
      }
    } catch (error, stackTrace) {
      logger.e(
        'Failed to restore previous model ${previous.name}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<ModelInfo?> _modelById(int modelId) async {
    final models = await _modelRepository.watchModels().first;
    for (final model in models) {
      if (model.id == modelId) return model;
    }
    return null;
  }

  void _warmupLocalSessionInBackground() {
    unawaited(_warmupLocalSessionWithLoadingIndicator());
  }

  Future<void> _warmupLocalSessionWithLoadingIndicator() async {
    if (!_capabilities.supportsLocalModels) return;
    if (_downloadsCubit.state.activeInstall != null) return;
    final model = await _activeModelInfoResolver.getActiveModelInfo();
    if (model == null || model.provider != ModelProviderType.local) return;

    final currentState = _chatModelSwitchingCubit.state;
    if (currentState.isBusy &&
        currentState.origin != ChatModelSwitchOrigin.backgroundWarmup) {
      return;
    }
    final operationId = _chatModelSwitchingCubit.begin(
      modelId: model.id,
      modelName: model.name,
      origin: ChatModelSwitchOrigin.backgroundWarmup,
      initialPhase: ChatModelSwitchPhase.loading,
    );
    try {
      await _warmupLocalSession();
      _chatModelSwitchingCubit.complete(operationId);
    } catch (error, stackTrace) {
      logger.w(
        'Local model warm-up skipped/failed: $error',
        stackTrace: stackTrace,
      );
      _chatModelSwitchingCubit.fail(
        operationId,
        'Could not load ${model.name}. Try again or choose another model.',
      );
    }
  }

  Future<void> _warmupLocalSession() async {
    if (!_capabilities.supportsLocalModels) return;
    if (_downloadsCubit.state.activeInstall != null) return;
    final model = await _activeModelInfoResolver.getActiveModelInfo();
    if (model == null || model.provider != ModelProviderType.local) return;
    await _localModelRuntime.prepare(model);
    await _chatThreadActions.primeCurrentContext(activeModel: model);
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

  Future<bool> _rejectUnsupportedLocalModel(ModelInfo model) async {
    if (model.provider != ModelProviderType.local ||
        _capabilities.supportsLocalModels) {
      return false;
    }
    await AppToast.show(
      _capabilities.localModelsUnavailableMessage,
      type: AppToastType.info,
    );
    return true;
  }
}

class RemoteModelConfirmationRequired implements Exception {
  const RemoteModelConfirmationRequired(this.model);

  final ModelInfo model;

  @override
  String toString() =>
      'Remote model ${model.name} requires explicit confirmation.';
}
