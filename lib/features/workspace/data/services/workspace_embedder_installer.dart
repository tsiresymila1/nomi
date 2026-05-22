import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:gena/core/logger.dart';

typedef InstallStatusCallback =
    void Function({
      required String message,
      int? modelProgress,
      int? tokenizerProgress,
    });

class WorkspaceEmbedderInstaller {
  static const _modelUrl =
      'https://huggingface.co/yyiimmiiyy/embeddinggemma-300m-mirror/resolve/main/embeddinggemma-300M_seq256_mixed-precision.tflite';
  static const _tokenizerUrl =
      'https://huggingface.co/yyiimmiiyy/embeddinggemma-300m-mirror/resolve/main/sentencepiece.model';

  Future<void> ensureInstalled({
    required InstallStatusCallback onStatus,
  }) async {
    onStatus(message: 'Checking embedding model...');

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
    logger.i(token);
    if (token.isEmpty) {
      throw const FormatException(
        'Missing HUGGING_FACE_TOKEN in .env. Add it and restart the app.',
      );
    }

    onStatus(message: 'Installing embedding model...');
    await FlutterGemma.installEmbedder()
        .modelFromNetwork(_modelUrl, token: token)
        .tokenizerFromNetwork(_tokenizerUrl, token: token)
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
