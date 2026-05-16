import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/domain/model_info.dart';

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
  @override
  Map<String, double> build() {
    return {};
  }

  Future<void> installModel(ModelInfo model) async {
    final installKey = _installKey(model);
    final installedId = _installedModelId(model);

    state = {...state, installKey: 0.0};
    ref.read(activeModelInstallProvider.notifier).start(installKey, model.name);
    try {
      final installer = FlutterGemma.installModel(
        modelType: _parseModelType(model.modelType),
        fileType: _inferFileType(model.source),
      );

      final builder = model.sourceType == 'file'
          ? installer.fromFile(model.source)
          : installer.fromNetwork(model.source);

      await builder.withProgress((progress) {
        state = {...state, installKey: progress / 100};
      }).install();

      state = {...state, installKey: 1.0};
      ref.invalidate(modelInstallerProvider);
    } catch (e) {
      logger.e(e, error: e);
      final nextState = {...state};
      nextState.remove(installKey);
      state = nextState;
      rethrow;
    } finally {
      ref.read(activeModelInstallProvider.notifier).clear();
      if (state[installKey] == 1.0) {
        state = {...state, installedId: 1.0};
      }
    }
  }

  Future<void> removeModel(ModelInfo model) async {
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
      rethrow;
    }
  }

  String installKeyForModel(ModelInfo model) => _installKey(model);

  String installedIdForModel(ModelInfo model) => _installedModelId(model);

  String _installKey(ModelInfo model) => 'model_${model.id}';

  String _installedModelId(ModelInfo model) {
    final parts = model.source.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? model.source : parts.last;
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
