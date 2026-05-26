import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_background_tasks/smart_background_tasks.dart';

SmartBackgroundTask createModelDownloadTask() => _ModelDownloadTask();

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

  final SmartBackgroundTasksController _controller =
      SmartBackgroundTasksController(
        foregroundServiceTitle: 'Model download in progress',
        foregroundServiceText: 'Preparing model download',
        foregroundEventIntervalMs: 1000,
      );

  bool _initialized = false;
  StreamSubscription<List<SmartTaskSnapshot>>? _tasksSubscription;
  final Map<String, _PendingDownload> _pending = <String, _PendingDownload>{};

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    await _controller.initialize(
      notificationMode: SmartNotificationMode.perTask,
    );
    await _controller.requestEssentialPermissions();

    _tasksSubscription = _controller.tasksStream.listen((tasks) {
      for (final task in tasks) {
        final pending = _pending[task.id];
        if (pending == null) {
          continue;
        }

        pending.onProgress(task.progress, task.message);

        switch (task.status) {
          case SmartTaskStatus.completed:
            _pending.remove(task.id);
            pending.complete(
              DownloadedModelFile(
                path: pending.outputPath,
                fileName: pending.fileName,
                sizeBytes: File(pending.outputPath).existsSync()
                    ? File(pending.outputPath).lengthSync()
                    : 0,
              ),
            );
            break;
          case SmartTaskStatus.failed:
            _pending.remove(task.id);
            pending.fail(StateError(task.error ?? task.message));
            break;
          case SmartTaskStatus.cancelled:
            _pending.remove(task.id);
            pending.fail(StateError('Download cancelled'));
            break;
          case SmartTaskStatus.queued:
          case SmartTaskStatus.running:
          case SmartTaskStatus.paused:
            break;
        }
      }
    });

    _initialized = true;
  }

  Future<DownloadedModelFile> downloadModelToFile({
    required String modelName,
    required String sourceUrl,
    void Function(double progress, String message)? onProgress,
  }) async {
    await _ensureInitialized();

    final destination = await _resolveDestination(modelName, sourceUrl);
    if (await File(destination.path).exists()) {
      return DownloadedModelFile(
        path: destination.path,
        fileName: destination.fileName,
        sizeBytes: await File(destination.path).length(),
      );
    }

    final completer = Completer<DownloadedModelFile>();

    final hfToken = dotenv.env['HUGGING_FACE_TOKEN']?.trim();
    final taskId = await _controller.startTask(
      SmartTaskRequest(
        name: 'Download $modelName',
        factoryHandle: SmartTaskFactoryHandle.fromFactory(
          createModelDownloadTask,
        ),
        payload: <String, dynamic>{
          'modelName': modelName,
          'downloadUrl': sourceUrl,
          'outputPath': destination.path,
          if (hfToken != null && hfToken.isNotEmpty) 'hfToken': hfToken,
        },
      ),
    );

    _pending[taskId] = _PendingDownload(
      completer: completer,
      outputPath: destination.path,
      fileName: destination.fileName,
      onProgress: onProgress ?? (progress, message) {},
    );

    return completer.future;
  }

  Future<_DownloadDestination> _resolveDestination(
    String modelName,
    String sourceUrl,
  ) async {
    final appSupport = await getApplicationSupportDirectory();
    final modelsDir = Directory('${appSupport.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final uri = Uri.tryParse(sourceUrl);
    String fileName = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : '';
    if (fileName.trim().isEmpty) {
      fileName = _safeModelName(modelName);
    }

    final sanitized = _safeFilename(fileName);
    final fullPath = '${modelsDir.path}/$sanitized';

    return _DownloadDestination(path: fullPath, fileName: sanitized);
  }

  String _safeFilename(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (cleaned.isEmpty) {
      return 'model.task';
    }
    return cleaned;
  }

  String _safeModelName(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (cleaned.isEmpty) {
      return 'model.task';
    }
    if (cleaned.contains('.')) {
      return cleaned;
    }
    return '$cleaned.task';
  }

  Future<void> dispose() async {
    await _tasksSubscription?.cancel();
    _tasksSubscription = null;
    _pending.clear();
    _initialized = false;
    await _controller.dispose();
  }
}

class _PendingDownload {
  const _PendingDownload({
    required this.completer,
    required this.outputPath,
    required this.fileName,
    required this.onProgress,
  });

  final Completer<DownloadedModelFile> completer;
  final String outputPath;
  final String fileName;
  final void Function(double progress, String message) onProgress;

  void complete(DownloadedModelFile result) {
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  void fail(Object error) {
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
  }
}

class _DownloadDestination {
  const _DownloadDestination({required this.path, required this.fileName});

  final String path;
  final String fileName;
}

class _ModelDownloadTask extends SmartBackgroundTask {
  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  bool _paused = false;
  bool _cancelled = false;
  bool _completed = false;
  bool _isDownloading = false;
  String? _error;

  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String _modelName = 'Model';
  String _downloadUrl = '';
  String _outputPath = '';
  String? _hfToken;

  @override
  Future<void> onStart(SmartTaskContext context) async {
    _modelName = context.payload['modelName'] as String? ?? 'Model';
    _downloadUrl = context.payload['downloadUrl'] as String? ?? '';
    _outputPath = context.payload['outputPath'] as String? ?? '';
    _hfToken = context.payload['hfToken'] as String?;

    _paused = false;
    _cancelled = false;
    _completed = false;
    _isDownloading = false;
    _error = null;
    _downloadedBytes = 0;
    _totalBytes = 0;

    if (_downloadUrl.trim().isEmpty || _outputPath.trim().isEmpty) {
      _error = 'Missing download URL or output path';
      return;
    }

    final output = File(_outputPath);
    if (await output.exists()) {
      await output.delete();
    }

    unawaited(_downloadFile(resume: false));
  }

  @override
  Future<SmartTaskStep> onTick(SmartTaskContext context) async {
    if (_error != null) {
      return SmartTaskStep.failed(
        error: _error!,
        message: '$_modelName failed',
      );
    }

    if (_completed) {
      return SmartTaskStep.completed(message: '$_modelName downloaded');
    }

    if (_totalBytes <= 0) {
      return SmartTaskStep.progress(
        progress: 0,
        message: '$_modelName connecting...',
      );
    }

    final progress = _downloadedBytes / _totalBytes;
    return SmartTaskStep.progress(
      progress: progress,
      message:
          '$_modelName ${(progress * 100).toStringAsFixed(0)}% (${_downloadedBytes ~/ 1024}KB/${_totalBytes ~/ 1024}KB)',
    );
  }

  @override
  Future<void> onPause(SmartTaskContext context) async {
    _paused = true;
    _cancelToken?.cancel('Paused by user');
  }

  @override
  Future<void> onResume(SmartTaskContext context) async {
    if (!_paused || _completed || _cancelled) {
      return;
    }
    _paused = false;
    _error = null;
    unawaited(_downloadFile(resume: true));
  }

  @override
  Future<void> onCancel(SmartTaskContext context) async {
    _cancelled = true;
    _paused = false;
    _cancelToken?.cancel('Cancelled by user');

    try {
      final file = File(_outputPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _downloadFile({required bool resume}) async {
    if (_isDownloading || _completed || _cancelled) {
      return;
    }

    _isDownloading = true;
    _cancelToken = CancelToken();

    try {
      final file = File(_outputPath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      final resumeFrom = (resume && await file.exists())
          ? await file.length()
          : 0;
      if (resumeFrom > 0) {
        _downloadedBytes = resumeFrom;
      }

      final headers = <String, dynamic>{HttpHeaders.acceptEncodingHeader: '*'};
      if (_hfToken != null && _hfToken!.isNotEmpty) {
        headers[HttpHeaders.authorizationHeader] = 'Bearer ${_hfToken!}';
      }

      var accessMode = FileAccessMode.write;
      if (resumeFrom > 0) {
        headers[HttpHeaders.rangeHeader] = 'bytes=$resumeFrom-';
        accessMode = FileAccessMode.append;
      }

      await _dio.download(
        _downloadUrl,
        _outputPath,
        fileAccessMode: accessMode,
        deleteOnError: !resume,
        options: Options(headers: headers),
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (_cancelled) {
            return;
          }

          _downloadedBytes = resumeFrom + received;
          if (total > 0) {
            _totalBytes = total >= _downloadedBytes
                ? total
                : resumeFrom + total;
          }
        },
      );

      if (!_paused && !_cancelled) {
        _completed = true;
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) && (_paused || _cancelled)) {
        return;
      }
      _error = error.message ?? 'Download failed';
    } catch (error) {
      _error = error.toString();
    } finally {
      _isDownloading = false;
    }
  }
}
