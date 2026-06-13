import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' hide ModelInfo;

import 'package:gena/features/chat/data/services/local_model_runtime.dart';
import 'package:gena/features/chat/data/services/unsupported_local_model_runtime.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';

ModelInfo _model({required String source, int maxTokens = 4096}) {
  return ModelInfo(
    id: 1,
    name: 'Test',
    description: '',
    provider: 'local',
    modelType: 'general',
    supportImage: false,
    supportAudio: false,
    supportsFunctionCalls: false,
    isThinking: false,
    temperature: 0.7,
    topK: 40,
    topP: 0.95,
    maxTokens: maxTokens,
    tokenBuffer: 256,
    randomSeed: 0,
    preferredBackend: 'cpu',
    sourceType: 'file',
    source: source,
  );
}

class _FakeLoader implements LocalRuntimeLoader {
  int loads = 0;
  int disposes = 0;
  int cancels = 0;
  final List<LocalRuntimeRequest> requests = <LocalRuntimeRequest>[];

  @override
  Future<LoadedLocalRuntime> load(LocalRuntimeRequest request) async {
    loads++;
    requests.add(request);
    return LoadedLocalRuntime(
      ai: Genkit(),
      modelRef: modelRef<dynamic>('fake-$loads'),
      modelId: 'fake-id-$loads',
      cancel: () => cancels++,
      dispose: () async => disposes++,
    );
  }
}

void main() {
  group('fallbackTokenEstimate', () {
    test('empty text is zero tokens', () {
      expect(fallbackTokenEstimate(''), 0);
    });

    test('estimates roughly one token per four characters', () {
      expect(fallbackTokenEstimate('abcd'), 1);
      expect(fallbackTokenEstimate('abcde'), 2);
    });
  });

  group('CachingLocalModelRuntime', () {
    test('reuses the cached runtime for the same model and settings', () async {
      final loader = _FakeLoader();
      final runtime = CachingLocalModelRuntime(loader);

      final first = await runtime.prepare(_model(source: '/models/a.gguf'));
      final second = await runtime.prepare(_model(source: '/models/a.gguf'));

      expect(loader.loads, 1);
      expect(loader.disposes, 0);
      expect(second.modelId, first.modelId);
    });

    test(
      'disposes the previous runtime before switching model files',
      () async {
        final loader = _FakeLoader();
        final runtime = CachingLocalModelRuntime(loader);

        await runtime.prepare(_model(source: '/models/a.gguf'));
        await runtime.prepare(_model(source: '/models/b.litertlm'));

        expect(loader.loads, 2);
        expect(loader.disposes, 1);
      },
    );

    test('reloads when the context window changes', () async {
      final loader = _FakeLoader();
      final runtime = CachingLocalModelRuntime(loader);

      await runtime.prepare(_model(source: '/models/a.gguf', maxTokens: 2048));
      await runtime.prepare(_model(source: '/models/a.gguf', maxTokens: 4096));

      expect(loader.loads, 2);
      expect(loader.disposes, 1);
    });

    test('forwards cancellation to the active runtime', () async {
      final loader = _FakeLoader();
      final runtime = CachingLocalModelRuntime(loader);

      await runtime.prepare(_model(source: '/models/a.gguf'));
      runtime.cancelActiveGeneration();

      expect(loader.cancels, 1);
    });

    test('reset disposes and clears the active runtime', () async {
      final loader = _FakeLoader();
      final runtime = CachingLocalModelRuntime(loader);

      await runtime.prepare(_model(source: '/models/a.gguf'));
      await runtime.reset();
      await runtime.prepare(_model(source: '/models/a.gguf'));

      expect(loader.loads, 2);
      expect(loader.disposes, 1);
    });

    test(
      'maps GGUF sources to constrained output and litertlm to off',
      () async {
        final loader = _FakeLoader();
        final runtime = CachingLocalModelRuntime(loader);

        await runtime.prepare(_model(source: '/models/a.gguf'));
        await runtime.prepare(_model(source: '/models/b.litertlm'));

        expect(loader.requests[0].constrainedOutput, isTrue);
        expect(loader.requests[1].constrainedOutput, isFalse);
        expect(loader.requests[0].contextSize, 4096);
      },
    );

    test('rejects unsupported sources', () async {
      final loader = _FakeLoader();
      final runtime = CachingLocalModelRuntime(loader);

      expect(
        () => runtime.prepare(_model(source: '/models/a.task')),
        throwsA(isA<LocalModelRuntimeException>()),
      );
      expect(loader.loads, 0);
    });

    test('token counting falls back to the estimate', () async {
      final runtime = CachingLocalModelRuntime(_FakeLoader());
      expect(await runtime.countTokens('abcd'), fallbackTokenEstimate('abcd'));
    });
  });

  group('UnsupportedLocalModelRuntime', () {
    test('rejects local preparation', () {
      final runtime = UnsupportedLocalModelRuntime();
      expect(
        () => runtime.prepare(_model(source: '/models/a.gguf')),
        throwsA(isA<LocalModelRuntimeException>()),
      );
    });

    test(
      'still provides a token estimate and no-op cancellation/reset',
      () async {
        final runtime = UnsupportedLocalModelRuntime();
        expect(
          await runtime.countTokens('abcd'),
          fallbackTokenEstimate('abcd'),
        );
        runtime.cancelActiveGeneration();
        await runtime.reset();
      },
    );
  });
}
