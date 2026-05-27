import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/downloads/data/default_static_models.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/data/services/model_background_download_service.dart';
import 'package:gena/features/downloads/presentation/cubit/downloads_state.dart';

class DownloadsCubit extends Cubit<DownloadsState> {
  DownloadsCubit({
    required ModelRepository modelRepository,
    required ModelInstallerService modelInstallerService,
    required ModelRepositoryActions modelRepositoryActions,
    required DefaultModelSeeder defaultModelSeeder,
  }) : _modelRepository = modelRepository,
       _modelInstallerService = modelInstallerService,
       _modelRepositoryActions = modelRepositoryActions,
       _defaultModelSeeder = defaultModelSeeder,
       super(const DownloadsState()) {
    _init();
  }

  final ModelRepository _modelRepository;
  final ModelInstallerService _modelInstallerService;
  final ModelRepositoryActions _modelRepositoryActions;
  final DefaultModelSeeder _defaultModelSeeder;
  StreamSubscription<List<ModelInfo>>? _modelsSubscription;
  bool _installInProgress = false;

  Future<void> _init() async {
    await _defaultModelSeeder.ensureSeeded();
    _modelsSubscription = _modelRepository.watchModels().listen(
      (models) {
        emit(state.copyWith(models: models, loading: false, clearError: true));
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
    await refreshInstalledModels();
  }

  Future<void> refreshInstalledModels() async {
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
    final parts = model.source.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? model.source : parts.last;
  }

  Future<void> installModel(ModelInfo model) async {
    if (model.provider == ModelProviderType.remote) return;
    if (_installInProgress || state.activeInstall != null) {
      await AppToast.show(
        'A model install is already running. Please wait.',
        type: AppToastType.info,
      );
      return;
    }

    final installKey = installKeyForModel(model);
    var installedId = installedIdForModel(model);
    var effectiveSource = model.source;
    var effectiveSourceType = model.sourceType;

    _installInProgress = true;
    emit(
      state.copyWith(
        progressByKey: {...state.progressByKey, installKey: 0.0},
        activeInstall: ActiveModelInstall(key: installKey, label: model.name),
        clearError: true,
      ),
    );

    try {
      if (effectiveSourceType == 'file') {
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
        installedId = _installedIdFromSource(effectiveSource);
        await _updateModelSource(
          model,
          sourceType: effectiveSourceType,
          source: effectiveSource,
        );
      }

      final installer = FlutterGemma.installModel(
        modelType: _parseModelType(model.modelType),
        fileType: _inferFileType(effectiveSource),
      );
      final installation = await installer
          .fromFile(effectiveSource)
          .withProgress((progress) {
            emit(
              state.copyWith(
                progressByKey: {
                  ...state.progressByKey,
                  installKey: progress / 100,
                },
              ),
            );
          })
          .install();

      await _modelRepositoryActions.updateModelId(
        id: model.id,
        modelId: installation.spec.name,
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
      await FlutterGemma.uninstallModel(installedId);
      await _deleteCopiedSourceIfExists(model);
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
    _installInProgress = false;
    final nextState = {...state.progressByKey}..remove(installKey);
    emit(state.copyWith(progressByKey: nextState, clearActiveInstall: true));

    try {
      await ModelBackgroundDownloadService.instance.cancelDownload(installKey);
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

    final file = File(model.source);
    if (await file.exists()) {
      await file.delete();
    }

    await _tryUninstall(model);
    await _updateModelSource(model, sourceType: 'network', source: defaultUrl);

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

  Future<void> _tryUninstall(ModelInfo model) async {
    try {
      if (model.modelId != null && model.modelId!.isNotEmpty) {
        await FlutterGemma.uninstallModel(model.modelId!);
        return;
      }
      await FlutterGemma.uninstallModel(installedIdForModel(model));
    } catch (_) {
      // Best effort.
    }
  }

  Future<void> _deleteCopiedSourceIfExists(ModelInfo model) async {
    if (model.sourceType != 'file') return;
    final file = File(model.source);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _installedIdFromSource(String source) {
    final parts = source.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? source : parts.last;
  }

  ModelFileType _inferFileType(String source) {
    final lower = source.toLowerCase();
    if (lower.endsWith('.litertlm')) return ModelFileType.litertlm;
    if (lower.endsWith('.task')) return ModelFileType.task;
    return ModelFileType.binary;
  }

  ModelType _parseModelType(String value) {
    return switch (value) {
      'general' => ModelType.general,
      'gemmaIt' => ModelType.gemmaIt,
      'gemma4' => ModelType.gemma4,
      'deepSeek' => ModelType.deepSeek,
      'qwen' => ModelType.qwen,
      'qwen3' => ModelType.qwen3,
      'llama' => ModelType.llama,
      'hammer' => ModelType.hammer,
      'functionGemma' => ModelType.functionGemma,
      'phi' => ModelType.phi,
      _ => ModelType.gemmaIt,
    };
  }

  @override
  Future<void> close() async {
    await _modelsSubscription?.cancel();
    return super.close();
  }
}
