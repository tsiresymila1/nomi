import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gena/features/downloads/data/services/model_download_task.dart';

export 'package:gena/features/downloads/data/services/model_download_task.dart'
    show ModelDownloadSnapshot, ModelDownloadStatus;

class DownloadedModelFile {
  const DownloadedModelFile({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
  });

  final String path;
  final String fileName;
  final int sizeBytes;
}

class ModelBackgroundDownloadService {
  ModelBackgroundDownloadService._();

  static final ModelBackgroundDownloadService instance =
      ModelBackgroundDownloadService._();

  final FileDownloader _downloader = FileDownloader();
  final StreamController<List<ModelDownloadSnapshot>> _tasksController =
      StreamController<List<ModelDownloadSnapshot>>.broadcast();
  final Map<String, ModelDownloadSnapshot> _snapshots =
      <String, ModelDownloadSnapshot>{};
  final Map<String, _PendingDownload> _pending = <String, _PendingDownload>{};
  final Map<String, String> _taskIdByModelKey = <String, String>{};

  StreamSubscription<TaskUpdate>? _updatesSubscription;
  StreamSubscription<TaskRecord>? _recordsSubscription;
  Future<void>? _initialization;

  Stream<List<ModelDownloadSnapshot>> watchTasks() async* {
    await _ensureInitialized();
    yield _currentSnapshots;
    yield* _tasksController.stream;
  }

  Future<void> _ensureInitialized() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    _updatesSubscription = _downloader.updates.listen(_onTaskUpdate);
    _recordsSubscription = _downloader.database.updates.listen(_onTaskRecord);

    _downloader.configureNotificationForGroup(
      modelDownloadsGroup,
      running: const TaskNotification(
        'Downloading model',
        '{displayName} · {progress}',
      ),
      complete: const TaskNotification(
        'Model downloaded',
        '{displayName} is ready to install',
      ),
      error: const TaskNotification(
        'Model download failed',
        '{displayName} could not be downloaded',
      ),
      paused: const TaskNotification(
        'Model download paused',
        '{displayName} is paused',
      ),
      canceled: const TaskNotification(
        'Model download cancelled',
        '{displayName} was cancelled',
      ),
      progressBar: true,
    );

    await _downloader.configure(
      androidConfig: [
        (Config.runInForeground, true),
        (Config.useCacheDir, Config.never),
      ],
      iOSConfig: (Config.resourceTimeout, const Duration(hours: 4)),
    );
    await _downloader.start(autoCleanDatabase: true);

    final records = await _downloader.database.allRecords(
      group: modelDownloadsGroup,
    );
    for (final record in records) {
      _storeSnapshot(modelDownloadSnapshotFromRecord(record));
    }
    _emitSnapshots();

    final notificationPermission = await _downloader.permissions.status(
      PermissionType.notifications,
    );
    if (notificationPermission == PermissionStatus.undetermined) {
      await _downloader.permissions.request(PermissionType.notifications);
    }
  }

  Future<DownloadedModelFile> downloadModelToFile({
    required String modelKey,
    required String modelName,
    required String sourceUrl,
    void Function(double progress, String message)? onProgress,
  }) async {
    await _ensureInitialized();

    final fileName = _fileNameFor(modelName, sourceUrl);
    final task = buildModelDownloadTask(
      modelKey: modelKey,
      modelName: modelName,
      sourceUrl: sourceUrl,
      fileName: fileName,
      huggingFaceToken: dotenv.env['HUGGING_FACE_TOKEN'],
    );
    final outputPath = await task.filePath();
    final output = File(outputPath);
    if (await output.exists()) {
      return DownloadedModelFile(
        path: outputPath,
        fileName: fileName,
        sizeBytes: await output.length(),
      );
    }

    final existingPending = _pending[task.taskId];
    if (existingPending != null) {
      return existingPending.completer.future;
    }

    final existingRecord = await _downloader.database.recordForId(task.taskId);
    if (existingRecord != null && !existingRecord.status.isFinalState) {
      final pending = _createPending(
        taskId: task.taskId,
        modelKey: modelKey,
        outputPath: outputPath,
        fileName: fileName,
        onProgress: onProgress,
      );
      if (existingRecord.status == TaskStatus.paused &&
          existingRecord.task is DownloadTask) {
        await _downloader.resume(existingRecord.task as DownloadTask);
      }
      return pending.completer.future;
    }
    await _downloader.database.deleteRecordWithId(task.taskId);

    final pending = _createPending(
      taskId: task.taskId,
      modelKey: modelKey,
      outputPath: outputPath,
      fileName: fileName,
      onProgress: onProgress,
    );

    final enqueued = await _downloader.enqueue(task);
    if (!enqueued) {
      _pending.remove(task.taskId);
      _taskIdByModelKey.remove(modelKey);
      throw StateError('Could not enqueue model download');
    }

    return pending.completer.future;
  }

  bool hasRunningDownload(String modelKey) {
    final taskId = _taskIdByModelKey[modelKey];
    if (taskId == null) return false;
    return !(_snapshots[taskId]?.isTerminal ?? false);
  }

  Future<bool> cancelDownload(String modelKey) async {
    await _ensureInitialized();
    final taskId = _taskIdByModelKey[modelKey];
    if (taskId == null) return false;
    return _downloader.cancelTaskWithId(taskId);
  }

  void _onTaskRecord(TaskRecord record) {
    if (record.group != modelDownloadsGroup) return;
    _handleSnapshot(modelDownloadSnapshotFromRecord(record));
  }

  void _onTaskUpdate(TaskUpdate update) {
    if (update.task.group != modelDownloadsGroup) return;

    final previous = _snapshots[update.task.taskId];
    final record = switch (update) {
      TaskStatusUpdate statusUpdate => TaskRecord(
        update.task,
        statusUpdate.status,
        _progressForStatus(statusUpdate.status, previous?.progress ?? 0),
        -1,
        statusUpdate.exception,
      ),
      TaskProgressUpdate progressUpdate => TaskRecord(
        update.task,
        _taskStatusForProgress(previous?.status),
        progressUpdate.progress,
        progressUpdate.expectedFileSize,
      ),
    };
    _handleSnapshot(modelDownloadSnapshotFromRecord(record));
  }

  void _handleSnapshot(ModelDownloadSnapshot snapshot) {
    _storeSnapshot(snapshot);
    _emitSnapshots();

    final pending = _pending[snapshot.id];
    if (pending == null) return;

    pending.onProgress(snapshot.progress, snapshot.message);
    switch (snapshot.status) {
      case ModelDownloadStatus.complete:
        _pending.remove(snapshot.id);
        _taskIdByModelKey.remove(pending.modelKey);
        pending.complete();
        break;
      case ModelDownloadStatus.failed:
        _pending.remove(snapshot.id);
        _taskIdByModelKey.remove(pending.modelKey);
        pending.fail(StateError(snapshot.error ?? snapshot.message));
        break;
      case ModelDownloadStatus.cancelled:
        _pending.remove(snapshot.id);
        _taskIdByModelKey.remove(pending.modelKey);
        pending.fail(StateError('Download cancelled'));
        break;
      case ModelDownloadStatus.queued:
      case ModelDownloadStatus.running:
      case ModelDownloadStatus.paused:
        break;
    }
  }

  void _storeSnapshot(ModelDownloadSnapshot snapshot) {
    _snapshots[snapshot.id] = snapshot;
    if (!snapshot.isTerminal) {
      _taskIdByModelKey[snapshot.modelKey] = snapshot.id;
    } else if (_taskIdByModelKey[snapshot.modelKey] == snapshot.id) {
      _taskIdByModelKey.remove(snapshot.modelKey);
    }
  }

  _PendingDownload _createPending({
    required String taskId,
    required String modelKey,
    required String outputPath,
    required String fileName,
    void Function(double progress, String message)? onProgress,
  }) {
    final pending = _PendingDownload(
      completer: Completer<DownloadedModelFile>(),
      modelKey: modelKey,
      outputPath: outputPath,
      fileName: fileName,
      onProgress: onProgress ?? (_, _) {},
    );
    _pending[taskId] = pending;
    _taskIdByModelKey[modelKey] = taskId;
    return pending;
  }

  List<ModelDownloadSnapshot> get _currentSnapshots =>
      List<ModelDownloadSnapshot>.unmodifiable(_snapshots.values);

  void _emitSnapshots() {
    if (!_tasksController.isClosed) {
      _tasksController.add(_currentSnapshots);
    }
  }

  String _fileNameFor(String modelName, String sourceUrl) {
    final uri = Uri.tryParse(sourceUrl);
    final sourceFileName = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : '';
    final fallback = modelName.contains('.') ? modelName : '$modelName.task';
    final cleaned = (sourceFileName.trim().isEmpty ? fallback : sourceFileName)
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return cleaned.isEmpty ? 'model.task' : cleaned;
  }

  Future<void> dispose() async {
    await _updatesSubscription?.cancel();
    await _recordsSubscription?.cancel();
    await _tasksController.close();
    _pending.clear();
    _taskIdByModelKey.clear();
    _snapshots.clear();
    _initialization = null;
  }
}

class _PendingDownload {
  const _PendingDownload({
    required this.completer,
    required this.modelKey,
    required this.outputPath,
    required this.fileName,
    required this.onProgress,
  });

  final Completer<DownloadedModelFile> completer;
  final String modelKey;
  final String outputPath;
  final String fileName;
  final void Function(double progress, String message) onProgress;

  void complete() {
    if (completer.isCompleted) return;
    final output = File(outputPath);
    completer.complete(
      DownloadedModelFile(
        path: outputPath,
        fileName: fileName,
        sizeBytes: output.existsSync() ? output.lengthSync() : 0,
      ),
    );
  }

  void fail(Object error) {
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
  }
}

double _progressForStatus(TaskStatus status, double previousProgress) {
  return switch (status) {
    TaskStatus.complete => 1,
    TaskStatus.enqueued ||
    TaskStatus.running ||
    TaskStatus.waitingToRetry ||
    TaskStatus.paused => previousProgress,
    TaskStatus.notFound || TaskStatus.failed || TaskStatus.canceled => 0,
  };
}

TaskStatus _taskStatusForProgress(ModelDownloadStatus? status) {
  return switch (status) {
    ModelDownloadStatus.queued => TaskStatus.enqueued,
    ModelDownloadStatus.complete => TaskStatus.complete,
    ModelDownloadStatus.failed => TaskStatus.failed,
    ModelDownloadStatus.cancelled => TaskStatus.canceled,
    ModelDownloadStatus.paused => TaskStatus.paused,
    ModelDownloadStatus.running || null => TaskStatus.running,
  };
}
