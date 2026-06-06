import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:gena/features/downloads/data/default_embedder_models.dart';

typedef InstallStatusCallback =
    void Function({
      required String message,
      int? modelProgress,
      int? tokenizerProgress,
    });

class WorkspaceEmbedderInstaller {
  Future<void> ensureInstalled({
    required InstallStatusCallback onStatus,
    String modelKey = 'embeddinggemma_300m',
  }) async {
    onStatus(message: 'Checking embedding model...');

    final selectedModel = findDefaultEmbedderModel(modelKey);
    if (selectedModel == null) {
      throw FormatException('Unknown embedder model: $modelKey');
    }

    if (FlutterGemma.hasActiveEmbedder()) {
      await FlutterGemma.getActiveEmbedder();
      onStatus(
        message: 'Embedding model is ready',
        modelProgress: 100,
        tokenizerProgress: 100,
      );
      return;
    }

    final token = dotenv.env['HUGGING_FACE_TOKEN']?.trim() ?? '';
    if (token.isEmpty) {
      throw const FormatException(
        'Missing HUGGING_FACE_TOKEN in .env. Add it and restart the app.',
      );
    }

    onStatus(message: 'Installing embedding model...');
    await FlutterGemma.installEmbedder()
        .modelFromNetwork(selectedModel.modelUrl, token: token)
        .tokenizerFromNetwork(selectedModel.tokenizerUrl, token: token)
        .withModelProgress(
          (progress) => onStatus(
            message: 'Downloading embedder model...',
            modelProgress: progress,
          ),
        )
        .withTokenizerProgress(
          (progress) => onStatus(
            message: 'Downloading tokenizer...',
            tokenizerProgress: progress,
          ),
        )
        .install();

    await FlutterGemma.getActiveEmbedder();
    onStatus(
      message: 'Embedding model is ready',
      modelProgress: 100,
      tokenizerProgress: 100,
    );
  }
}
