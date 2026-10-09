import 'dart:async';
import 'dart:typed_data';

import 'package:gena/core/local_ai/local_ai_runtime_coordinator.dart';
import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/data/services/image_generation_backend.dart';
import 'package:gena/features/image_generation/data/services/image_model_store.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_model_selection_cubit.dart';

abstract interface class GeneratedImageStore {
  Future<String> savePng(Uint8List bytes, {required int seed});
}

abstract interface class ImageGenerationServiceApi {
  Future<ImageRuntimeSupport> checkSupport();

  Future<InstalledImageModel?> resolveModel();

  Future<InstalledImageModel> prepareModel();

  Future<InstalledImageModel> installModel({
    required void Function(double progress) onProgress,
    required void Function() onVerifying,
  });

  Future<void> cancelInstall();

  Future<GeneratedImageArtifact> generate({
    required String prompt,
    String negativePrompt = '',
    int width = 512,
    int height = 512,
    int? seed,
    void Function(LocalImageGenerationProgress progress)? onProgress,
  });

  void cancelGeneration();

  Future<void> removeModel();

  Future<void> releaseEngine();
}

/// Owns the resident diffusion engine and its shared heavyweight-runtime lease.
class LocalImageGenerationService implements ImageGenerationServiceApi {
  LocalImageGenerationService({
    required LocalAiRuntimeCoordinator coordinator,
    required ImageModelStore modelStore,
    required ImageGenerationBackend backend,
    required GeneratedImageStore outputStore,
    required ImageModelSelectionCubit selection,
  }) : _coordinator = coordinator,
       _modelStore = modelStore,
       _backend = backend,
       _outputStore = outputStore,
       _selection = selection;

  final LocalAiRuntimeCoordinator _coordinator;
  final ImageModelStore _modelStore;
  final ImageGenerationBackend _backend;
  final GeneratedImageStore _outputStore;
  final ImageModelSelectionCubit _selection;

  LocalAiRuntimeLease? _lease;
  LoadedImageGenerator? _generator;
  ImageGenerationRun? _activeRun;
  Future<LocalImageGenerationCompletion>? _activeCompletion;
  Future<void> _operationTail = Future<void>.value();
  bool _cancelRequested = false;
  String? _loadedProfileId;

  @override
  Future<ImageRuntimeSupport> checkSupport() async {
    if (!_modelStore.isSupported) {
      return const ImageRuntimeSupport(
        isSupported: false,
        unsupportedReason: 'Image model storage is unavailable.',
      );
    }
    return _backend.checkRuntime();
  }

  @override
  Future<InstalledImageModel?> resolveModel() =>
      _modelStore.resolve(_selection.state.selectedProfile);

  @override
  Future<InstalledImageModel> installModel({
    required void Function(double progress) onProgress,
    required void Function() onVerifying,
  }) {
    final profile = _selection.state.selectedProfile;
    return _modelStore.install(
      profile,
      onProgress: onProgress,
      onVerifying: onVerifying,
    );
  }

  @override
  Future<void> cancelInstall() =>
      _modelStore.cancelInstall(_selection.state.selectedProfile);

  @override
  Future<InstalledImageModel> prepareModel() {
    return _serialize(() async {
      final profile = _selection.state.selectedProfile;
      final installed = await _modelStore.resolve(profile);
      if (installed == null) {
        throw StateError('${profile.name} is not installed.');
      }
      await _ensureGenerator(installed);
      return installed;
    });
  }

  @override
  Future<GeneratedImageArtifact> generate({
    required String prompt,
    String negativePrompt = '',
    int width = 512,
    int height = 512,
    int? seed,
    void Function(LocalImageGenerationProgress progress)? onProgress,
  }) {
    return _serialize(() async {
      final profile = _selection.state.selectedProfile;
      _cancelRequested = false;
      final normalizedPrompt = prompt.trim();
      if (normalizedPrompt.isEmpty) {
        throw ArgumentError.value(prompt, 'prompt', 'must not be empty');
      }

      final installed = await _modelStore.resolve(profile);
      if (installed == null) {
        throw StateError('${profile.name} is not installed.');
      }

      final generator = await _ensureGenerator(installed);
      final run = await generator.generate(
        LocalImageGenerationRequest(
          prompt: normalizedPrompt,
          negativePrompt: negativePrompt.trim(),
          width: width,
          height: height,
          steps: profile.steps,
          guidanceScale: profile.guidanceScale,
          seed: seed,
        ),
      );
      _activeRun = run;
      if (_cancelRequested) run.cancel();
      final subscription = onProgress == null
          ? null
          : run.events.listen(onProgress);
      final completion = run.done;
      _activeCompletion = completion;
      try {
        final outcome = await completion;
        return switch (outcome.state) {
          LocalImageGenerationCompletionState.completed => _persist(
            outcome.image!,
            profile,
          ),
          LocalImageGenerationCompletionState.cancelled =>
            throw const ImageGenerationCancelledException(),
          LocalImageGenerationCompletionState.failed =>
            throw outcome.error ?? StateError('Image generation failed.'),
        };
      } finally {
        await subscription?.cancel();
        if (identical(_activeRun, run)) _activeRun = null;
        if (identical(_activeCompletion, completion)) _activeCompletion = null;
        _cancelRequested = false;
      }
    });
  }

  Future<GeneratedImageArtifact> _persist(
    LocalGeneratedImage image,
    ImageModelProfile profile,
  ) async {
    final path = await _outputStore.savePng(image.pngBytes, seed: image.seed);
    return GeneratedImageArtifact(
      path: path,
      seed: image.seed,
      width: image.width,
      height: image.height,
      elapsed: image.elapsed,
      profile: profile,
    );
  }

  @override
  void cancelGeneration() {
    _cancelRequested = true;
    _activeRun?.cancel();
  }

  @override
  Future<void> removeModel() async {
    final profile = _selection.state.selectedProfile;
    await releaseEngine();
    await _modelStore.delete(profile);
  }

  Future<LoadedImageGenerator> _ensureGenerator(
    InstalledImageModel installed,
  ) async {
    final resident = _generator;
    final lease = _lease;
    if (resident != null &&
        lease != null &&
        lease.isActive &&
        _loadedProfileId == installed.profile.id) {
      return resident;
    }
    if (resident != null || lease != null) await releaseEngine();

    LocalAiRuntimeLease? acquired;
    try {
      acquired = await _coordinator.acquire(
        LocalAiWorkload.diffusion,
        onEvict: _evict,
      );
      _lease = acquired;
      final generator = await _backend.load(installed.modelPath);
      _generator = generator;
      _loadedProfileId = installed.profile.id;
      return generator;
    } catch (_) {
      if (identical(_lease, acquired)) _lease = null;
      await acquired?.release();
      rethrow;
    }
  }

  Future<void> _evict() async {
    final run = _activeRun;
    final completion = _activeCompletion;
    run?.cancel();
    if (completion != null) {
      try {
        await completion;
      } catch (_) {
        // A failed run still has to release its native engine.
      }
    }
    final generator = _generator;
    _generator = null;
    _lease = null;
    _loadedProfileId = null;
    await generator?.dispose();
  }

  @override
  Future<void> releaseEngine() async {
    final lease = _lease;
    await _evict();
    await lease?.release();
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operationTail.then<T>((_) => operation());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }
}
