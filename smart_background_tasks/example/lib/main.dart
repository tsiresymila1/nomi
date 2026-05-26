import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:smart_background_tasks/smart_background_tasks.dart';

SmartBackgroundTask createDemoModelTask() => DioDownloadTask();

class DioDownloadTask extends SmartBackgroundTask {
  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  bool _paused = false;
  bool _completed = false;
  bool _cancelled = false;
  bool _isDownloading = false;
  String? _error;

  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String _modelName = 'Model';
  String _downloadUrl = '';
  String _savePath = '';

  @override
  Future<void> onStart(SmartTaskContext context) async {
    _modelName = context.payload['modelName'] as String? ?? 'Model';
    _downloadUrl =
        context.payload['downloadUrl'] as String? ??
        'https://speed.cloudflare.com/__down?bytes=5000000';
    final String fileName =
        context.payload['fileName'] as String? ?? '${context.taskId}.bin';
    _savePath = '${Directory.systemTemp.path}/$fileName';
    _paused = false;
    _completed = false;
    _cancelled = false;
    _error = null;
    _downloadedBytes = 0;
    _totalBytes = 0;

    final File output = File(_savePath);
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
      return SmartTaskStep.completed(
        message: '$_modelName downloaded to $_savePath',
      );
    }

    if (_totalBytes <= 0) {
      return SmartTaskStep.progress(
        progress: 0,
        message: '$_modelName connecting...',
      );
    }

    final double progress = _downloadedBytes / _totalBytes;
    return SmartTaskStep.progress(
      progress: progress,
      message:
          '$_modelName ${(progress * 100).toStringAsFixed(0)}% '
          '(${_downloadedBytes ~/ 1024}KB/${_totalBytes ~/ 1024}KB)',
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
      final File file = File(_savePath);
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
      final File file = File(_savePath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      final int resumeFrom = (resume && await file.exists())
          ? await file.length()
          : 0;

      if (resumeFrom > 0) {
        _downloadedBytes = resumeFrom;
      }

      final Map<String, dynamic> headers = <String, dynamic>{
        HttpHeaders.acceptEncodingHeader: '*',
      };
      FileAccessMode accessMode = FileAccessMode.write;
      if (resumeFrom > 0) {
        headers[HttpHeaders.rangeHeader] = 'bytes=$resumeFrom-';
        accessMode = FileAccessMode.append;
      }

      await _dio.download(
        _downloadUrl,
        _savePath,
        fileAccessMode: accessMode,
        deleteOnError: !resume,
        options: Options(headers: headers),
        cancelToken: _cancelToken,
        onReceiveProgress: (int received, int total) {
          if (_cancelled) {
            return;
          }

          final int absoluteReceived = resumeFrom + received;
          _downloadedBytes = absoluteReceived;

          if (total > 0) {
            _totalBytes = total >= absoluteReceived
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

void main() {
  runApp(const SmartBackgroundTasksExampleApp());
}

class SmartBackgroundTasksExampleApp extends StatelessWidget {
  const SmartBackgroundTasksExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Background Tasks Example',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const TasksPage(),
    );
  }
}

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final SmartBackgroundTasksController _controller =
      SmartBackgroundTasksController(
        foregroundServiceTitle: 'Smart Background Tasks',
        foregroundServiceText: 'Preparing tasks',
        foregroundEventIntervalMs: 1000,
      );

  StreamSubscription<List<SmartTaskSnapshot>>? _tasksSubscription;
  List<SmartTaskSnapshot> _tasks = const <SmartTaskSnapshot>[];
  SmartNotificationMode _notificationMode = SmartNotificationMode.grouped;
  String? _selectedTaskId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    await _controller.initialize(notificationMode: _notificationMode);
    await _controller.requestEssentialPermissions();

    _tasksSubscription = _controller.tasksStream.listen((
      List<SmartTaskSnapshot> tasks,
    ) {
      setState(() {
        _tasks = tasks;
        if (_selectedTaskId != null &&
            tasks.every((task) => task.id != _selectedTaskId)) {
          _selectedTaskId = null;
        }
      });
    });
  }

  Future<void> _startOneTask() async {
    await _runAction(() async {
      final SmartModelSource model = kDefaultFlutterGemmaModelSources.first;

      final String id = await _controller.startTask(
        SmartTaskRequest(
          name: 'Download ${model.name}',
          factoryHandle: SmartTaskFactoryHandle.fromFactory(
            createDemoModelTask,
          ),
          payload: <String, dynamic>{
            'modelName': model.name,
            'modelUrl': model.url,
            'downloadUrl': 'https://speed.cloudflare.com/__down?bytes=5000000',
            'fileName': '${model.name.replaceAll(' ', '_')}_5mb.bin',
          },
        ),
      );

      setState(() => _selectedTaskId = id);
    });
  }

  Future<void> _startThreeTasks() async {
    await _runAction(() async {
      final List<SmartTaskRequest> requests = kDefaultFlutterGemmaModelSources
          .take(3)
          .toList(growable: false)
          .asMap()
          .entries
          .map((entry) {
            final int index = entry.key;
            final SmartModelSource model = entry.value;
            return SmartTaskRequest(
              name: 'Download ${model.name}',
              factoryHandle: SmartTaskFactoryHandle.fromFactory(
                createDemoModelTask,
              ),
              payload: <String, dynamic>{
                'modelName': model.name,
                'modelUrl': model.url,
                'downloadUrl':
                    'https://speed.cloudflare.com/__down?bytes=${(index + 4) * 1000000}',
                'fileName':
                    '${model.name.replaceAll(' ', '_')}_${index + 4}mb.bin',
              },
            );
          })
          .toList(growable: false);

      final List<String> ids = await _controller.startTasks(requests);
      if (ids.isNotEmpty) {
        setState(() => _selectedTaskId = ids.last);
      }
    });
  }

  Future<void> _pauseSelectedTask() async {
    final String? id =
        _selectedTaskId ?? _firstTaskWithStatus(SmartTaskStatus.running);
    if (id == null) {
      return;
    }
    await _controller.pauseTask(id);
  }

  Future<void> _resumeSelectedTask() async {
    final String? id =
        _selectedTaskId ?? _firstTaskWithStatus(SmartTaskStatus.paused);
    if (id == null) {
      return;
    }
    await _controller.resumeTask(id);
  }

  Future<void> _cancelSelectedTask() async {
    final String? id = _selectedTaskId ?? _firstNonTerminalTaskId();
    if (id == null) {
      return;
    }
    await _controller.cancelTask(id);
  }

  Future<void> _cancelAll() async {
    await _controller.cancelAll();
  }

  Future<void> _changeMode(SmartNotificationMode mode) async {
    setState(() => _notificationMode = mode);
    await _controller.setNotificationMode(mode);
  }

  String? _firstTaskWithStatus(SmartTaskStatus status) {
    for (final SmartTaskSnapshot task in _tasks) {
      if (task.status == status) {
        return task.id;
      }
    }
    return null;
  }

  String? _firstNonTerminalTaskId() {
    for (final SmartTaskSnapshot task in _tasks) {
      if (!task.isTerminal) {
        return task.id;
      }
    }
    return null;
  }

  Future<void> _runAction(Future<void> Function() callback) async {
    if (_busy) {
      return;
    }

    setState(() => _busy = true);
    try {
      await callback();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('smart_background_tasks')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text('Notification mode:'),
                const SizedBox(width: 12),
                DropdownButton<SmartNotificationMode>(
                  value: _notificationMode,
                  items: const <DropdownMenuItem<SmartNotificationMode>>[
                    DropdownMenuItem(
                      value: SmartNotificationMode.grouped,
                      child: Text('grouped'),
                    ),
                    DropdownMenuItem(
                      value: SmartNotificationMode.perTask,
                      child: Text('perTask'),
                    ),
                  ],
                  onChanged: (SmartNotificationMode? mode) {
                    if (mode != null) {
                      _changeMode(mode);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ElevatedButton(
                  onPressed: _busy ? null : _startOneTask,
                  child: const Text('Start One Task'),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : _startThreeTasks,
                  child: const Text('Start Three Tasks'),
                ),
                OutlinedButton(
                  onPressed: _pauseSelectedTask,
                  child: const Text('Pause Task'),
                ),
                OutlinedButton(
                  onPressed: _resumeSelectedTask,
                  child: const Text('Resume Task'),
                ),
                OutlinedButton(
                  onPressed: _cancelSelectedTask,
                  child: const Text('Cancel Task'),
                ),
                OutlinedButton(
                  onPressed: _cancelAll,
                  child: const Text('Cancel All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Default model sources (from flutter_gemma):',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            ...kDefaultFlutterGemmaModelSources.map((SmartModelSource model) {
              return Text('• ${model.name}: ${model.url}');
            }),
            const SizedBox(height: 16),
            Expanded(
              child: _tasks.isEmpty
                  ? const Center(child: Text('No tasks yet.'))
                  : ListView.separated(
                      itemBuilder: (BuildContext context, int index) {
                        final SmartTaskSnapshot task = _tasks[index];
                        final bool selected = task.id == _selectedTaskId;

                        return Card(
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            onTap: () {
                              setState(() => _selectedTaskId = task.id);
                            },
                            title: Text(task.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const SizedBox(height: 6),
                                Text(
                                  'Status: ${task.status.name} | ${task.message}',
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(value: task.progress),
                                const SizedBox(height: 6),
                                Text(
                                  '${(task.progress * 100).toStringAsFixed(0)}%',
                                ),
                                if (task.payload['downloadUrl'] != null)
                                  Text(
                                    task.payload['downloadUrl'] as String,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                if (task.error != null)
                                  Text(
                                    'Error: ${task.error}',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, index) => const SizedBox(height: 8),
                      itemCount: _tasks.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
