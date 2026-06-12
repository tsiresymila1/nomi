import 'dart:io';

import 'package:background_downloader/background_downloader.dart';

const modelDownloadsGroup = 'model_downloads';
const modelDownloadsDirectory = 'models';

enum ModelDownloadStatus {
  queued,
  running,
  complete,
  failed,
  cancelled,
  paused,
}

class ModelDownloadSnapshot {
  const ModelDownloadSnapshot({
    required this.id,
    required this.modelKey,
    required this.progress,
    required this.status,
    required this.message,
    this.error,
  });

  final String id;
  final String modelKey;
  final double progress;
  final ModelDownloadStatus status;
  final String message;
  final String? error;

  bool get isTerminal =>
      status == ModelDownloadStatus.complete ||
      status == ModelDownloadStatus.failed ||
      status == ModelDownloadStatus.cancelled;
}

DownloadTask buildModelDownloadTask({
  required String modelKey,
  required String modelName,
  required String sourceUrl,
  required String fileName,
  String? huggingFaceToken,
}) {
  final token = huggingFaceToken?.trim();
  return DownloadTask(
    taskId: modelDownloadTaskId(modelKey),
    url: sourceUrl,
    filename: fileName,
    directory: modelDownloadsDirectory,
    baseDirectory: BaseDirectory.applicationSupport,
    group: modelDownloadsGroup,
    updates: Updates.statusAndProgress,
    retries: 3,
    allowPause: true,
    metaData: modelKey,
    displayName: modelName,
    headers: {
      HttpHeaders.acceptEncodingHeader: '*',
      if (token != null && token.isNotEmpty)
        HttpHeaders.authorizationHeader: 'Bearer $token',
    },
  );
}

String modelDownloadTaskId(String modelKey) {
  final normalized = modelKey
      .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  return 'model_download_${normalized.substring(0, normalized.length.clamp(0, 48))}_${_fnv1a(modelKey)}';
}

ModelDownloadSnapshot modelDownloadSnapshotFromRecord(TaskRecord record) {
  return ModelDownloadSnapshot(
    id: record.taskId,
    modelKey: record.task.metaData,
    progress: _normalizedProgress(record.progress),
    status: modelDownloadStatusFromTaskStatus(record.status),
    message: _messageFor(record.task, record.status, record.progress),
    error: record.exception?.description,
  );
}

ModelDownloadStatus modelDownloadStatusFromTaskStatus(TaskStatus status) {
  return switch (status) {
    TaskStatus.enqueued ||
    TaskStatus.waitingToRetry => ModelDownloadStatus.queued,
    TaskStatus.running => ModelDownloadStatus.running,
    TaskStatus.complete => ModelDownloadStatus.complete,
    TaskStatus.notFound || TaskStatus.failed => ModelDownloadStatus.failed,
    TaskStatus.canceled => ModelDownloadStatus.cancelled,
    TaskStatus.paused => ModelDownloadStatus.paused,
  };
}

double _normalizedProgress(double progress) => progress.clamp(0.0, 1.0);

String _messageFor(Task task, TaskStatus status, double progress) {
  final label = task.displayName.isEmpty ? task.filename : task.displayName;
  return switch (status) {
    TaskStatus.enqueued => '$label queued',
    TaskStatus.running =>
      '$label ${(progress.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%',
    TaskStatus.complete => '$label downloaded',
    TaskStatus.notFound => '$label was not found',
    TaskStatus.failed => '$label failed',
    TaskStatus.canceled => '$label cancelled',
    TaskStatus.waitingToRetry => '$label waiting to retry',
    TaskStatus.paused => '$label paused',
  };
}

String _fnv1a(String value) {
  var hash = 0x811c9dc5;
  for (final byte in value.codeUnits) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
