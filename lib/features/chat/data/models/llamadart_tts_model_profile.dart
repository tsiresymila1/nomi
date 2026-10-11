enum LlamaDartTtsModelSourceType { managedDownload, externalFiles }

class LlamaDartTtsModelProfile {
  const LlamaDartTtsModelProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.modelUrl,
    required this.modelFileName,
    required this.modelSizeBytes,
    required this.modelSha256,
    required this.projectorUrl,
    required this.projectorFileName,
    required this.projectorSizeBytes,
    required this.projectorSha256,
    required this.minimumRamGb,
    this.sourceType = LlamaDartTtsModelSourceType.managedDownload,
    this.modelPath,
    this.projectorPath,
  });

  factory LlamaDartTtsModelProfile.external({
    required String name,
    required String modelPath,
    required int modelSizeBytes,
    required String projectorPath,
    required int projectorSizeBytes,
  }) {
    final normalizedModel = modelPath.trim().replaceAll('\\', '/');
    final normalizedProjector = projectorPath.trim().replaceAll('\\', '/');
    return LlamaDartTtsModelProfile(
      id: 'custom:${Uri.encodeComponent(normalizedModel)}',
      name: name.trim(),
      description: 'Custom Qwen3-TTS model and audio projector.',
      modelUrl: '',
      modelFileName: normalizedModel.split('/').last,
      modelSizeBytes: modelSizeBytes,
      modelSha256: '',
      projectorUrl: '',
      projectorFileName: normalizedProjector.split('/').last,
      projectorSizeBytes: projectorSizeBytes,
      projectorSha256: '',
      minimumRamGb: 6,
      sourceType: LlamaDartTtsModelSourceType.externalFiles,
      modelPath: normalizedModel,
      projectorPath: normalizedProjector,
    );
  }

  final String id;
  final String name;
  final String description;
  final String modelUrl;
  final String modelFileName;
  final int modelSizeBytes;
  final String modelSha256;
  final String projectorUrl;
  final String projectorFileName;
  final int projectorSizeBytes;
  final String projectorSha256;
  final int minimumRamGb;
  final LlamaDartTtsModelSourceType sourceType;
  final String? modelPath;
  final String? projectorPath;

  bool get isExternal =>
      sourceType == LlamaDartTtsModelSourceType.externalFiles;
  int get totalSizeBytes => modelSizeBytes + projectorSizeBytes;
  double get modelDownloadWeight => modelSizeBytes / totalSizeBytes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'description': description,
    'modelUrl': modelUrl,
    'modelFileName': modelFileName,
    'modelSizeBytes': modelSizeBytes,
    'modelSha256': modelSha256,
    'projectorUrl': projectorUrl,
    'projectorFileName': projectorFileName,
    'projectorSizeBytes': projectorSizeBytes,
    'projectorSha256': projectorSha256,
    'minimumRamGb': minimumRamGb,
    'sourceType': sourceType.name,
    'modelPath': modelPath,
    'projectorPath': projectorPath,
  };

  static LlamaDartTtsModelProfile fromJson(Object? value) {
    if (value is! Map) return qwen3Tts17bQ4;
    try {
      final json = Map<String, dynamic>.from(value);
      if (json['id'] == qwen3Tts17bQ4.id) return qwen3Tts17bQ4;
      final sourceType = LlamaDartTtsModelSourceType.values.byName(
        json['sourceType'] as String,
      );
      final modelPath = json['modelPath'] as String?;
      final projectorPath = json['projectorPath'] as String?;
      if (sourceType != LlamaDartTtsModelSourceType.externalFiles ||
          modelPath == null ||
          projectorPath == null) {
        return qwen3Tts17bQ4;
      }
      return LlamaDartTtsModelProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        modelUrl: '',
        modelFileName: json['modelFileName'] as String,
        modelSizeBytes: (json['modelSizeBytes'] as num).toInt(),
        modelSha256: '',
        projectorUrl: '',
        projectorFileName: json['projectorFileName'] as String,
        projectorSizeBytes: (json['projectorSizeBytes'] as num).toInt(),
        projectorSha256: '',
        minimumRamGb: (json['minimumRamGb'] as num?)?.toInt() ?? 6,
        sourceType: sourceType,
        modelPath: modelPath,
        projectorPath: projectorPath,
      );
    } catch (_) {
      return qwen3Tts17bQ4;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LlamaDartTtsModelProfile &&
          other.id == id &&
          other.modelPath == modelPath &&
          other.projectorPath == projectorPath;

  @override
  int get hashCode => Object.hash(id, modelPath, projectorPath);
}

class InstalledLlamaDartTtsModel {
  const InstalledLlamaDartTtsModel({
    required this.profile,
    required this.modelPath,
    required this.projectorPath,
  });

  final LlamaDartTtsModelProfile profile;
  final String modelPath;
  final String projectorPath;
}

const qwen3Tts17bQ4 = LlamaDartTtsModelProfile(
  id: 'qwen3-tts-1.7b-base-q4-k-m',
  name: 'Qwen3-TTS 1.7B Q4_K_M',
  description:
      'Local neural voice through LlamaDart · multilingual including French',
  modelUrl:
      'https://huggingface.co/ggml-org/Qwen3-TTS-12Hz-1.7B-Base-GGUF/resolve/ca27d74bc954b73dadab5b71ca265d87fc861a7c/Qwen3-TTS-12Hz-1.7B-Base-Q4_K_M.gguf?download=true',
  modelFileName: 'Qwen3-TTS-12Hz-1.7B-Base-Q4_K_M.gguf',
  modelSizeBytes: 1035965280,
  modelSha256:
      '8d18c94acb2addd042f97da63c98be144eafa76d0d9495177eab65130cf85129',
  projectorUrl:
      'https://huggingface.co/ggml-org/Qwen3-TTS-12Hz-1.7B-Base-GGUF/resolve/ca27d74bc954b73dadab5b71ca265d87fc861a7c/mmproj-Qwen3-TTS-12Hz-1.7B-Base-Q8_0.gguf?download=true',
  projectorFileName: 'mmproj-Qwen3-TTS-12Hz-1.7B-Base-Q8_0.gguf',
  projectorSizeBytes: 446422912,
  projectorSha256:
      '6fd65188839bcd6ecc91b277ad471e22a0edfada4699a0fe82f1165c18cfcce2',
  minimumRamGb: 6,
);

const llamaDartTtsModels = <LlamaDartTtsModelProfile>[qwen3Tts17bQ4];
