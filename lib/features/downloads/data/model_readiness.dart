import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';

String installedModelIdFromSource(String source) {
  final parts = source.split(RegExp(r'[/\\]'));
  return parts.isEmpty ? source : parts.last;
}

bool isModelReady(ModelInfo model, List<String> installedModels) {
  if (model.provider == ModelProviderType.remote) return true;
  final installedId = installedModelIdFromSource(model.source);
  return installedModels.contains(installedId);
}
