import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads the workspace-RAG embedding model + tokenizer on first use.
///
/// `mobile_rag_engine` reads its model/tokenizer from
/// `getApplicationDocumentsDirectory()/<basename>` and only copies the bundled
/// Flutter asset when that file is missing (see `RagEngine.initialize` /
/// `_copyAssetToFile` in mobile_rag_engine 0.18.6). By pre-placing verified
/// downloads at exactly those paths, the engine reuses them and we avoid
/// shipping a ~23MB asset in the app bundle and git repo.
///
/// The downloaded filenames MUST match the basenames passed as `modelAsset` /
/// `tokenizerAsset` to `MobileRag.initialize` (`model.onnx`, `tokenizer.json`).
class RagModelProvisioner {
  RagModelProvisioner({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static Future<void>? _inFlight;

  /// all-MiniLM-L6-v2 (sentence-transformers) — the model the mobile_rag_engine
  /// README recommends. INT8/ARM64 quantization; the QLinear graph still runs
  /// cross-architecture under onnxruntime (slower off-target). To require x86
  /// emulators, swap [_model] to the fp32 `onnx/model.onnx` build.
  static const _model = _RagAsset(
    fileName: 'model.onnx',
    url:
        'https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/onnx/model_qint8_arm64.onnx',
    sha256: '4278337fd0ff3c68bfb6291042cad8ab363e1d9fbc43dcb499fe91c871902474',
    sizeBytes: 23026053,
  );

  static const _tokenizer = _RagAsset(
    fileName: 'tokenizer.json',
    url:
        'https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/tokenizer.json',
    sha256: 'be50c3628f2bf5bb5e3a7f17b1f74611b2561a3a27eeab05e5aa30f411572037',
    sizeBytes: 466247,
  );

  /// Ensures both model files exist (and pass size check) on disk, downloading
  /// any that are missing. Concurrent calls share one in-flight future.
  Future<void> ensure({void Function(String status)? onProgress}) {
    return _inFlight ??= _ensure(onProgress: onProgress).whenComplete(() {
      _inFlight = null;
    });
  }

  Future<void> _ensure({void Function(String status)? onProgress}) async {
    final dir = await getApplicationDocumentsDirectory();
    await _ensureAsset(dir, _tokenizer, onProgress: onProgress);
    await _ensureAsset(dir, _model, onProgress: onProgress);
  }

  Future<void> _ensureAsset(
    Directory dir,
    _RagAsset asset, {
    void Function(String status)? onProgress,
  }) async {
    final target = File('${dir.path}/${asset.fileName}');
    if (await target.exists() && await target.length() == asset.sizeBytes) {
      return;
    }

    onProgress?.call('Downloading ${asset.fileName}...');
    final temp = File('${target.path}.download');
    if (await temp.exists()) await temp.delete();

    try {
      await _dio.download(
        asset.url,
        temp.path,
        options: Options(followRedirects: true, receiveTimeout: null),
      );
    } catch (error) {
      if (await temp.exists()) await temp.delete();
      throw RagModelDownloadException(
        'Failed to download ${asset.fileName}: $error',
      );
    }

    final digest = sha256.convert(await temp.readAsBytes()).toString();
    if (digest != asset.sha256) {
      await temp.delete();
      throw RagModelDownloadException(
        '${asset.fileName} checksum mismatch (expected ${asset.sha256}, '
        'got $digest).',
      );
    }

    if (await target.exists()) await target.delete();
    await temp.rename(target.path);
  }
}

class _RagAsset {
  const _RagAsset({
    required this.fileName,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
  });

  final String fileName;
  final String url;
  final String sha256;
  final int sizeBytes;
}

/// Raised when the RAG model assets cannot be provisioned.
class RagModelDownloadException implements Exception {
  const RagModelDownloadException(this.message);

  final String message;

  @override
  String toString() => 'RagModelDownloadException: $message';
}
