import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/downloads/data/model_readiness.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';

Future<List<String>> loadInstalledModelsIfSupported({
  required AppCapabilities capabilities,
  required Future<List<String>> Function() loadInstalledModels,
}) {
  if (!capabilities.supportsLocalModels) {
    return Future.value(const <String>[]);
  }
  return loadInstalledModels();
}

List<ModelInfo> readyModelsForCapabilities({
  required List<ModelInfo> models,
  required List<String> installedModels,
  required AppCapabilities capabilities,
}) {
  return models
      .where(
        (model) =>
            model.provider == ModelProviderType.remote ||
            (capabilities.supportsLocalModels &&
                isModelReady(model, installedModels)),
      )
      .toList(growable: false);
}

/// Never chooses a remote fallback automatically on a local-capable device.
/// Remote-only platforms may still select their first usable model.
ModelInfo? automaticReadyModelForPlatform({
  required List<ModelInfo> readyModels,
  required bool supportsLocalModels,
}) {
  if (!supportsLocalModels) return readyModels.firstOrNull;
  return readyModels
      .where((model) => model.provider == ModelProviderType.local)
      .firstOrNull;
}
