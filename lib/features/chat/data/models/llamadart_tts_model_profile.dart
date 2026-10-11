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
  });

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

  int get totalSizeBytes => modelSizeBytes + projectorSizeBytes;
  double get modelDownloadWeight => modelSizeBytes / totalSizeBytes;
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
