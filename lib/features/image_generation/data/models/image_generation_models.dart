import 'dart:typed_data';

/// A pinned, downloadable image-generation model.
class ImageModelProfile {
  const ImageModelProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
    required this.steps,
    required this.guidanceScale,
  });

  final String id;
  final String name;
  final String description;
  final String url;
  final String fileName;
  final int sizeBytes;
  final String sha256;
  final int steps;
  final double guidanceScale;

  static const sdxs = ImageModelProfile(
    id: 'sdxs-512-q8_0',
    name: 'SDXS-512',
    description: 'Fast one-step local image model for Android phones.',
    url:
        'https://huggingface.co/concedo/sdxs-512-tinySDdistilled-GGUF/resolve/3144d898d61492f8382ffcabec055733fc5b2a0e/sdxs-512-tinySDdistilled_Q8_0.gguf?download=true',
    fileName: 'sdxs-512-tinySDdistilled_Q8_0.gguf',
    sizeBytes: 682847200,
    sha256: '409ab23582ee074c6b9d5395784fc0741b0599fb9d138686c69087c71678eb6a',
    steps: 1,
    guidanceScale: 1,
  );
}

class InstalledImageModel {
  const InstalledImageModel({required this.profile, required this.modelPath});

  final ImageModelProfile profile;
  final String modelPath;
}

class ImageRuntimeSupport {
  const ImageRuntimeSupport({
    required this.isSupported,
    this.unsupportedReason,
    this.backendName,
  });

  final bool isSupported;
  final String? unsupportedReason;
  final String? backendName;
}

enum LocalImageGenerationPhase { loading, encodingPrompt, sampling, decoding }

class LocalImageGenerationProgress {
  const LocalImageGenerationProgress({
    required this.phase,
    required this.step,
    required this.steps,
    this.imageIndex = 0,
    this.imageCount = 1,
  });

  final LocalImageGenerationPhase phase;
  final int step;
  final int steps;
  final int imageIndex;
  final int imageCount;

  double get fraction => steps <= 0 ? 0 : (step / steps).clamp(0, 1);
}

class LocalImageGenerationRequest {
  const LocalImageGenerationRequest({
    required this.prompt,
    this.negativePrompt = '',
    this.width = 512,
    this.height = 512,
    required this.steps,
    required this.guidanceScale,
    this.seed,
  });

  final String prompt;
  final String negativePrompt;
  final int width;
  final int height;
  final int steps;
  final double guidanceScale;
  final int? seed;
}

class LocalGeneratedImage {
  const LocalGeneratedImage({
    required this.pngBytes,
    required this.seed,
    required this.width,
    required this.height,
    required this.elapsed,
  });

  final Uint8List pngBytes;
  final int seed;
  final int width;
  final int height;
  final Duration elapsed;
}

enum LocalImageGenerationCompletionState { completed, cancelled, failed }

class LocalImageGenerationCompletion {
  const LocalImageGenerationCompletion._({
    required this.state,
    this.image,
    this.error,
  });

  factory LocalImageGenerationCompletion.completed(LocalGeneratedImage image) =>
      LocalImageGenerationCompletion._(
        state: LocalImageGenerationCompletionState.completed,
        image: image,
      );

  const factory LocalImageGenerationCompletion.cancelled() =
      _CancelledImageGenerationCompletion;

  factory LocalImageGenerationCompletion.failed(Object error) =>
      LocalImageGenerationCompletion._(
        state: LocalImageGenerationCompletionState.failed,
        error: error,
      );

  final LocalImageGenerationCompletionState state;
  final LocalGeneratedImage? image;
  final Object? error;
}

class _CancelledImageGenerationCompletion
    extends LocalImageGenerationCompletion {
  const _CancelledImageGenerationCompletion()
    : super._(state: LocalImageGenerationCompletionState.cancelled);
}

class GeneratedImageArtifact {
  const GeneratedImageArtifact({
    required this.path,
    required this.seed,
    required this.width,
    required this.height,
    required this.elapsed,
  });

  final String path;
  final int seed;
  final int width;
  final int height;
  final Duration elapsed;
}

class ImageGenerationCancelledException implements Exception {
  const ImageGenerationCancelledException();

  @override
  String toString() => 'Image generation was cancelled.';
}
