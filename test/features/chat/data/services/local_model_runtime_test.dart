import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' hide ModelInfo;

import 'package:gena/features/chat/data/services/local_model_runtime.dart';
import 'package:gena/features/chat/data/services/llamadart_local_model_runtime.dart';
import 'package:gena/features/chat/data/services/unsupported_local_model_runtime.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:llamadart/llamadart.dart' show ComputeDevice;

ModelInfo _model({
  required String source,
  int maxTokens = 4096,
  String? mmprojSource,
  String preferredBackend = 'cpu',
}) {
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
    preferredBackend: preferredBackend,
    sourceType: 'file',
    source: source,
    mmprojSource: mmprojSource,
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

class _ControlledLoader implements LocalRuntimeLoader {
  _ControlledLoader(
    this._beforeLoadCompletes, {
    Future<void> Function(int loadNumber)? beforeDisposeCompletes,
  }) : _beforeDisposeCompletes = beforeDisposeCompletes;

  final Future<void> Function(LocalRuntimeRequest request, int loadNumber)
  _beforeLoadCompletes;
  final Future<void> Function(int loadNumber)? _beforeDisposeCompletes;

  int loads = 0;
  int activeLoads = 0;
  int maxActiveLoads = 0;
  final List<LocalRuntimeRequest> requests = <LocalRuntimeRequest>[];
  final Map<int, int> cancelCallsByLoad = <int, int>{};
  final Map<int, int> disposeAttemptsByLoad = <int, int>{};
  final Map<int, int> disposesByLoad = <int, int>{};

  @override
  Future<LoadedLocalRuntime> load(LocalRuntimeRequest request) async {
    final loadNumber = ++loads;
    requests.add(request);
    activeLoads++;
    if (activeLoads > maxActiveLoads) {
      maxActiveLoads = activeLoads;
    }
    try {
      await _beforeLoadCompletes(request, loadNumber);
    } finally {
      activeLoads--;
    }
    return LoadedLocalRuntime(
      ai: Genkit(),
      modelRef: modelRef<dynamic>('controlled-$loadNumber'),
      modelId: 'controlled-id-$loadNumber',
      cancel: () {
        cancelCallsByLoad.update(
          loadNumber,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      },
      dispose: () async {
        disposeAttemptsByLoad.update(
          loadNumber,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        await _beforeDisposeCompletes?.call(loadNumber);
        disposesByLoad.update(
          loadNumber,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      },
    );
  }
}

void main() {
  group('buildLocalModelParams', () {
    test('forces the model CPU preference instead of LiteRT automatic GPU', () {
      final request = LocalRuntimeRequest(
        modelInfo: _model(
          source: '/models/qwen3.litertlm',
          preferredBackend: 'cpu',
        ),
        contextSize: 4096,
        constrainedOutput: false,
      );

      final params = buildLocalModelParams(request);

      expect(params.contextSize, 4096);
      expect(params.device, ComputeDevice.cpu);
    });

    test('maps explicit GPU and NPU model preferences', () {
      paramsFor(String backend) => buildLocalModelParams(
        LocalRuntimeRequest(
          modelInfo: _model(
            source: '/models/model.litertlm',
            preferredBackend: backend,
          ),
          contextSize: 2048,
          constrainedOutput: false,
        ),
      );

      expect(paramsFor('gpu').device, ComputeDevice.gpu);
      expect(paramsFor('npu').device, ComputeDevice.npu);
    });

    test('keeps automatic selection for an unknown legacy preference', () {
      final params = buildLocalModelParams(
        LocalRuntimeRequest(
          modelInfo: _model(
            source: '/models/model.gguf',
            preferredBackend: 'legacy',
          ),
          contextSize: 1024,
          constrainedOutput: true,
        ),
      );

      expect(params.device, ComputeDevice.auto);
    });
  });

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
    test(
      'concurrent prepares for the same key share one loaded runtime',
      () async {
        final loadStarted = Completer<void>();
        final releaseLoad = Completer<void>();
        final loader = _ControlledLoader((request, loadNumber) async {
          if (!loadStarted.isCompleted) {
            loadStarted.complete();
          }
          await releaseLoad.future;
        });
        final runtime = CachingLocalModelRuntime(loader);
        final model = _model(source: '/models/a.gguf');

        final firstFuture = runtime.prepare(model);
        final secondFuture = runtime.prepare(model);
        await loadStarted.future;
        releaseLoad.complete();

        final first = await firstFuture;
        final second = await secondFuture;

        expect(loader.loads, 1);
        expect(second, same(first));
      },
    );

    test(
      'serializes different keys so an earlier delayed load cannot win',
      () async {
        final firstLoadStarted = Completer<void>();
        final releaseFirstLoad = Completer<void>();
        final loader = _ControlledLoader((request, loadNumber) async {
          if (request.modelInfo.source.endsWith('a.gguf')) {
            firstLoadStarted.complete();
            await releaseFirstLoad.future;
          }
        });
        final runtime = CachingLocalModelRuntime(loader);
        final firstModel = _model(source: '/models/a.gguf');
        final laterModel = _model(source: '/models/b.gguf');

        final firstFuture = runtime.prepare(firstModel);
        await firstLoadStarted.future;
        final laterFuture = runtime.prepare(laterModel);
        releaseFirstLoad.complete();

        final first = await firstFuture;
        final later = await laterFuture;
        final cachedLater = await runtime.prepare(laterModel);

        expect(loader.loads, 2);
        expect(loader.maxActiveLoads, 1);
        expect(first.modelId, 'controlled-id-1');
        expect(later.modelId, 'controlled-id-2');
        expect(cachedLater, same(later));
        expect(loader.disposesByLoad, <int, int>{1: 1});
      },
    );

    test(
      'reset waits for prepare and disposes every superseded runtime once',
      () async {
        final firstLoadStarted = Completer<void>();
        final releaseFirstLoad = Completer<void>();
        final loader = _ControlledLoader((request, loadNumber) async {
          if (loadNumber == 1) {
            firstLoadStarted.complete();
            await releaseFirstLoad.future;
          }
        });
        final runtime = CachingLocalModelRuntime(loader);
        final model = _model(source: '/models/a.gguf');

        final prepareFuture = runtime.prepare(model);
        await firstLoadStarted.future;
        final resetFuture = runtime.reset();
        releaseFirstLoad.complete();

        await prepareFuture;
        await resetFuture;
        await runtime.prepare(model);
        await runtime.reset();

        expect(loader.loads, 2);
        expect(loader.disposesByLoad, <int, int>{1: 1, 2: 1});
      },
    );

    test('loader failure does not poison later operations', () async {
      final loader = _ControlledLoader((request, loadNumber) async {
        if (loadNumber == 1) {
          throw StateError('first load failed');
        }
      });
      final runtime = CachingLocalModelRuntime(loader);
      final model = _model(source: '/models/a.gguf');

      await expectLater(runtime.prepare(model), throwsStateError);
      final prepared = await runtime.prepare(model);

      expect(loader.loads, 2);
      expect(prepared.modelId, 'controlled-id-2');
    });

    test(
      'does not begin the next load until slow disposal completes',
      () async {
        final disposeStarted = Completer<void>();
        final releaseDispose = Completer<void>();
        final loader = _ControlledLoader(
          (request, loadNumber) async {},
          beforeDisposeCompletes: (loadNumber) async {
            if (loadNumber == 1) {
              disposeStarted.complete();
              await releaseDispose.future;
            }
          },
        );
        final runtime = CachingLocalModelRuntime(loader);

        await runtime.prepare(_model(source: '/models/a.gguf'));
        final nextPrepare = runtime.prepare(_model(source: '/models/b.gguf'));
        await disposeStarted.future;

        expect(loader.loads, 1);
        runtime.cancelActiveGeneration();
        expect(loader.cancelCallsByLoad, <int, int>{1: 1});

        releaseDispose.complete();
        await nextPrepare;

        expect(loader.loads, 2);
        expect(loader.disposesByLoad, <int, int>{1: 1});
      },
    );

    test(
      'failed disposal blocks a new load and keeps cancellation reachable',
      () async {
        final loader = _ControlledLoader(
          (request, loadNumber) async {},
          beforeDisposeCompletes: (loadNumber) async {
            if (loadNumber == 1) {
              throw StateError('dispose failed');
            }
          },
        );
        final runtime = CachingLocalModelRuntime(loader);

        await runtime.prepare(_model(source: '/models/a.gguf'));
        await expectLater(
          runtime.prepare(_model(source: '/models/b.gguf')),
          throwsStateError,
        );
        runtime.cancelActiveGeneration();

        expect(loader.loads, 1);
        expect(loader.cancelCallsByLoad, <int, int>{1: 1});
        expect(loader.disposeAttemptsByLoad, <int, int>{1: 1});
        expect(loader.disposesByLoad, isEmpty);
      },
    );

    test(
      'dispose failure stays fail-closed without retrying native release',
      () async {
        final disposeFailure = StateError('released then failed');
        var nativeReleases = 0;
        final loader = _ControlledLoader(
          (request, loadNumber) async {},
          beforeDisposeCompletes: (loadNumber) async {
            if (loadNumber == 1) {
              nativeReleases++;
              if (nativeReleases == 1) {
                throw disposeFailure;
              }
              throw StateError('native dispose was retried');
            }
          },
        );
        final runtime = CachingLocalModelRuntime(loader);
        final nextModel = _model(source: '/models/b.gguf');

        await runtime.prepare(_model(source: '/models/a.gguf'));
        Object? firstError;
        StackTrace? firstStackTrace;
        try {
          await runtime.prepare(nextModel);
        } catch (error, stackTrace) {
          firstError = error;
          firstStackTrace = stackTrace;
        }

        Object? laterPrepareError;
        StackTrace? laterPrepareStackTrace;
        try {
          await runtime.prepare(nextModel);
        } catch (error, stackTrace) {
          laterPrepareError = error;
          laterPrepareStackTrace = stackTrace;
        }

        Object? laterResetError;
        StackTrace? laterResetStackTrace;
        try {
          await runtime.reset();
        } catch (error, stackTrace) {
          laterResetError = error;
          laterResetStackTrace = stackTrace;
        }
        runtime.cancelActiveGeneration();

        expect(firstError, same(disposeFailure));
        expect(laterPrepareError, same(disposeFailure));
        expect(laterResetError, same(disposeFailure));
        final originalStackPrefix = firstStackTrace
            .toString()
            .split('<asynchronous suspension>')
            .first;
        expect(
          laterPrepareStackTrace.toString(),
          startsWith(originalStackPrefix),
        );
        expect(
          laterResetStackTrace.toString(),
          startsWith(originalStackPrefix),
        );
        expect(nativeReleases, 1);
        expect(loader.loads, 1);
        expect(loader.disposeAttemptsByLoad, <int, int>{1: 1});
        expect(loader.disposesByLoad, isEmpty);
        expect(loader.cancelCallsByLoad, <int, int>{1: 1});
      },
    );

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

    test('reloads when the preferred compute backend changes', () async {
      final loader = _FakeLoader();
      final runtime = CachingLocalModelRuntime(loader);

      await runtime.prepare(
        _model(source: '/models/a.litertlm', preferredBackend: 'cpu'),
      );
      await runtime.prepare(
        _model(source: '/models/a.litertlm', preferredBackend: 'gpu'),
      );

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

    test('mmprojPath is null when the model has no projector', () async {
      final loader = _FakeLoader();
      final runtime = CachingLocalModelRuntime(loader);

      await runtime.prepare(_model(source: '/models/a.gguf'));

      expect(loader.requests.single.mmprojPath, isNull);
    });

    test(
      'flows a local mmprojSource into the request as a canonical path',
      () async {
        final loader = _FakeLoader();
        final runtime = CachingLocalModelRuntime(loader);

        await runtime.prepare(
          _model(
            source: '/models/a.gguf',
            mmprojSource: '/models/mmproj-a.gguf',
          ),
        );

        expect(loader.requests.single.mmprojPath, isNotNull);
        expect(loader.requests.single.mmprojPath, contains('mmproj-a.gguf'));
      },
    );

    test('ignores a remote (not-yet-downloaded) projector URL', () async {
      final loader = _FakeLoader();
      final runtime = CachingLocalModelRuntime(loader);

      await runtime.prepare(
        _model(
          source: '/models/a.gguf',
          mmprojSource: 'https://example.com/mmproj-a.gguf',
        ),
      );

      expect(loader.requests.single.mmprojPath, isNull);
    });

    test('reloads when the projector path changes', () async {
      final loader = _FakeLoader();
      final runtime = CachingLocalModelRuntime(loader);

      await runtime.prepare(_model(source: '/models/a.gguf'));
      await runtime.prepare(
        _model(source: '/models/a.gguf', mmprojSource: '/models/mmproj-a.gguf'),
      );

      expect(loader.loads, 2);
      expect(loader.disposes, 1);
    });

    test('reuses the cached runtime when the projector is unchanged', () async {
      final loader = _FakeLoader();
      final runtime = CachingLocalModelRuntime(loader);

      await runtime.prepare(
        _model(source: '/models/a.gguf', mmprojSource: '/models/mmproj-a.gguf'),
      );
      await runtime.prepare(
        _model(source: '/models/a.gguf', mmprojSource: '/models/mmproj-a.gguf'),
      );

      expect(loader.loads, 1);
      expect(loader.disposes, 0);
    });

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
