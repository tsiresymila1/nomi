import 'package:flutter/foundation.dart';
import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/data/services/image_generation_backend.dart';
import 'package:llamadart/llamadart.dart' as llama;

class LlamadartImageGenerationBackend implements ImageGenerationBackend {
  const LlamadartImageGenerationBackend();

  @override
  Future<ImageRuntimeSupport> checkRuntime() async {
    final capabilities = await llama.ImageGenerationEngine.checkRuntime();
    return ImageRuntimeSupport(
      isSupported: capabilities.isSupported,
      unsupportedReason: capabilities.unsupportedReason,
      backendName: capabilities.backendName,
    );
  }

  @override
  Future<LoadedImageGenerator> load(String modelPath) async {
    final engine = await llama.ImageGenerationEngine.load(
      llama.ImageGenerationModel(llama.ModelSource.path(modelPath)),
      params: const llama.ImageModelParams(checkMemory: true),
    );
    return _LlamadartLoadedImageGenerator(engine);
  }
}

class _LlamadartLoadedImageGenerator implements LoadedImageGenerator {
  const _LlamadartLoadedImageGenerator(this._engine);

  final llama.ImageGenerationEngine _engine;

  @override
  Future<void> dispose() => _engine.dispose();

  @override
  Future<ImageGenerationRun> generate(
    LocalImageGenerationRequest request,
  ) async {
    final task = await _engine.generate(
      llama.ImageGenerationRequest(
        prompt: request.prompt,
        negativePrompt: request.negativePrompt,
        width: request.width,
        height: request.height,
        steps: request.steps,
        guidanceScale: request.guidanceScale,
        seed: request.seed,
      ),
    );
    return _LlamadartImageGenerationRun(task);
  }
}

class _LlamadartImageGenerationRun implements ImageGenerationRun {
  const _LlamadartImageGenerationRun(this._task);

  final llama.ImageGenerationTask _task;

  @override
  void cancel() => _task.cancel();

  @override
  Stream<LocalImageGenerationProgress> get events async* {
    await for (final event in _task.events) {
      if (event is! llama.ImageGenerationProgressEvent) continue;
      yield LocalImageGenerationProgress(
        phase: switch (event.phase) {
          llama.ImageGenerationPhase.loading =>
            LocalImageGenerationPhase.loading,
          llama.ImageGenerationPhase.encodingPrompt =>
            LocalImageGenerationPhase.encodingPrompt,
          llama.ImageGenerationPhase.sampling =>
            LocalImageGenerationPhase.sampling,
          llama.ImageGenerationPhase.decoding =>
            LocalImageGenerationPhase.decoding,
        },
        step: event.step,
        steps: event.steps,
        imageIndex: event.imageIndex,
        imageCount: event.imageCount,
      );
    }
  }

  @override
  Future<LocalImageGenerationCompletion> get done async {
    final completion = await _task.done;
    switch (completion.state) {
      case llama.ImageGenerationCompletionState.completed:
        final result = completion.result!;
        final image = result.images.first;
        final png = await compute(_encodePng, image);
        return LocalImageGenerationCompletion.completed(
          LocalGeneratedImage(
            pngBytes: png,
            seed: result.seed,
            width: image.width,
            height: image.height,
            elapsed: result.elapsed,
          ),
        );
      case llama.ImageGenerationCompletionState.cancelled:
        return const LocalImageGenerationCompletion.cancelled();
      case llama.ImageGenerationCompletionState.failed:
        return LocalImageGenerationCompletion.failed(completion.error!);
    }
  }
}

Uint8List _encodePng(llama.GeneratedImage image) => image.toPng();
