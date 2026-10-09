import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:gena/features/downloads/data/services/model_background_download_service.dart';
import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/data/services/image_model_store.dart';
import 'package:path_provider/path_provider.dart';

typedef ImageModelDirectoryProvider = Future<Directory> Function();
typedef ImageModelDigestProvider = Future<String> Function(File file);

ImageModelStore createPlatformImageModelStore() => IoImageModelStore();

class BackgroundImageModelDownloadClient implements ImageModelDownloadClient {
  const BackgroundImageModelDownloadClient();

  String _key(ImageModelProfile profile) => 'image-generation:${profile.id}';

  @override
  Future<void> cancel(ImageModelProfile profile) async {
    await ModelBackgroundDownloadService.instance.cancelDownload(_key(profile));
  }

  @override
  Future<DownloadedImageModelFile> download(
    ImageModelProfile profile, {
    required void Function(double progress) onProgress,
  }) async {
    final downloaded = await ModelBackgroundDownloadService.instance
        .downloadModelToFile(
          modelKey: _key(profile),
          modelName: profile.name,
          sourceUrl: profile.url,
          onProgress: (progress, _) => onProgress(progress),
        );
    return DownloadedImageModelFile(
      path: downloaded.path,
      sizeBytes: downloaded.sizeBytes,
    );
  }
}

class IoImageModelStore implements ImageModelStore {
  IoImageModelStore({
    ImageModelDownloadClient? downloadClient,
    ImageModelDirectoryProvider? modelsDirectoryProvider,
    ImageModelDigestProvider? digestProvider,
  }) : _downloadClient =
           downloadClient ?? const BackgroundImageModelDownloadClient(),
       _modelsDirectoryProvider =
           modelsDirectoryProvider ?? _defaultModelsDirectory,
       _digestProvider = digestProvider ?? _streamingSha256;

  final ImageModelDownloadClient _downloadClient;
  final ImageModelDirectoryProvider _modelsDirectoryProvider;
  final ImageModelDigestProvider _digestProvider;

  @override
  bool get isSupported => true;

  @override
  Future<InstalledImageModel?> resolve(ImageModelProfile profile) async {
    if (profile.isExternal) return _resolveExternal(profile);
    final directory = await _modelsDirectoryProvider();
    final model = File('${directory.path}/${profile.fileName}');
    if (!await model.exists() || await model.length() != profile.sizeBytes) {
      return null;
    }

    final marker = File('${model.path}.sha256');
    final trusted =
        await marker.exists() &&
        (await marker.readAsString()).trim().toLowerCase() ==
            profile.sha256.toLowerCase();
    if (!trusted) {
      final digest = await _digestProvider(model);
      if (digest.toLowerCase() != profile.sha256.toLowerCase()) return null;
      await marker.writeAsString(profile.sha256, flush: true);
    }
    return InstalledImageModel(profile: profile, modelPath: model.path);
  }

  @override
  Future<InstalledImageModel> install(
    ImageModelProfile profile, {
    required void Function(double progress) onProgress,
    required void Function() onVerifying,
  }) async {
    if (profile.isExternal) {
      throw StateError(
        '${profile.name} is an external model and cannot be downloaded.',
      );
    }
    final existing = await resolve(profile);
    if (existing != null) {
      onProgress(1);
      return existing;
    }

    final downloaded = await _downloadClient.download(
      profile,
      onProgress: onProgress,
    );
    final file = File(downloaded.path);
    if (!await file.exists() || await file.length() != profile.sizeBytes) {
      await _deleteIfPresent(file);
      throw ImageModelIntegrityException(
        '${profile.name} has an unexpected download size.',
      );
    }

    onVerifying();
    final digest = await _digestProvider(file);
    if (digest.toLowerCase() != profile.sha256.toLowerCase()) {
      await _deleteIfPresent(file);
      await _deleteIfPresent(File('${file.path}.sha256'));
      throw ImageModelIntegrityException(
        '${profile.name} checksum verification failed.',
      );
    }
    await File(
      '${file.path}.sha256',
    ).writeAsString(profile.sha256, flush: true);
    onProgress(1);
    return InstalledImageModel(profile: profile, modelPath: file.path);
  }

  @override
  Future<void> cancelInstall(ImageModelProfile profile) async {
    if (profile.isExternal) return;
    await _downloadClient.cancel(profile);
  }

  @override
  Future<void> delete(ImageModelProfile profile) async {
    if (profile.isExternal) return;
    await cancelInstall(profile);
    final directory = await _modelsDirectoryProvider();
    final model = File('${directory.path}/${profile.fileName}');
    await _deleteIfPresent(model);
    await _deleteIfPresent(File('${model.path}.sha256'));
  }

  static Future<Directory> _defaultModelsDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/models');
    await directory.create(recursive: true);
    return directory;
  }

  static Future<String> _streamingSha256(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  Future<InstalledImageModel?> _resolveExternal(
    ImageModelProfile profile,
  ) async {
    final path = profile.filePath;
    if (path == null || !path.toLowerCase().endsWith('.gguf')) return null;
    final model = File(path);
    try {
      if (!await model.exists()) return null;
      final length = await model.length();
      if (length <= 0 || length != profile.sizeBytes) return null;
      await model.openRead(0, 1).drain<void>();
      if (profile.sha256.isNotEmpty) {
        final digest = await _digestProvider(model);
        if (digest.toLowerCase() != profile.sha256.toLowerCase()) return null;
      }
      return InstalledImageModel(profile: profile, modelPath: path);
    } on FileSystemException {
      return null;
    }
  }

  static Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }
}

class ImageModelIntegrityException implements Exception {
  const ImageModelIntegrityException(this.message);

  final String message;

  @override
  String toString() => 'ImageModelIntegrityException: $message';
}
