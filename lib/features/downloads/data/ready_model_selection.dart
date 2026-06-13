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
