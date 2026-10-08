import 'dart:io';

import 'package:gena/features/chat/data/models/whisper_model_profile.dart';
import 'package:gena/features/downloads/data/services/model_background_download_service.dart';
import 'package:path_provider/path_provider.dart';

class WhisperDownloadedModel {
  const WhisperDownloadedModel({required this.path, required this.sizeBytes});

  final String path;
  final int sizeBytes;
}

abstract interface class WhisperModelDownloadClient {
  Future<WhisperDownloadedModel> download({
    required WhisperModelProfile profile,
    required void Function(double progress, String message) onProgress,
  });

  Future<bool> cancel(WhisperModelProfile profile);
}

class BackgroundWhisperModelDownloadClient
    implements WhisperModelDownloadClient {
  const BackgroundWhisperModelDownloadClient();

  String _modelKey(WhisperModelProfile profile) => 'whisper_${profile.id}';

  @override
  Future<WhisperDownloadedModel> download({
    required WhisperModelProfile profile,
    required void Function(double progress, String message) onProgress,
  }) async {
    final downloaded = await ModelBackgroundDownloadService.instance
        .downloadModelToFile(
          modelKey: _modelKey(profile),
          modelName: 'Whisper ${profile.label}',
          sourceUrl: profile.downloadUri.toString(),
          onProgress: onProgress,
        );
    return WhisperDownloadedModel(
      path: downloaded.path,
      sizeBytes: downloaded.sizeBytes,
    );
  }

  @override
  Future<bool> cancel(WhisperModelProfile profile) {
    return ModelBackgroundDownloadService.instance.cancelDownload(
      _modelKey(profile),
    );
  }
}

abstract interface class WhisperProvisioner {
  Future<String> ensureReady(
    WhisperModelProfile profile, {
    void Function(double progress, String message)? onProgress,
  });
}

abstract interface class WhisperModelManager implements WhisperProvisioner {
  Future<bool> isInstalled(WhisperModelProfile profile);

  Future<bool> cancel(WhisperModelProfile profile);
}

class WhisperModelProvisioner implements WhisperModelManager {
  WhisperModelProvisioner({
    WhisperModelDownloadClient? downloadClient,
    Future<Directory> Function()? modelDirectoryProvider,
  }) : _downloadClient =
           downloadClient ?? const BackgroundWhisperModelDownloadClient(),
       _modelDirectoryProvider =
           modelDirectoryProvider ?? getApplicationSupportDirectory;

  final WhisperModelDownloadClient _downloadClient;
  final Future<Directory> Function() _modelDirectoryProvider;
  final Map<WhisperModelProfile, Future<String>> _inFlight =
      <WhisperModelProfile, Future<String>>{};

  @override
  Future<String> ensureReady(
    WhisperModelProfile profile, {
    void Function(double progress, String message)? onProgress,
  }) async {
    final existing = _inFlight[profile];
    if (existing != null) return existing;

    final operation = _ensureReady(
      profile,
      onProgress: onProgress ?? (_, _) {},
    );
    _inFlight[profile] = operation;
    try {
      return await operation;
    } finally {
      if (identical(_inFlight[profile], operation)) {
        _inFlight.remove(profile);
      }
    }
  }

  Future<String> _ensureReady(
    WhisperModelProfile profile, {
    required void Function(double progress, String message) onProgress,
  }) async {
    final directory = await _modelDirectoryProvider();
    if (!await directory.exists()) await directory.create(recursive: true);
    final target = File('${directory.path}/${profile.fileName}');
    if (await _isUsable(target)) {
      onProgress(1, '${profile.label} is ready');
      return target.path;
    }

    final downloaded = await _downloadClient.download(
      profile: profile,
      onProgress: onProgress,
    );
    final stagingFile = File(downloaded.path);
    if (!await _isUsable(stagingFile)) {
      throw StateError('The downloaded Whisper model is missing or empty.');
    }

    if (await target.exists()) await target.delete();
    if (stagingFile.path != target.path) {
      await stagingFile.rename(target.path);
    }
    if (!await _isUsable(target)) {
      throw StateError('The Whisper model could not be installed.');
    }
    onProgress(1, '${profile.label} is ready');
    return target.path;
  }

  @override
  Future<bool> isInstalled(WhisperModelProfile profile) async {
    final directory = await _modelDirectoryProvider();
    return _isUsable(File('${directory.path}/${profile.fileName}'));
  }

  @override
  Future<bool> cancel(WhisperModelProfile profile) {
    return _downloadClient.cancel(profile);
  }

  Future<bool> _isUsable(File file) async {
    return await file.exists() && await file.length() > 0;
  }
}
