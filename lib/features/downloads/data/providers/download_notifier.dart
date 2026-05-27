import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/downloads/data/default_static_models.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/data/services/model_background_download_service.dart';

class ActiveModelInstall {
  final String key;
  final String label;

  const ActiveModelInstall({required this.key, required this.label});
}

final activeModelInstallProvider =
    NotifierProvider<ActiveModelInstallNotifier, ActiveModelInstall?>(
      ActiveModelInstallNotifier.new,
    );

class ActiveModelInstallNotifier extends Notifier<ActiveModelInstall?> {
  @override
  ActiveModelInstall? build() => null;

  void start(String key, String label) {
    state = ActiveModelInstall(key: key, label: label);
  }

  void clear() {
    state = null;
  }
}

final downloadProvider =
    NotifierProvider<DownloadNotifier, Map<String, double>>(
      DownloadNotifier.new,
    );

class DownloadNotifier extends Notifier<Map<String, double>> {
  bool _installInProgress = false;

  @override
  Map<String, double> build() {
    return {};
  }

  Future<void> installModel(ModelInfo model) async {
    if (model.provider == ModelProviderType.remote) {
      return;
    }
    final currentInstall = ref.read(activeModelInstallProvider);
    if (_installInProgress || currentInstall != null) {
      await AppToast.show(
        'A model install is already running. Please wait.',
        type: AppToastType.info,
      );
      return;
    }

    final installKey = _installKey(model);
    var installedId = _installedModelId(model);
    var effectiveSource = model.source;
    var effectiveSourceType = model.sourceType;

    _installInProgress = true;
    state = {...state, installKey: 0.0};
    ref.read(activeModelInstallProvider.notifier).start(installKey, model.name);
    try {
      if (effectiveSourceType == 'file') {
        final file = File(effectiveSource);
        final exists = await file.exists();
        if (!exists) {
          final defaultUrl = defaultStaticModelSourceUrl(model);
          if (defaultUrl != null) {
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
          } else {
            throw StateError(
              'Model file is missing. Please update the model source.',
            );
          }
        }
      }

      if (effectiveSourceType == 'network') {
        final downloaded = await ModelBackgroundDownloadService.instance
            .downloadModelToFile(
              modelKey: installKey,
              modelName: model.name,
              sourceUrl: effectiveSource,
              onProgress: (progress, _) {
                state = {...state, installKey: progress.clamp(0, 1)};
              },
            );
        effectiveSource = downloaded.path;
        effectiveSourceType = 'file';
        installedId = _installedModelIdFromSource(effectiveSource);
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

      final builder = installer.fromFile(effectiveSource);

      final installation = await builder.withProgress((progress) {
        state = {...state, installKey: progress / 100};
      }).install();
      await ref
          .read(modelRepositoryActionsProvider)
          .updateModelId(id: model.id, modelId: installation.spec.name);

      state = {...state, installKey: 1.0};
      ref.invalidate(modelInstallerProvider);
    } catch (e) {
      logger.e(e, error: e);
      final message = e.toString().toLowerCase();
      final isCancelled = message.contains('cancelled');
      if (!isCancelled) {
        await AppToast.show('Install failed: $e', type: AppToastType.error);
      }
      final nextState = {...state};
      nextState.remove(installKey);
      state = nextState;
    } finally {
      _installInProgress = false;
      ref.read(activeModelInstallProvider.notifier).clear();
      if (state[installKey] == 1.0) {
        state = {...state, installedId: 1.0};
      }
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
      await ref.read(modelRepositoryActionsProvider).deleteModel(model.id);
      return;
    }
    final installKey = _installKey(model);
    final installedId = _installedModelId(model);

    try {
      await FlutterGemma.uninstallModel(installedId);
      await _deleteCopiedSourceIfExists(model);
      await ref.read(modelRepositoryActionsProvider).deleteModel(model.id);
      final nextState = {...state};
      nextState.remove(installKey);
      nextState.remove(installedId);
      state = nextState;
      ref.invalidate(modelInstallerProvider);
    } catch (e) {
      logger.e(e, error: e);
      await AppToast.show('Remove failed: $e', type: AppToastType.error);
    }
  }

  Future<void> cancelDownload(ModelInfo model) async {
    final installKey = _installKey(model);
    _installInProgress = false;
    ref.read(activeModelInstallProvider.notifier).clear();
    final nextState = {...state};
    nextState.remove(installKey);
    state = nextState;

    try {
      await ModelBackgroundDownloadService.instance.cancelDownload(installKey);
      await AppToast.show('Download cancelled', type: AppToastType.info);
    } catch (e) {
      logger.e(e, error: e);
      await AppToast.show('Cancel failed: $e', type: AppToastType.error);
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

    final nextState = {...state};
    nextState.remove(_installKey(model));
    nextState.remove(_installedModelId(model));
    if (model.modelId != null) {
      nextState.remove(model.modelId!);
    }
    state = nextState;
    ref.invalidate(modelInstallerProvider);

    await AppToast.show(
      'Downloaded file deleted. Model entry kept.',
      type: AppToastType.success,
    );
  }

  String installKeyForModel(ModelInfo model) => _installKey(model);

  String installedIdForModel(ModelInfo model) => _installedModelId(model);

  String _installKey(ModelInfo model) => 'model_${model.id}';

  String _installedModelId(ModelInfo model) {
    return _installedModelIdFromSource(model.source);
  }

  String _installedModelIdFromSource(String source) {
    final parts = source.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? source : parts.last;
  }

  Future<void> _updateModelSource(
    ModelInfo model, {
    required String sourceType,
    required String source,
  }) async {
    await ref
        .read(modelRepositoryActionsProvider)
        .updateModel(
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
      await FlutterGemma.uninstallModel(_installedModelId(model));
    } catch (_) {
      // Best effort only: source file can still be reset even if uninstall fails.
    }
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

  Future<void> _deleteCopiedSourceIfExists(ModelInfo model) async {
    if (model.sourceType != 'file') return;

    final file = File(model.source);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
