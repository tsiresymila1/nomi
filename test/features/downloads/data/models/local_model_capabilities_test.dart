import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/downloads/data/models/local_model_capabilities.dart';

void main() {
  group('LocalModelType', () {
    test('every constant name round-trips through parse', () {
      for (final type in LocalModelType.values) {
        expect(parseLocalModelType(type.name), type);
      }
    });

    test('names match the persisted Drift strings', () {
      expect(LocalModelType.gemma4.name, 'gemma4');
      expect(LocalModelType.gemmaIt.name, 'gemmaIt');
      expect(LocalModelType.deepSeek.name, 'deepSeek');
      expect(LocalModelType.functionGemma.name, 'functionGemma');
    });

    test('unknown values fall back to general', () {
      expect(parseLocalModelType('not-a-real-type'), LocalModelType.general);
      expect(parseLocalModelType(''), LocalModelType.general);
    });
  });

  group('LocalModelBackend', () {
    test('every constant name round-trips through parse', () {
      for (final backend in LocalModelBackend.values) {
        expect(parseLocalModelBackend(backend.name), backend);
      }
    });

    test('null and unknown values return null', () {
      expect(parseLocalModelBackend(null), isNull);
      expect(parseLocalModelBackend('tpu'), isNull);
    });

    test('exposes exactly cpu, gpu, npu', () {
      expect(
        LocalModelBackend.values.map((b) => b.name).toList(),
        <String>['cpu', 'gpu', 'npu'],
      );
    });
  });
}
