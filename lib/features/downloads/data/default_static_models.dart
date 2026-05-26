import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:smart_background_tasks/smart_background_tasks.dart';

final Set<String> _defaultModelNames = kDefaultFlutterGemmaModelSources
    .map((model) => _normalize(model.name))
    .toSet();

final Set<String> _defaultModelUrls = kDefaultFlutterGemmaModelSources
    .map((model) => _normalize(model.url))
    .toSet();

bool isDefaultStaticModel(ModelInfo model) {
  final name = _normalize(model.name);
  final source = _normalize(model.source);
  return _defaultModelNames.contains(name) ||
      _defaultModelUrls.contains(source);
}

String _normalize(String value) {
  return value.trim().toLowerCase();
}
