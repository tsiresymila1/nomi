import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/default_seed_models.dart';

final Set<String> _defaultModelNames = kDefaultSeedModels
    .map((model) => _normalize(model.displayName))
    .toSet();

final Set<String> _defaultModelUrls = kDefaultSeedModels
    .map((model) => _normalize(model.sourceUrl))
    .toSet();

bool isDefaultStaticModel(ModelInfo model) {
  final name = _normalize(model.name);
  final source = _normalize(model.source);
  return _defaultModelNames.contains(name) ||
      _defaultModelUrls.contains(source);
}

String? defaultStaticModelSourceUrl(ModelInfo model) {
  return findDefaultSeedModelByNameOrSource(
    name: model.name,
    source: model.source,
  )?.sourceUrl;
}

String _normalize(String value) {
  return value.trim().toLowerCase();
}
