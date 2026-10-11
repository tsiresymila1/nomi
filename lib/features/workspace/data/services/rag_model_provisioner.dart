import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:gena/features/downloads/data/services/model_background_download_service.dart';
import 'package:path_provider/path_provider.dart';

typedef RagModelDirectoryProvider = Future<Directory> Function();
typedef RagModelDigestProvider = Future<String> Function(File file);
typedef RagModelDownload =
    Future<DownloadedModelFile> Function({
      required String modelKey,
      required String modelName,
      required String sourceUrl,
      void Function(double progress, String message)? onProgress,
    });

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
  RagModelProvisioner({
    RagModelDirectoryProvider? directoryProvider,
    RagModelDigestProvider? digestProvider,
    RagModelDownload? download,
  }) : _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory,
       _digestProvider = digestProvider ?? _streamingSha256,
       _download =
           download ??
           ModelBackgroundDownloadService.instance.downloadModelToFile;

  final RagModelDirectoryProvider _directoryProvider;
  final RagModelDigestProvider _digestProvider;
  final RagModelDownload _download;

  static Future<void>? _inFlight;

  /// all-MiniLM-L6-v2 (sentence-transformers) — the model the mobile_rag_engine
  /// README recommends. INT8/ARM64 quantization; the QLinear graph still runs
  /// cross-architecture under onnxruntime (slower off-target). To require x86
  /// emulators, swap [_model] to the fp32 `onnx/model.onnx` build.
  static const _model = _RagAsset(
    label: 'Workspace RAG model',
    fileName: 'model.onnx',
    url:
        'https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/onnx/model_qint8_arm64.onnx',
    sha256: '4278337fd0ff3c68bfb6291042cad8ab363e1d9fbc43dcb499fe91c871902474',
    sizeBytes: 23026053,
  );

  static const _tokenizer = _RagAsset(
    label: 'Workspace RAG tokenizer',
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
    final dir = await _directoryProvider();
    if (!await dir.exists()) await dir.create(recursive: true);
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

    onProgress?.call('Downloading ${asset.label}...');
    File? downloadedFile;

    try {
      final downloaded = await _download(
        modelKey: 'workspace-rag:${asset.fileName}',
        modelName: asset.label,
        sourceUrl: asset.url,
        onProgress: (progress, _) => onProgress?.call(
          'Downloading ${asset.label} ${(progress * 100).round()}%',
        ),
      );
      downloadedFile = File(downloaded.path);
    } catch (error) {
      throw RagModelDownloadException(
        'Failed to download ${asset.fileName}: $error',
      );
    }

    if (!await downloadedFile.exists() ||
        await downloadedFile.length() != asset.sizeBytes) {
      await _deleteIfPresent(downloadedFile);
      throw RagModelDownloadException(
        '${asset.fileName} has an unexpected download size.',
      );
    }

    onProgress?.call('Verifying ${asset.label}...');
    final digest = await _digestProvider(downloadedFile);
    if (digest != asset.sha256) {
      await _deleteIfPresent(downloadedFile);
      throw RagModelDownloadException(
        '${asset.fileName} checksum mismatch (expected ${asset.sha256}, '
        'got $digest).',
      );
    }

    if (await target.exists()) await target.delete();
    await downloadedFile.rename(target.path);
  }

  static Future<String> _streamingSha256(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  static Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }
}

class _RagAsset {
  const _RagAsset({
    required this.label,
    required this.fileName,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
  });

  final String label;
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
