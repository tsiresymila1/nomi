import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/services/device_system_info_service.dart';
import 'package:gena/features/downloads/data/default_seed_models.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/data/services/model_catalog_insights_service.dart';

void main() {
  final service = ModelCatalogInsightsService(DeviceSystemInfoService());

  test('recommends Qwen3 0.6B on a healthy 4 GB device', () {
    final insight = service.describeLlmModel(
      _defaultModel('qwen3_0_6b_q4_k_m'),
      deviceInfo: _device(totalGb: 4, availableGb: 2),
    );

    expect(insight.status, ModelCompatibilityStatus.recommended);
    expect(insight.recommended, isTrue);
    expect(insight.recommendedContextTokens, 4096);
  });

  test('marks a larger but runnable model as compatible', () {
    final insight = service.describeLlmModel(
      _defaultModel('qwen2_5_1_5b_instruct_q4_k_m'),
      deviceInfo: _device(totalGb: 4, availableGb: 2),
    );

    expect(insight.status, ModelCompatibilityStatus.compatible);
    expect(insight.compatible, isTrue);
    expect(insight.recommended, isFalse);
  });

  test('uses current available RAM to mark a model as limited', () {
    final insight = service.describeLlmModel(
      _defaultModel('qwen3_0_6b_q4_k_m'),
      deviceInfo: _device(totalGb: 4, availableGb: 0.5),
    );

    expect(insight.status, ModelCompatibilityStatus.limited);
    expect(insight.compatible, isTrue);
    expect(insight.limited, isTrue);
  });

  test('hides a model whose minimum RAM exceeds the device RAM', () {
    final insight = service.describeLlmModel(
      _defaultModel('smollm3_3b_q4_k_m'),
      deviceInfo: _device(totalGb: 4, availableGb: 2),
    );

    expect(insight.status, ModelCompatibilityStatus.incompatible);
    expect(insight.compatible, isFalse);
  });

  test('accounts for download headroom and recognizes GGUF storage', () {
    final insight = service.describeLlmModel(
      _defaultModel('qwen3_0_6b_q4_k_m'),
      deviceInfo: _device(totalGb: 4, availableGb: 2, freeStorageGb: 0.1),
    );

    expect(insight.status, ModelCompatibilityStatus.incompatible);
  });
}

ModelInfo _defaultModel(String key) {
  final seed = kDefaultSeedModels.firstWhere((model) => model.key == key);
  return ModelInfo(
    id: 1,
    name: seed.displayName,
    description: seed.notes,
    provider: ModelProviderType.local,
    modelType: seed.modelType.name,
    supportImage: seed.supportImage,
    supportAudio: seed.supportAudio,
    supportsFunctionCalls: seed.supportsFunctionCalls,
    isThinking: seed.isThinking,
    temperature: seed.temperature,
    topK: seed.topK,
    topP: seed.topP,
    maxTokens: seed.maxTokens,
    tokenBuffer: 256,
    randomSeed: 1,
    preferredBackend: seed.preferredBackend.name,
    sourceType: 'file',
    source: seed.sourceUrl,
  );
}

DeviceSystemInfo _device({
  required double totalGb,
  required double availableGb,
  double freeStorageGb = 10,
}) {
  int bytes(double gb) => (gb * 1024 * 1024 * 1024).round();
  return DeviceSystemInfo(
    platform: 'android',
    cpuCores: 8,
    cpuModel: 'Tensor',
    gpuModel: 'Mali',
    totalRamBytes: bytes(totalGb),
    availableRamBytes: bytes(availableGb),
    totalStorageBytes: bytes(128),
    freeStorageBytes: bytes(freeStorageGb),
    abis: const <String>['arm64-v8a'],
  );
}
