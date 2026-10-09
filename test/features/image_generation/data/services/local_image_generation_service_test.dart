import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/local_ai/local_ai_runtime_coordinator.dart';
import 'package:gena/features/image_generation/data/models/image_model_catalog.dart';
import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/data/services/image_generation_backend.dart';
import 'package:gena/features/image_generation/data/services/image_model_store.dart';
import 'package:gena/features/image_generation/data/services/local_image_generation_service.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_model_selection_cubit.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../../support/in_memory_hydrated_storage.dart';

void main() {
  group('ImageModelProfile.sdxs', () {
    test('pins the Android-friendly GGUF artifact and one-step defaults', () {
      const profile = ImageModelProfile.sdxs;

      expect(profile.id, 'sdxs-512-q8_0');
      expect(profile.fileName, 'sdxs-512-tinySDdistilled_Q8_0.gguf');
      expect(profile.sizeBytes, 682847200);
      expect(
        profile.sha256,
        '409ab23582ee074c6b9d5395784fc0741b0599fb9d138686c69087c71678eb6a',
      );
      expect(profile.steps, 1);
      expect(profile.guidanceScale, 1);
    });
  });

  group('LocalImageGenerationService', () {
    late LocalAiRuntimeCoordinator coordinator;
    late _FakeImageModelStore modelStore;
    late _FakeImageGenerationBackend backend;
    late _FakeGeneratedImageStore outputStore;
    late ImageModelSelectionCubit selection;
    late LocalImageGenerationService service;

    setUp(() {
      HydratedBloc.storage = InMemoryHydratedStorage();
      coordinator = LocalAiRuntimeCoordinator(
        requiresExclusiveAccess: () async => true,
      );
      modelStore = _FakeImageModelStore();
      backend = _FakeImageGenerationBackend();
      outputStore = _FakeGeneratedImageStore();
      selection = ImageModelSelectionCubit();
      service = LocalImageGenerationService(
        coordinator: coordinator,
        modelStore: modelStore,
        backend: backend,
        outputStore: outputStore,
        selection: selection,
      );
    });

    tearDown(() async {
      await service.releaseEngine();
      await selection.close();
      await coordinator.close();
    });

    test('reports runtime and installation support together', () async {
      backend.support = const ImageRuntimeSupport(
        isSupported: true,
        backendName: 'CPU',
      );

      final support = await service.checkSupport();

      expect(support.isSupported, isTrue);
      expect(support.backendName, 'CPU');
      expect(backend.checkRuntimeCalls, 1);
    });

    test('does not claim support when model storage is unavailable', () async {
      modelStore.isSupported = false;

      final support = await service.checkSupport();

      expect(support.isSupported, isFalse);
      expect(support.unsupportedReason, contains('storage'));
      expect(backend.checkRuntimeCalls, 0);
    });

    test('forwards install progress and verification', () async {
      final progress = <double>[];
      var verifying = false;

      final installed = await service.installModel(
        onProgress: progress.add,
        onVerifying: () => verifying = true,
      );

      expect(installed.modelPath, '/models/sdxs.gguf');
      expect(progress, <double>[0.25, 1]);
      expect(verifying, isTrue);
      expect(modelStore.installs, 1);
    });

    test('preloads the selected model and generation reuses it', () async {
      var chatEvicted = false;
      await coordinator.acquire(
        LocalAiWorkload.chat,
        onEvict: () async => chatEvicted = true,
      );

      final installed = await service.prepareModel();

      expect(installed.profile, ImageModelCatalog.sdxs);
      expect(chatEvicted, isTrue);
      expect(coordinator.state.activeWorkloads, {LocalAiWorkload.diffusion});
      expect(backend.loadPaths, <String>['/models/sdxs.gguf']);

      await service.generate(prompt: 'Already warm');

      expect(backend.loadPaths, hasLength(1));
      expect(backend.generator.requests.single.prompt, 'Already warm');
    });

    test('preload rejects a selected model that is not installed', () async {
      modelStore.installed = null;

      await expectLater(service.prepareModel(), throwsA(isA<StateError>()));

      expect(backend.loadPaths, isEmpty);
      expect(coordinator.state.activeWorkloads, isEmpty);
    });

    test(
      'evicts chat, holds diffusion lease, and persists PNG output',
      () async {
        var chatEvicted = false;
        await coordinator.acquire(
          LocalAiWorkload.chat,
          onEvict: () async => chatEvicted = true,
        );
        final progress = <LocalImageGenerationProgress>[];

        final artifact = await service.generate(
          prompt: 'A tiny red fox in the rain',
          seed: 7,
          onProgress: progress.add,
        );

        expect(chatEvicted, isTrue);
        expect(coordinator.state.activeWorkloads, {LocalAiWorkload.diffusion});
        expect(backend.loadPaths, <String>['/models/sdxs.gguf']);
        expect(backend.generator.requests.single.prompt, contains('red fox'));
        expect(backend.generator.requests.single.steps, 1);
        expect(backend.generator.requests.single.guidanceScale, 1);
        expect(progress.single.phase, LocalImageGenerationPhase.sampling);
        expect(outputStore.savedBytes.single, <int>[1, 2, 3, 4]);
        expect(artifact.path, '/generated/7.png');
        expect(artifact.seed, 7);
        expect(artifact.width, 512);
        expect(artifact.height, 512);
        expect(artifact.profile, ImageModelCatalog.sdxs);
      },
    );

    test('reuses the loaded image engine across generations', () async {
      await service.generate(prompt: 'First');
      await service.generate(prompt: 'Second');

      expect(backend.loadPaths, hasLength(1));
      expect(backend.generator.requests, hasLength(2));
    });

    test(
      'disposes the resident engine before loading a selected model',
      () async {
        await service.generate(prompt: 'First');
        selection.select(ImageModelCatalog.stableDiffusion15Q4.id);
        modelStore.installed = const InstalledImageModel(
          profile: ImageModelCatalog.stableDiffusion15Q4,
          modelPath: '/models/sd15-q4.gguf',
        );

        final artifact = await service.generate(prompt: 'Second');

        expect(backend.loadPaths, <String>[
          '/models/sdxs.gguf',
          '/models/sd15-q4.gguf',
        ]);
        expect(backend.generator.disposeCalls, 1);
        expect(backend.generator.requests.last.steps, 20);
        expect(backend.generator.requests.last.guidanceScale, 7);
        expect(artifact.profile, ImageModelCatalog.stableDiffusion15Q4);
      },
    );

    test('cancels the active native generation', () async {
      final run = _BlockingImageGenerationRun();
      backend.generator.run = run;
      final generation = service.generate(prompt: 'Never finishes');
      await backend.generator.started.future;

      service.cancelGeneration();

      await expectLater(
        generation,
        throwsA(isA<ImageGenerationCancelledException>()),
      );
      expect(run.cancelCalls, 1);
    });

    test('releases the diffusion lease when loading fails', () async {
      backend.loadError = StateError('bad model');

      await expectLater(
        service.generate(prompt: 'Will fail'),
        throwsA(isA<StateError>()),
      );

      expect(coordinator.state.activeWorkloads, isEmpty);
    });

    test('unloads before deleting the installed model', () async {
      await service.generate(prompt: 'Load the model');

      await service.removeModel();

      expect(backend.generator.disposeCalls, 1);
      expect(modelStore.deletes, 1);
      expect(coordinator.state.activeWorkloads, isEmpty);
    });
  });
}

class _FakeImageModelStore implements ImageModelStore {
  @override
  bool isSupported = true;
  int installs = 0;
  int deletes = 0;
  InstalledImageModel? installed = const InstalledImageModel(
    profile: ImageModelProfile.sdxs,
    modelPath: '/models/sdxs.gguf',
  );

  @override
  Future<void> cancelInstall(ImageModelProfile profile) async {}

  @override
  Future<void> delete(ImageModelProfile profile) async {
    deletes++;
    installed = null;
  }

  @override
  Future<InstalledImageModel> install(
    ImageModelProfile profile, {
    required void Function(double progress) onProgress,
    required void Function() onVerifying,
  }) async {
    installs++;
    onProgress(0.25);
    onVerifying();
    onProgress(1);
    return installed = InstalledImageModel(
      profile: profile,
      modelPath: '/models/sdxs.gguf',
    );
  }

  @override
  Future<InstalledImageModel?> resolve(ImageModelProfile profile) async =>
      installed?.profile.id == profile.id ? installed : null;
}

class _FakeImageGenerationBackend implements ImageGenerationBackend {
  ImageRuntimeSupport support = const ImageRuntimeSupport(isSupported: true);
  int checkRuntimeCalls = 0;
  final loadPaths = <String>[];
  Object? loadError;
  final generator = _FakeLoadedImageGenerator();

  @override
  Future<ImageRuntimeSupport> checkRuntime() async {
    checkRuntimeCalls++;
    return support;
  }

  @override
  Future<LoadedImageGenerator> load(String modelPath) async {
    loadPaths.add(modelPath);
    final error = loadError;
    if (error != null) throw error;
    return generator;
  }
}

class _FakeLoadedImageGenerator implements LoadedImageGenerator {
  final requests = <LocalImageGenerationRequest>[];
  final started = Completer<void>();
  ImageGenerationRun run = _CompletedImageGenerationRun();
  int disposeCalls = 0;

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  @override
  Future<ImageGenerationRun> generate(
    LocalImageGenerationRequest request,
  ) async {
    requests.add(request);
    if (!started.isCompleted) started.complete();
    return run;
  }
}

class _CompletedImageGenerationRun implements ImageGenerationRun {
  @override
  Stream<LocalImageGenerationProgress> get events => Stream.value(
    const LocalImageGenerationProgress(
      phase: LocalImageGenerationPhase.sampling,
      step: 1,
      steps: 1,
    ),
  );

  @override
  Future<LocalImageGenerationCompletion> get done async =>
      LocalImageGenerationCompletion.completed(
        LocalGeneratedImage(
          pngBytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
          seed: 7,
          width: 512,
          height: 512,
          elapsed: const Duration(seconds: 2),
        ),
      );

  @override
  void cancel() {}
}

class _BlockingImageGenerationRun implements ImageGenerationRun {
  final Completer<LocalImageGenerationCompletion> _done = Completer();
  int cancelCalls = 0;

  @override
  Stream<LocalImageGenerationProgress> get events => const Stream.empty();

  @override
  Future<LocalImageGenerationCompletion> get done => _done.future;

  @override
  void cancel() {
    cancelCalls++;
    if (!_done.isCompleted) {
      _done.complete(const LocalImageGenerationCompletion.cancelled());
    }
  }
}

class _FakeGeneratedImageStore implements GeneratedImageStore {
  final savedBytes = <List<int>>[];

  @override
  Future<String> savePng(Uint8List bytes, {required int seed}) async {
    savedBytes.add(bytes);
    return '/generated/$seed.png';
  }
}
