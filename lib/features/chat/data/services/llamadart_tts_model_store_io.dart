import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:gena/features/chat/data/models/llamadart_tts_model_profile.dart';
import 'package:gena/features/chat/data/services/llamadart_tts_model_store.dart';
import 'package:gena/features/downloads/data/services/model_background_download_service.dart';
import 'package:path_provider/path_provider.dart';

LlamaDartTtsModelStore createPlatformLlamaDartTtsModelStore() =>
    IoLlamaDartTtsModelStore();

class IoLlamaDartTtsModelStore implements LlamaDartTtsModelStore {
  @override
  bool get isSupported => true;

  String _modelKey(LlamaDartTtsModelProfile profile) =>
      'tts:${profile.id}:model';

  String _projectorKey(LlamaDartTtsModelProfile profile) =>
      'tts:${profile.id}:projector';

  @override
  Future<InstalledLlamaDartTtsModel?> resolve(
    LlamaDartTtsModelProfile profile,
  ) async {
    final directory = await _modelsDirectory();
    final model = File('${directory.path}/${profile.modelFileName}');
    final projector = File('${directory.path}/${profile.projectorFileName}');
    if (!await _isTrusted(
          model,
          sizeBytes: profile.modelSizeBytes,
          expectedSha256: profile.modelSha256,
        ) ||
        !await _isTrusted(
          projector,
          sizeBytes: profile.projectorSizeBytes,
          expectedSha256: profile.projectorSha256,
        )) {
      return null;
    }
    return InstalledLlamaDartTtsModel(
      profile: profile,
      modelPath: model.path,
      projectorPath: projector.path,
    );
  }

  @override
  Future<InstalledLlamaDartTtsModel> install(
    LlamaDartTtsModelProfile profile, {
    required void Function(double progress, String message) onProgress,
    required void Function(String message) onVerifying,
  }) async {
    final existing = await resolve(profile);
    if (existing != null) return existing;

    final modelWeight = profile.modelDownloadWeight;
    final downloadedModel = await _download(
      key: _modelKey(profile),
      name: profile.name,
      url: profile.modelUrl,
      expectedFileName: profile.modelFileName,
      expectedSize: profile.modelSizeBytes,
      expectedSha256: profile.modelSha256,
      onProgress: (progress, message) =>
          onProgress(progress * modelWeight, 'Voice model · $message'),
      onVerifying: onVerifying,
    );
    final downloadedProjector = await _download(
      key: _projectorKey(profile),
      name: '${profile.name} audio projector',
      url: profile.projectorUrl,
      expectedFileName: profile.projectorFileName,
      expectedSize: profile.projectorSizeBytes,
      expectedSha256: profile.projectorSha256,
      onProgress: (progress, message) => onProgress(
        modelWeight + (progress * (1 - modelWeight)),
        'Audio projector · $message',
      ),
      onVerifying: onVerifying,
    );
    onProgress(1, '${profile.name} is installed');
    return InstalledLlamaDartTtsModel(
      profile: profile,
      modelPath: downloadedModel.path,
      projectorPath: downloadedProjector.path,
    );
  }

  Future<File> _download({
    required String key,
    required String name,
    required String url,
    required String expectedFileName,
    required int expectedSize,
    required String expectedSha256,
    required void Function(double progress, String message) onProgress,
    required void Function(String message) onVerifying,
  }) async {
    final directory = await _modelsDirectory();
    final target = File('${directory.path}/$expectedFileName');
    if (await target.exists() &&
        !await _isTrusted(
          target,
          sizeBytes: expectedSize,
          expectedSha256: expectedSha256,
        )) {
      await _deleteFileAndMarker(target);
    }
    final downloaded = await ModelBackgroundDownloadService.instance
        .downloadModelToFile(
          modelKey: key,
          modelName: name,
          sourceUrl: url,
          onProgress: onProgress,
        );
    final file = File(downloaded.path);
    if (file.path != target.path) {
      if (await target.exists()) await _deleteFileAndMarker(target);
      await file.rename(target.path);
    }
    if (!await target.exists() || await target.length() != expectedSize) {
      await _deleteFileAndMarker(target);
      throw StateError('$name has an unexpected download size.');
    }
    onVerifying('Verifying $name…');
    final digest = await _digest(target);
    if (digest.toLowerCase() != expectedSha256.toLowerCase()) {
      await _deleteFileAndMarker(target);
      throw StateError('$name checksum verification failed.');
    }
    await File(
      '${target.path}.sha256',
    ).writeAsString(expectedSha256, flush: true);
    return target;
  }

  @override
  Future<void> cancelInstall(LlamaDartTtsModelProfile profile) async {
    await Future.wait([
      ModelBackgroundDownloadService.instance.cancelDownload(
        _modelKey(profile),
      ),
      ModelBackgroundDownloadService.instance.cancelDownload(
        _projectorKey(profile),
      ),
    ]);
  }

  @override
  Future<void> delete(LlamaDartTtsModelProfile profile) async {
    await cancelInstall(profile);
    final directory = await _modelsDirectory();
    await _deleteFileAndMarker(
      File('${directory.path}/${profile.modelFileName}'),
    );
    await _deleteFileAndMarker(
      File('${directory.path}/${profile.projectorFileName}'),
    );
  }

  Future<bool> _isTrusted(
    File file, {
    required int sizeBytes,
    required String expectedSha256,
  }) async {
    if (!await file.exists() || await file.length() != sizeBytes) return false;
    final marker = File('${file.path}.sha256');
    if (await marker.exists() &&
        (await marker.readAsString()).trim().toLowerCase() ==
            expectedSha256.toLowerCase()) {
      return true;
    }
    final digest = await _digest(file);
    if (digest.toLowerCase() != expectedSha256.toLowerCase()) return false;
    await marker.writeAsString(expectedSha256, flush: true);
    return true;
  }

  Future<Directory> _modelsDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/models');
    await directory.create(recursive: true);
    return directory;
  }

  Future<String> _digest(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  Future<void> _deleteFileAndMarker(File file) async {
    if (await file.exists()) await file.delete();
    final marker = File('${file.path}.sha256');
    if (await marker.exists()) await marker.delete();
  }
}
