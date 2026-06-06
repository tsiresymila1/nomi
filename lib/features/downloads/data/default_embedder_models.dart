class DefaultEmbedderModel {
  const DefaultEmbedderModel({
    required this.key,
    required this.displayName,
    required this.description,
    required this.modelUrl,
    required this.tokenizerUrl,
    required this.sizeLabel,
    required this.sizeBytes,
    required this.recommendedRamBytes,
  });

  final String key;
  final String displayName;
  final String description;
  final String modelUrl;
  final String tokenizerUrl;
  final String sizeLabel;
  final int sizeBytes;
  final int recommendedRamBytes;
}

const List<DefaultEmbedderModel>
kDefaultEmbedderModels = <DefaultEmbedderModel>[
  DefaultEmbedderModel(
    key: 'embeddinggemma_300m',
    displayName: 'EmbeddingGemma 300M',
    description: 'On-device embedding model used for workspace RAG search.',
    modelUrl:
        'https://huggingface.co/yyiimmiiyy/embeddinggemma-300m-mirror/resolve/main/embeddinggemma-300M_seq256_mixed-precision.tflite',
    tokenizerUrl:
        'https://huggingface.co/yyiimmiiyy/embeddinggemma-300m-mirror/resolve/main/sentencepiece.model',
    sizeLabel: '313MB',
    sizeBytes: 313 * 1024 * 1024,
    recommendedRamBytes: 2 * 1024 * 1024 * 1024,
  ),
];

DefaultEmbedderModel? findDefaultEmbedderModel(String key) {
  for (final model in kDefaultEmbedderModels) {
    if (model.key == key) return model;
  }
  return null;
}
