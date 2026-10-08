import 'package:gena/features/image_generation/data/models/image_generation_models.dart';

abstract interface class ImageGenerationBackend {
  Future<ImageRuntimeSupport> checkRuntime();

  Future<LoadedImageGenerator> load(String modelPath);
}

abstract interface class LoadedImageGenerator {
  Future<ImageGenerationRun> generate(LocalImageGenerationRequest request);

  Future<void> dispose();
}

abstract interface class ImageGenerationRun {
  Stream<LocalImageGenerationProgress> get events;

  Future<LocalImageGenerationCompletion> get done;

  void cancel();
}
