import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/downloads/data/default_static_models.dart';
import 'package:gena/features/downloads/data/local_model_files.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/model_readiness.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/data/services/model_background_download_service.dart';
import 'package:gena/features/downloads/presentation/cubit/download_reconciliation.dart';
import 'package:gena/features/downloads/presentation/cubit/downloads_state.dart';
import 'package:path_provider/path_provider.dart';

class DownloadsCubit extends Cubit<DownloadsState> {
  DownloadsCubit({
    required ModelRepository modelRepository,
    required ModelInstallerService modelInstallerService,
    required ModelRepositoryActions modelRepositoryActions,
    required DefaultModelSeeder defaultModelSeeder,
    AppCapabilities? capabilities,
  }) : _modelRepository = modelRepository,
       _modelInstallerService = modelInstallerService,
       _modelRepositoryActions = modelRepositoryActions,
       _defaultModelSeeder = defaultModelSeeder,
       _capabilities = capabilities ?? AppCapabilities.current,
       super(const DownloadsState()) {
    _init();
  }

  final ModelRepository _modelRepository;
  final ModelInstallerService _modelInstallerService;
  final ModelRepositoryActions _modelRepositoryActions;
  final DefaultModelSeeder _defaultModelSeeder;
  final AppCapabilities _capabilities;
  StreamSubscription<List<ModelInfo>>? _modelsSubscription;
  StreamSubscription<List<ModelDownloadSnapshot>>? _downloadTasksSubscription;
  List<ModelDownloadSnapshot> _backgroundDownloadTasks = const [];
  bool _installInProgress = false;

  Future<void> _init() async {
    await _defaultModelSeeder.ensureSeeded();
    _modelsSubscription = _modelRepository.watchModels().listen(
      (models) {
        emit(state.copyWith(models: models, loading: false, clearError: true));
        _syncBackgroundDownloadTasks(_backgroundDownloadTasks);
      },
      onError: (Object error, StackTrace stackTrace) {
        logger.e(error, error: error, stackTrace: stackTrace);
        emit(
          state.copyWith(
            loading: false,
            errorMessage: 'Failed to load models: $error',
          ),
        );
      },
    );
    if (_capabilities.supportsLocalModels) {
      _downloadTasksSubscription = ModelBackgroundDownloadService.instance
          .watchTasks()
          .listen((tasks) {
            _backgroundDownloadTasks = tasks;
            _syncBackgroundDownloadTasks(tasks);
          });
      await refreshInstalledModels();
    } else {
      emit(state.copyWith(installedModels: const [], clearError: true));
    }
  }

  void _syncBackgroundDownloadTasks(List<ModelDownloadSnapshot> tasks) {
    final nextState = reconcileBackgroundDownloads(state, tasks);
    _installInProgress = nextState.activeInstall != null;
    if (!identical(nextState, state)) emit(nextState);
  }

  Future<void> refreshInstalledModels() async {
    if (!_capabilities.supportsLocalModels) return;
    try {
      final installed = await _modelInstallerService.listInstalledModels();
      emit(state.copyWith(installedModels: installed, clearError: true));
    } catch (error, stackTrace) {
      logger.e(error, error: error, stackTrace: stackTrace);
      emit(state.copyWith(errorMessage: 'Failed to read installed models.'));
    }
  }

  String installKeyForModel(ModelInfo model) => 'model_${model.id}';

  String installedIdForModel(ModelInfo model) {
    if (model.sourceType == 'file') {
      return installedModelIdFromSource(model.source);
    }
    return model.modelId ?? model.source;
  }

  Future<void> installModel(ModelInfo model) async {
    if (model.provider == ModelProviderType.remote) return;
    if (!_capabilities.supportsLocalModels) {
      final message = _capabilities.localModelsUnavailableMessage;
      emit(state.copyWith(errorMessage: message));
      await AppToast.show(message, type: AppToastType.info);
      return;
    }
    if (_installInProgress || state.activeInstall != null) {
      await AppToast.show(
        'A model install is already running. Please wait.',
        type: AppToastType.info,
      );
      return;
    }

    final installKey = installKeyForModel(model);
    var effectiveSource = model.source;
    var effectiveSourceType = model.sourceType;

    _installInProgress = true;
    emit(
      state.copyWith(
        progressByKey: {...state.progressByKey, installKey: 0.0},
        activeInstall: ActiveModelInstall(
          key: installKey,
          label: model.name,
          ownership: ActiveModelInstallOwnership.live,
        ),
        clearError: true,
      ),
    );

    try {
      _throwIfUnsupportedLocalSource(effectiveSource);

      if (effectiveSourceType == 'file') {
        effectiveSource = canonicalLocalModelPath(effectiveSource);
        final file = File(effectiveSource);
        final exists = await file.exists();
        if (!exists) {
          final defaultUrl = defaultStaticModelSourceUrl(model);
          if (defaultUrl == null) {
            throw StateError(
              'Model file is missing. Please update the model source.',
            );
          }
          effectiveSourceType = 'network';
          effectiveSource = defaultUrl;
          _throwIfUnsupportedLocalSource(effectiveSource);
          await _updateModelSource(
            model,
            sourceType: effectiveSourceType,
            source: effectiveSource,
          );
          await AppToast.show(
            'Model file is missing. Re-downloading from default source.',
            type: AppToastType.info,
          );
        }
      }

      if (effectiveSourceType == 'network') {
        final downloaded = await ModelBackgroundDownloadService.instance
            .downloadModelToFile(
              modelKey: installKey,
              modelName: model.name,
              sourceUrl: effectiveSource,
              onProgress: (progress, _) {
                emit(
                  state.copyWith(
                    progressByKey: {
                      ...state.progressByKey,
                      installKey: progress.clamp(0, 1),
                    },
                  ),
                );
              },
            );
        effectiveSource = downloaded.path;
        effectiveSourceType = 'file';
        _throwIfUnsupportedLocalSource(effectiveSource);
        await _updateModelSource(
          model,
          sourceType: effectiveSourceType,
          source: effectiveSource,
        );
      }

      if (effectiveSourceType != 'file' ||
          !await File(effectiveSource).exists()) {
        throw StateError('Compatible model file is missing.');
      }

      final installedId = localModelIdForPath(effectiveSource);
      await _modelRepositoryActions.updateModelId(
        id: model.id,
        modelId: installedId,
      );
      emit(
        state.copyWith(
          progressByKey: {
            ...state.progressByKey,
            installKey: 1.0,
            installedId: 1.0,
          },
          clearActiveInstall: true,
        ),
      );
      await refreshInstalledModels();
    } catch (error, stackTrace) {
      logger.e(error, error: error, stackTrace: stackTrace);
      final message = error.toString().toLowerCase();
      if (!message.contains('cancelled')) {
        await AppToast.show('Install failed: $error', type: AppToastType.error);
      }
      final nextState = {...state.progressByKey}..remove(installKey);
      emit(
        state.copyWith(
          progressByKey: nextState,
          clearActiveInstall: true,
          errorMessage: 'Install failed: $error',
        ),
      );
    } finally {
      _installInProgress = false;
    }
  }

  Future<void> removeModel(ModelInfo model) async {
    if (isDefaultStaticModel(model)) {
      await AppToast.show(
        'This default model is static and cannot be deleted.',
        type: AppToastType.info,
      );
      return;
    }

    if (model.provider == ModelProviderType.remote) {
      await _modelRepositoryActions.deleteModel(model.id);
      return;
    }

    final installKey = installKeyForModel(model);
    final installedId = installedIdForModel(model);
    try {
      await _deleteAppOwnedSourceIfExists(model);
      await _modelRepositoryActions.deleteModel(model.id);
      final nextState = {...state.progressByKey}
        ..remove(installKey)
        ..remove(installedId);
      emit(state.copyWith(progressByKey: nextState, clearError: true));
      await refreshInstalledModels();
    } catch (error, stackTrace) {
      logger.e(error, error: error, stackTrace: stackTrace);
      await AppToast.show('Remove failed: $error', type: AppToastType.error);
      emit(state.copyWith(errorMessage: 'Remove failed: $error'));
    }
  }

  Future<void> cancelDownload(ModelInfo model) async {
    final installKey = installKeyForModel(model);

    try {
      final cancelled = await ModelBackgroundDownloadService.instance
          .cancelDownload(installKey);
      if (!cancelled) {
        await AppToast.show(
          'This install is already finalizing and can no longer be cancelled.',
          type: AppToastType.info,
        );
        return;
      }

      _installInProgress = false;
      final nextState = {...state.progressByKey}..remove(installKey);
      emit(state.copyWith(progressByKey: nextState, clearActiveInstall: true));
      await AppToast.show('Download cancelled', type: AppToastType.info);
    } catch (error, stackTrace) {
      logger.e(error, error: error, stackTrace: stackTrace);
      await AppToast.show('Cancel failed: $error', type: AppToastType.error);
      emit(state.copyWith(errorMessage: 'Cancel failed: $error'));
    }
  }

  Future<void> deleteDownloadedFileForStaticModel(ModelInfo model) async {
    if (!isDefaultStaticModel(model)) return;
    final defaultUrl = defaultStaticModelSourceUrl(model);
    if (defaultUrl == null) {
      await AppToast.show(
        'Default source URL not found for this model.',
        type: AppToastType.error,
      );
      return;
    }
    if (model.sourceType != 'file') {
      await AppToast.show(
        'No downloaded file to delete for this model.',
        type: AppToastType.info,
      );
      return;
    }

    final file = File(canonicalLocalModelPath(model.source));
    if (!await _isAppOwnedModelPath(model.source)) {
      await AppToast.show(
        'This file is outside app-managed model storage and was not deleted.',
        type: AppToastType.info,
      );
      return;
    }
    if (await file.exists()) {
      await file.delete();
    }

    await _updateModelSource(model, sourceType: 'network', source: defaultUrl);
    await _modelRepositoryActions.updateModelId(id: model.id, modelId: null);

    final nextState = {...state.progressByKey}
      ..remove(installKeyForModel(model))
      ..remove(installedIdForModel(model));
    if (model.modelId != null) nextState.remove(model.modelId!);
    emit(state.copyWith(progressByKey: nextState, clearError: true));
    await refreshInstalledModels();
    await AppToast.show(
      'Downloaded file deleted. Model entry kept.',
      type: AppToastType.success,
    );
  }

  Future<void> resetSeedModels() async {
    await _modelRepositoryActions.clearAndReseedDefaultModels();
    await refreshInstalledModels();
  }

  Future<void> _updateModelSource(
    ModelInfo model, {
    required String sourceType,
    required String source,
  }) {
    return _modelRepositoryActions.updateModel(
      id: model.id,
      name: model.name,
      description: model.description,
      provider: model.provider,
      apiUrl: model.apiUrl,
      apiToken: model.apiToken,
      modelType: model.modelType,
      supportImage: model.supportImage,
      supportAudio: model.supportAudio,
      supportsFunctionCalls: model.supportsFunctionCalls,
      isThinking: model.isThinking,
      temperature: model.temperature,
      topK: model.topK,
      topP: model.topP,
      maxTokens: model.maxTokens,
      tokenBuffer: model.tokenBuffer,
      randomSeed: model.randomSeed,
      preferredBackend: model.preferredBackend,
      sourceType: sourceType,
      source: source,
    );
  }

  void _throwIfUnsupportedLocalSource(String source) {
    final validationError = localModelSourceValidationError(source);
    if (validationError != null) throw StateError(validationError);
  }

  Future<void> _deleteAppOwnedSourceIfExists(ModelInfo model) async {
    if (model.sourceType != 'file') return;
    final file = File(canonicalLocalModelPath(model.source));
    if (!await file.exists()) return;
    if (!await _isAppOwnedModelPath(model.source)) return;
    await file.delete();
  }

  Future<bool> _isAppOwnedModelPath(String path) async {
    final appSupportDirectory = await getApplicationSupportDirectory();
    final modelsDirectory = Directory('${appSupportDirectory.path}/models');
    final file = File(canonicalLocalModelPath(path));
    if (!await modelsDirectory.exists() || !await file.exists()) return false;
    final resolvedModelsDirectory = await modelsDirectory
        .resolveSymbolicLinks();
    final resolvedPath = await file.resolveSymbolicLinks();
    return isPathWithinDirectory(
      path: resolvedPath,
      directory: resolvedModelsDirectory,
    );
  }

  @override
  Future<void> close() async {
    await _modelsSubscription?.cancel();
    await _downloadTasksSubscription?.cancel();
    return super.close();
  }
}
