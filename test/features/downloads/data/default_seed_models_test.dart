import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/downloads/data/default_seed_models.dart';

void main() {
  Iterable<String> allSources(DefaultSeedModel model) sync* {
    yield model.baseUrl;
    if (model.webUrl != null && model.webUrl!.isNotEmpty) yield model.webUrl!;
    if (model.desktopUrl != null && model.desktopUrl!.isNotEmpty) {
      yield model.desktopUrl!;
    }
  }

  bool isCompatible(String url) =>
      url.endsWith('.gguf') || url.endsWith('.litertlm');

  test('all default local model sources are llamadart compatible', () {
    for (final model in kDefaultSeedModels) {
      expect(
        isCompatible(model.sourceUrl),
        isTrue,
        reason: '${model.key} sourceUrl must be .gguf/.litertlm: '
            '${model.sourceUrl}',
      );
      expect(model.sourceUrl.endsWith('.task'), isFalse);
    }
  });

  test('no catalog source references a FlutterGemma .task bundle', () {
    for (final model in kDefaultSeedModels) {
      for (final url in allSources(model)) {
        expect(
          isCompatible(url),
          isTrue,
          reason: '${model.key} has incompatible source: $url',
        );
        expect(url.endsWith('.task'), isFalse);
      }
    }
  });

  test('catalog keys are unique', () {
    final keys = kDefaultSeedModels.map((model) => model.key).toList();
    expect(keys.toSet().length, keys.length);
  });

  test('every entry exposes a non-empty source url', () {
    for (final model in kDefaultSeedModels) {
      expect(model.sourceUrl, isNotEmpty);
    }
  });
}
