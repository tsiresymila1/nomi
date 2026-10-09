import 'dart:typed_data';

enum ImageModelSourceType { managedDownload, externalFile }

enum ImageModelDeviceTier { recommended4Gb, experimental, custom }

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
    this.sourceType = ImageModelSourceType.managedDownload,
    this.deviceTier = ImageModelDeviceTier.recommended4Gb,
    this.filePath,
  });

  factory ImageModelProfile.external({
    required String id,
    required String name,
    required String filePath,
    required int sizeBytes,
    int steps = 20,
    double guidanceScale = 7,
  }) {
    final normalizedPath = filePath.trim();
    return ImageModelProfile(
      id: id,
      name: name,
      description: 'Custom local GGUF image model.',
      url: '',
      fileName: normalizedPath.split(RegExp(r'[/\\]')).last,
      sizeBytes: sizeBytes,
      sha256: '',
      steps: steps,
      guidanceScale: guidanceScale,
      sourceType: ImageModelSourceType.externalFile,
      deviceTier: ImageModelDeviceTier.custom,
      filePath: normalizedPath,
    );
  }

  factory ImageModelProfile.fromJson(Map<String, dynamic> json) {
    return ImageModelProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      url: json['url'] as String? ?? '',
      fileName: json['fileName'] as String,
      sizeBytes: (json['sizeBytes'] as num).toInt(),
      sha256: json['sha256'] as String? ?? '',
      steps: (json['steps'] as num).toInt(),
      guidanceScale: (json['guidanceScale'] as num).toDouble(),
      sourceType: ImageModelSourceType.values.byName(
        json['sourceType'] as String? ??
            ImageModelSourceType.managedDownload.name,
      ),
      deviceTier: ImageModelDeviceTier.values.byName(
        json['deviceTier'] as String? ?? ImageModelDeviceTier.custom.name,
      ),
      filePath: json['filePath'] as String?,
    );
  }

  final String id;
  final String name;
  final String description;
  final String url;
  final String fileName;
  final int sizeBytes;
  final String sha256;
  final int steps;
  final double guidanceScale;
  final ImageModelSourceType sourceType;
  final ImageModelDeviceTier deviceTier;
  final String? filePath;

  bool get isExternal => sourceType == ImageModelSourceType.externalFile;

  String get displaySize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    const kib = 1024;
    const mib = kib * 1024;
    const gib = mib * 1024;
    if (sizeBytes < mib) return '${(sizeBytes / kib).toStringAsFixed(1)} KB';
    if (sizeBytes < gib) return '${(sizeBytes / mib).round()} MB';
    return '${(sizeBytes / gib).toStringAsFixed(1)} GB';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'description': description,
    'url': url,
    'fileName': fileName,
    'sizeBytes': sizeBytes,
    'sha256': sha256,
    'steps': steps,
    'guidanceScale': guidanceScale,
    'sourceType': sourceType.name,
    'deviceTier': deviceTier.name,
    'filePath': filePath,
  };

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
    required this.profile,
  });

  final String path;
  final int seed;
  final int width;
  final int height;
  final Duration elapsed;
  final ImageModelProfile profile;
}

class ImageGenerationCancelledException implements Exception {
  const ImageGenerationCancelledException();

  @override
  String toString() => 'Image generation was cancelled.';
}
