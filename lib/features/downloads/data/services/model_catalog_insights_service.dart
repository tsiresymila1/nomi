import 'dart:io';

import 'package:gena/core/services/device_system_info_service.dart';
import 'package:gena/features/downloads/data/default_seed_models.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:path_provider/path_provider.dart';

enum ModelUsage { llm, embedder }

enum ModelCompatibilityStatus {
  remote,
  recommended,
  compatible,
  limited,
  incompatible,
}

class StorageInsights {
  const StorageInsights({
    required this.totalStorageBytes,
    required this.freeStorageBytes,
    required this.modelFilesBytes,
    required this.modelFileCount,
  });

  final int totalStorageBytes;
  final int freeStorageBytes;
  final int modelFilesBytes;
  final int modelFileCount;
}

class ModelCatalogInsight {
  const ModelCatalogInsight({
    required this.usage,
    required this.isRemote,
    required this.sizeBytes,
    required this.sizeLabel,
    required this.minimumRamBytes,
    required this.recommendedRamBytes,
    required this.status,
    required this.recommendedContextTokens,
    required this.experimental,
  });

  final ModelUsage usage;
  final bool isRemote;
  final int sizeBytes;
  final String? sizeLabel;
  final int minimumRamBytes;
  final int recommendedRamBytes;
  final ModelCompatibilityStatus status;
  final int recommendedContextTokens;
  final bool experimental;

  bool get compatible => status != ModelCompatibilityStatus.incompatible;

  bool get recommended =>
      status == ModelCompatibilityStatus.recommended ||
      status == ModelCompatibilityStatus.remote;

  bool get limited => status == ModelCompatibilityStatus.limited;

  String get statusLabel => switch (status) {
    ModelCompatibilityStatus.remote => 'Remote',
    ModelCompatibilityStatus.recommended => 'Recommended',
    ModelCompatibilityStatus.compatible => 'Compatible',
    ModelCompatibilityStatus.limited => 'Limited',
    ModelCompatibilityStatus.incompatible => 'Incompatible',
  };
}

class ModelCatalogInsightsService {
  ModelCatalogInsightsService(this._deviceInfoService);

  final DeviceSystemInfoService _deviceInfoService;

  Future<DeviceSystemInfo> getDeviceInfo({bool forceRefresh = false}) {
    return _deviceInfoService.getInfo(forceRefresh: forceRefresh);
  }

  Future<StorageInsights> getStorageInsights() async {
    final deviceInfo = await _deviceInfoService.getInfo();
    final appSupportDir = await getApplicationSupportDirectory();

    var totalBytes = 0;
    var fileCount = 0;
    await for (final entity in appSupportDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      if (!_isModelLikeFile(entity.path)) continue;
      final length = await entity.length();
      totalBytes += length;
      fileCount += 1;
    }

    return StorageInsights(
      totalStorageBytes: deviceInfo.totalStorageBytes,
      freeStorageBytes: deviceInfo.freeStorageBytes,
      modelFilesBytes: totalBytes,
      modelFileCount: fileCount,
    );
  }

  Future<ModelCatalogInsight> describeModel(ModelInfo model) async {
    final deviceInfo = await _deviceInfoService.getInfo();
    return describeLlmModel(model, deviceInfo: deviceInfo);
  }

  ModelCatalogInsight describeLlmModel(
    ModelInfo model, {
    required DeviceSystemInfo deviceInfo,
  }) {
    final defaultModel = findDefaultSeedModelByNameOrSource(
      name: model.name,
      source: model.source,
    );
    final sizeBytes = defaultModel != null
        ? _parseSizeToBytes(defaultModel.size)
        : _resolveLocalFileSize(model.sourceType, model.source);
    final isRemote = model.provider == 'remote';
    final minimumRamBytes = defaultModel == null
        ? _estimateMinimumRam(sizeBytes)
        : _gibibytes(defaultModel.minimumRamGb);
    final recommendedRamBytes = defaultModel == null
        ? _estimateRecommendedRam(sizeBytes)
        : _gibibytes(defaultModel.recommendedRamGb);
    final status = isRemote
        ? ModelCompatibilityStatus.remote
        : _resolveStatus(
            deviceInfo: deviceInfo,
            sizeBytes: sizeBytes,
            minimumRamBytes: minimumRamBytes,
            recommendedRamBytes: recommendedRamBytes,
          );

    return ModelCatalogInsight(
      usage: ModelUsage.llm,
      isRemote: isRemote,
      sizeBytes: sizeBytes,
      sizeLabel: _formatSize(sizeBytes),
      minimumRamBytes: minimumRamBytes,
      recommendedRamBytes: recommendedRamBytes,
      status: status,
      recommendedContextTokens: _contextLimit(deviceInfo.totalRamBytes),
      experimental:
          defaultModel?.validationStatus == ModelValidationStatus.experimental,
    );
  }

  ModelCompatibilityStatus _resolveStatus({
    required DeviceSystemInfo deviceInfo,
    required int sizeBytes,
    required int minimumRamBytes,
    required int recommendedRamBytes,
  }) {
    final storageRequired = sizeBytes <= 0 ? 0 : (sizeBytes * 1.15).round();
    if (deviceInfo.freeStorageBytes > 0 &&
        storageRequired > 0 &&
        deviceInfo.freeStorageBytes < storageRequired) {
      return ModelCompatibilityStatus.incompatible;
    }
    if (deviceInfo.totalRamBytes > 0 &&
        minimumRamBytes > 0 &&
        deviceInfo.totalRamBytes < minimumRamBytes) {
      return ModelCompatibilityStatus.incompatible;
    }

    final estimatedWorkingSet = _estimatedWorkingSet(
      sizeBytes: sizeBytes,
      minimumRamBytes: minimumRamBytes,
    );
    if (deviceInfo.availableRamBytes > 0 &&
        estimatedWorkingSet > 0 &&
        deviceInfo.availableRamBytes < estimatedWorkingSet) {
      return ModelCompatibilityStatus.limited;
    }
    if (deviceInfo.totalRamBytes > 0 &&
        recommendedRamBytes > 0 &&
        deviceInfo.totalRamBytes >= recommendedRamBytes) {
      return ModelCompatibilityStatus.recommended;
    }
    return ModelCompatibilityStatus.compatible;
  }

  int _estimateMinimumRam(int sizeBytes) {
    if (sizeBytes <= 0) return 0;
    final estimated = (sizeBytes * 1.5).round();
    final floor = _gibibytes(2);
    return estimated < floor ? floor : estimated;
  }

  int _estimateRecommendedRam(int sizeBytes) {
    if (sizeBytes <= 0) return 0;
    final doubled = sizeBytes * 2;
    final floor = 2 * 1024 * 1024 * 1024;
    return doubled < floor ? floor : doubled;
  }

  int _estimatedWorkingSet({
    required int sizeBytes,
    required int minimumRamBytes,
  }) {
    final fromWeights = (sizeBytes * 1.4).round();
    final fromMinimum = (minimumRamBytes * 0.5).round();
    return fromWeights > fromMinimum ? fromWeights : fromMinimum;
  }

  int _contextLimit(int totalRamBytes) {
    final gb = totalRamBytes / (1024 * 1024 * 1024);
    if (totalRamBytes <= 0 || gb < 4) return 2048;
    if (gb < 6) return 4096;
    if (gb < 8) return 8192;
    if (gb < 12) return 16384;
    return 32768;
  }

  int _gibibytes(double value) => (value * 1024 * 1024 * 1024).round();

  int _resolveLocalFileSize(String sourceType, String source) {
    if (sourceType != 'file') return 0;
    final file = File(source);
    if (!file.existsSync()) return 0;
    return file.lengthSync();
  }

  bool _isModelLikeFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.task') ||
        lower.endsWith('.litertlm') ||
        lower.endsWith('.gguf') ||
        lower.endsWith('.bin') ||
        lower.endsWith('.tflite') ||
        lower.endsWith('sentencepiece.model');
  }

  int _parseSizeToBytes(String size) {
    final normalized = size.trim().toUpperCase();
    final match = RegExp(
      r'^(\d+(?:\.\d+)?)\s*(KB|MB|GB)$',
    ).firstMatch(normalized);
    if (match == null) return 0;
    final value = double.tryParse(match.group(1) ?? '') ?? 0;
    final unit = match.group(2) ?? '';
    final multiplier = switch (unit) {
      'KB' => 1024,
      'MB' => 1024 * 1024,
      'GB' => 1024 * 1024 * 1024,
      _ => 1,
    };
    return (value * multiplier).round();
  }

  String? _formatSize(int bytes) {
    if (bytes <= 0) return null;
    const gb = 1024 * 1024 * 1024;
    const mb = 1024 * 1024;
    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(1)}GB';
    }
    return '${(bytes / mb).toStringAsFixed(0)}MB';
  }
}
