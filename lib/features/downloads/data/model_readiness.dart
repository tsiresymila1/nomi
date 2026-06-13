import 'package:gena/features/downloads/data/local_model_files.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';

String installedModelIdFromSource(String source) {
  return localModelIdForPath(source);
}

bool isModelReady(ModelInfo model, List<String> installedModels) {
  if (model.provider == ModelProviderType.remote) return true;
  if (model.sourceType != 'file' ||
      !isCompatibleLocalModelSource(model.source)) {
    return false;
  }
  final installedId = installedModelIdFromSource(model.source);
  return installedModels.contains(installedId);
}
