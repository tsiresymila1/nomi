enum WhisperModelProfile {
  tiny(
    id: 'tiny',
    label: 'Tiny',
    fileName: 'ggml-tiny.bin',
    approximateSizeMb: 75,
  ),
  base(
    id: 'base',
    label: 'Base',
    fileName: 'ggml-base.bin',
    approximateSizeMb: 142,
  );

  const WhisperModelProfile({
    required this.id,
    required this.label,
    required this.fileName,
    required this.approximateSizeMb,
  });

  final String id;
  final String label;
  final String fileName;
  final int approximateSizeMb;

  bool get isMultilingual => true;

  Uri get downloadUri => Uri.parse(
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$fileName',
  );

  static WhisperModelProfile parse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return WhisperModelProfile.values.firstWhere(
      (profile) => profile.id == normalized,
      orElse: () => WhisperModelProfile.tiny,
    );
  }
}
