class WhisperModelProfile {
  const WhisperModelProfile({
    required this.id,
    required this.label,
    required this.fileName,
    required this.approximateSizeMb,
    this.filePath,
  });

  factory WhisperModelProfile.external({
    required String name,
    required String filePath,
    required int sizeBytes,
  }) {
    final normalizedPath = filePath.trim().replaceAll('\\', '/');
    return WhisperModelProfile(
      id: 'custom:${Uri.encodeComponent(normalizedPath)}',
      label: name.trim(),
      fileName: normalizedPath.split('/').last,
      approximateSizeMb: (sizeBytes / (1024 * 1024)).ceil(),
      filePath: normalizedPath,
    );
  }

  static const tiny = WhisperModelProfile(
    id: 'tiny',
    label: 'Tiny',
    fileName: 'ggml-tiny.bin',
    approximateSizeMb: 75,
  );

  static const base = WhisperModelProfile(
    id: 'base',
    label: 'Base',
    fileName: 'ggml-base.bin',
    approximateSizeMb: 142,
  );

  static const builtIn = <WhisperModelProfile>[tiny, base];

  final String id;
  final String label;
  final String fileName;
  final int approximateSizeMb;
  final String? filePath;

  bool get isExternal => filePath != null;
  bool get isMultilingual => true;

  Uri get downloadUri {
    if (isExternal) {
      throw StateError('External Whisper models are not downloadable.');
    }
    return Uri.parse(
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$fileName',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'fileName': fileName,
    'approximateSizeMb': approximateSizeMb,
    'filePath': filePath,
  };

  static WhisperModelProfile parse(Object? value) {
    if (value is Map) {
      try {
        final json = Map<String, dynamic>.from(value);
        final id = json['id'] as String?;
        for (final profile in builtIn) {
          if (profile.id == id) return profile;
        }
        final filePath = json['filePath'] as String?;
        if (id != null &&
            filePath != null &&
            filePath.trim().isNotEmpty &&
            filePath.toLowerCase().endsWith('.bin')) {
          return WhisperModelProfile(
            id: id,
            label: json['label'] as String? ?? 'Custom Whisper',
            fileName: json['fileName'] as String? ?? filePath.split('/').last,
            approximateSizeMb:
                (json['approximateSizeMb'] as num?)?.toInt() ?? 0,
            filePath: filePath,
          );
        }
      } catch (_) {
        return tiny;
      }
    }
    final normalized = value?.toString().trim().toLowerCase();
    for (final profile in builtIn) {
      if (profile.id == normalized) return profile;
    }
    return tiny;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhisperModelProfile &&
          other.id == id &&
          other.filePath == filePath;

  @override
  int get hashCode => Object.hash(id, filePath);
}
