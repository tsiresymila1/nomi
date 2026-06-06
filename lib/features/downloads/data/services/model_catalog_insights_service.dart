import 'dart:io';

import 'package:gena/core/services/device_system_info_service.dart';
import 'package:gena/features/downloads/data/default_embedder_models.dart';
import 'package:gena/features/downloads/data/default_seed_models.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:path_provider/path_provider.dart';

enum ModelUsage { llm, embedder }

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
    required this.recommendedRamBytes,
    required this.compatible,
    required this.recommended,
    required this.statusLabel,
  });

  final ModelUsage usage;
  final bool isRemote;
  final int sizeBytes;
  final String? sizeLabel;
  final int recommendedRamBytes;
  final bool compatible;
  final bool recommended;
  final String statusLabel;
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
    final recommendedRamBytes = _estimateRecommendedRam(sizeBytes);
    final isRemote = model.provider == 'remote';
    final compatible =
        isRemote ||
        _isCompatible(
          totalRamBytes: deviceInfo.totalRamBytes,
          recommendedRamBytes: recommendedRamBytes,
          freeStorageBytes: deviceInfo.freeStorageBytes,
          sizeBytes: sizeBytes,
        );
    final recommended =
        isRemote ||
        _isRecommended(
          totalRamBytes: deviceInfo.totalRamBytes,
          recommendedRamBytes: recommendedRamBytes,
        );

    return ModelCatalogInsight(
      usage: ModelUsage.llm,
      isRemote: isRemote,
      sizeBytes: sizeBytes,
      sizeLabel: _formatSize(sizeBytes),
      recommendedRamBytes: recommendedRamBytes,
      compatible: compatible,
      recommended: recommended,
      statusLabel: _buildStatusLabel(
        compatible: compatible,
        recommended: recommended,
        isRemote: isRemote,
      ),
    );
  }

  Future<ModelCatalogInsight> describeEmbedderModel(String modelKey) async {
    final deviceInfo = await _deviceInfoService.getInfo();
    final embedder = findDefaultEmbedderModel(modelKey);
    final sizeBytes = embedder?.sizeBytes ?? 0;
    final recommendedRamBytes = embedder?.recommendedRamBytes ?? 0;
    final compatible = _isCompatible(
      totalRamBytes: deviceInfo.totalRamBytes,
      recommendedRamBytes: recommendedRamBytes,
      freeStorageBytes: deviceInfo.freeStorageBytes,
      sizeBytes: sizeBytes,
    );
    final recommended = _isRecommended(
      totalRamBytes: deviceInfo.totalRamBytes,
      recommendedRamBytes: recommendedRamBytes,
    );

    return ModelCatalogInsight(
      usage: ModelUsage.embedder,
      isRemote: false,
      sizeBytes: sizeBytes,
      sizeLabel: embedder?.sizeLabel ?? _formatSize(sizeBytes),
      recommendedRamBytes: recommendedRamBytes,
      compatible: compatible,
      recommended: recommended,
      statusLabel: _buildStatusLabel(
        compatible: compatible,
        recommended: recommended,
        isRemote: false,
      ),
    );
  }

  bool _isCompatible({
    required int totalRamBytes,
    required int recommendedRamBytes,
    required int freeStorageBytes,
    required int sizeBytes,
  }) {
    final ramOkay =
        totalRamBytes <= 0 ||
        recommendedRamBytes <= 0 ||
        totalRamBytes >= recommendedRamBytes;
    final storageOkay =
        freeStorageBytes <= 0 ||
        sizeBytes <= 0 ||
        freeStorageBytes >= sizeBytes;
    return ramOkay && storageOkay;
  }

  bool _isRecommended({
    required int totalRamBytes,
    required int recommendedRamBytes,
  }) {
    if (recommendedRamBytes <= 0 || totalRamBytes <= 0) return false;
    return totalRamBytes >= (recommendedRamBytes * 1.2).round();
  }

  int _estimateRecommendedRam(int sizeBytes) {
    if (sizeBytes <= 0) return 0;
    final doubled = sizeBytes * 2;
    final floor = 2 * 1024 * 1024 * 1024;
    return doubled < floor ? floor : doubled;
  }

  int _resolveLocalFileSize(String sourceType, String source) {
    if (sourceType != 'file') return 0;
    final file = File(source);
    if (!file.existsSync()) return 0;
    return file.lengthSync();
  }

  String _buildStatusLabel({
    required bool compatible,
    required bool recommended,
    required bool isRemote,
  }) {
    if (isRemote) return 'Remote';
    if (!compatible) return 'Incompatible';
    if (recommended) return 'Recommended';
    return 'Compatible';
  }

  bool _isModelLikeFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.task') ||
        lower.endsWith('.litertlm') ||
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
