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
  final Set<String> _retiredTaskIds = <String>{};

  StreamSubscription<TaskUpdate>? _updatesSubscription;
  StreamSubscription<TaskRecord>? _recordsSubscription;
  Future<void>? _initialization;
  int _replacementGeneration = 0;

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
    final requestedTask = buildModelDownloadTask(
      modelKey: modelKey,
      modelName: modelName,
      sourceUrl: sourceUrl,
      fileName: fileName,
      huggingFaceToken: dotenv.env['HUGGING_FACE_TOKEN'],
    );
    final outputPath = await requestedTask.filePath();
    final output = File(outputPath);
    if (await output.exists()) {
      return DownloadedModelFile(
        path: outputPath,
        fileName: fileName,
        sizeBytes: await output.length(),
      );
    }

    var replacementRequired = false;
    final activeTaskId = activeModelDownloadTaskId(
      modelKey: modelKey,
      currentTaskId: _taskIdByModelKey[modelKey],
    );
    final existingPending = _pending[activeTaskId];
    if (existingPending != null) {
      final requestMatches = modelDownloadTasksMatchRequest(
        persistedTask: existingPending.task,
        requestedTask: requestedTask,
        persistedOutputPath: existingPending.outputPath,
        requestedOutputPath: outputPath,
      );
      if (requestMatches) return existingPending.completer.future;
      await _discardTaskState(
        activeTaskId,
        StateError('Download request changed'),
      );
      replacementRequired = true;
    }

    final existingRecord = await _downloader.database.recordForId(activeTaskId);
    if (existingRecord != null && !existingRecord.status.isFinalState) {
      final persistedOutputPath = await existingRecord.task.filePath();
      final requestMatches = modelDownloadTasksMatchRequest(
        persistedTask: existingRecord.task,
        requestedTask: requestedTask,
        persistedOutputPath: persistedOutputPath,
        requestedOutputPath: outputPath,
      );

      var taskCanResume = false;
      var resumeSucceeded = false;
      if (requestMatches &&
          existingRecord.status == TaskStatus.paused &&
          existingRecord.task is DownloadTask) {
        final persistedTask = existingRecord.task as DownloadTask;
        taskCanResume = await _downloader.taskCanResume(persistedTask);
        if (taskCanResume) {
          resumeSucceeded = await _downloader.resume(persistedTask);
        }
      }

      final action = persistedModelDownloadAction(
        status: existingRecord.status,
        requestMatches: requestMatches,
        taskCanResume: taskCanResume,
        resumeSucceeded: resumeSucceeded,
      );
      if (action == PersistedModelDownloadAction.reuse) {
        final persistedTask = existingRecord.task;
        if (persistedTask is! DownloadTask) {
          await _discardTaskState(
            activeTaskId,
            StateError('Persisted download task type changed'),
          );
          replacementRequired = true;
        } else {
          final pending = _createPending(
            task: persistedTask,
            modelKey: modelKey,
            outputPath: outputPath,
            fileName: fileName,
            onProgress: onProgress,
          );
          return pending.completer.future;
        }
      } else {
        await _discardTaskState(
          activeTaskId,
          StateError('Persisted download could not be resumed'),
        );
        replacementRequired = true;
      }
    } else if (existingRecord != null) {
      await _downloader.database.deleteRecordWithId(activeTaskId);
      replacementRequired = true;
    }

    final task = replacementRequired
        ? requestedTask.copyWith(taskId: _nextReplacementTaskId(modelKey))
        : requestedTask;
    final pending = _createPending(
      task: task,
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
    final currentTaskId = _taskIdByModelKey[modelKey];
    if (currentTaskId == null) return false;
    final taskId = activeModelDownloadTaskId(
      modelKey: modelKey,
      currentTaskId: currentTaskId,
    );
    return !(_snapshots[taskId]?.isTerminal ?? false);
  }

  Future<bool> cancelDownload(String modelKey) async {
    await _ensureInitialized();
    final currentTaskId = _taskIdByModelKey[modelKey];
    if (currentTaskId == null) return false;
    final taskId = activeModelDownloadTaskId(
      modelKey: modelKey,
      currentTaskId: currentTaskId,
    );
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
    if (_retiredTaskIds.contains(snapshot.id)) return;

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
    required DownloadTask task,
    required String modelKey,
    required String outputPath,
    required String fileName,
    void Function(double progress, String message)? onProgress,
  }) {
    final pending = _PendingDownload(
      completer: Completer<DownloadedModelFile>(),
      task: task,
      modelKey: modelKey,
      outputPath: outputPath,
      fileName: fileName,
      onProgress: onProgress ?? (_, _) {},
    );
    _pending[task.taskId] = pending;
    _taskIdByModelKey[modelKey] = task.taskId;
    return pending;
  }

  Future<void> _discardTaskState(String taskId, Object error) async {
    _retiredTaskIds.add(taskId);
    await _downloader.cancelTaskWithId(taskId);
    await _downloader.database.deleteRecordWithId(taskId);

    final pending = _pending.remove(taskId);
    if (pending != null) {
      _taskIdByModelKey.remove(pending.modelKey);
      pending.fail(error);
    }

    final snapshot = _snapshots.remove(taskId);
    if (snapshot != null && _taskIdByModelKey[snapshot.modelKey] == taskId) {
      _taskIdByModelKey.remove(snapshot.modelKey);
    }
    _emitSnapshots();
  }

  String _nextReplacementTaskId(String modelKey) {
    _replacementGeneration++;
    final attemptId =
        '${DateTime.now().microsecondsSinceEpoch}_$_replacementGeneration';
    return modelDownloadReplacementTaskId(modelKey, attemptId);
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
    _retiredTaskIds.clear();
    _replacementGeneration = 0;
    _initialization = null;
  }
}

class _PendingDownload {
  const _PendingDownload({
    required this.completer,
    required this.task,
    required this.modelKey,
    required this.outputPath,
    required this.fileName,
    required this.onProgress,
  });

  final Completer<DownloadedModelFile> completer;
  final DownloadTask task;
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
