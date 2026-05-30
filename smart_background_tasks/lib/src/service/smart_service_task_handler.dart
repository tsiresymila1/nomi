import 'dart:async';
import 'dart:ui';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/protocol.dart';
import '../models/smart_notification_mode.dart';
import '../models/smart_task_event.dart';
import '../models/smart_task_snapshot.dart';
import '../models/smart_task_status.dart';
import '../task/smart_background_task.dart';
import '../task/smart_task_context.dart';
import '../task/smart_task_step.dart';

class SmartServiceTaskHandler extends TaskHandler {
  SmartServiceTaskHandler({required SmartNotificationMode initialMode})
    : _notificationMode = initialMode;

  static const String _localChannelId = 'smart_background_tasks_per_task';
  static const String _localChannelName = 'Smart Background Tasks';
  static const String _cancelActionId = 'cancel_task';

  final Map<String, _RunningTask> _tasks = <String, _RunningTask>{};
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  SmartNotificationMode _notificationMode;
  bool _localNotificationsInitialized = false;
  bool _isTicking = false;
  int _nextNotificationId = 40000;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _ensureLocalNotificationPlugin();
    await _refreshForegroundNotification();
    _emitState(message: 'Service started');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_isTicking) {
      return;
    }

    _isTicking = true;
    unawaited(_tick().whenComplete(() => _isTicking = false));
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _localNotifications.cancelAll();
    _tasks.clear();
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map) {
      return;
    }

    final Map<String, dynamic> message = Map<String, dynamic>.from(data);
    if (message['envelope'] != kSmartEnvelope ||
        message['type'] != kCommandType) {
      return;
    }

    final String command = message['command'] as String? ?? '';

    switch (command) {
      case kCmdStart:
        unawaited(_handleStart(message));
        break;
      case kCmdPause:
        unawaited(_handlePause(message['taskId'] as String?));
        break;
      case kCmdResume:
        unawaited(_handleResume(message['taskId'] as String?));
        break;
      case kCmdCancel:
        unawaited(_handleCancel(message['taskId'] as String?));
        break;
      case kCmdCancelAll:
        unawaited(_handleCancelAll());
        break;
      case kCmdSetMode:
        final String rawMode = message['mode'] as String? ?? kModeGrouped;
        _notificationMode = rawMode == kModePerTask
            ? SmartNotificationMode.perTask
            : SmartNotificationMode.grouped;
        unawaited(_refreshForegroundNotification());
        break;
      default:
        break;
    }
  }

  Future<void> _handleStart(Map<String, dynamic> message) async {
    final String taskId = message['taskId'] as String? ?? '';
    final String taskName = message['name'] as String? ?? 'Unnamed task';
    final int rawHandle = (message['factoryHandle'] as num?)?.toInt() ?? 0;
    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      message['payload'] as Map? ?? const <String, dynamic>{},
    );

    if (taskId.isEmpty || rawHandle == 0) {
      return;
    }

    final SmartTaskContext context = SmartTaskContext(
      taskId: taskId,
      taskName: taskName,
      payload: payload,
    );

    try {
      final CallbackHandle callbackHandle = CallbackHandle.fromRawHandle(
        rawHandle,
      );
      final Function? restored = PluginUtilities.getCallbackFromHandle(
        callbackHandle,
      );

      if (restored is! SmartBackgroundTaskFactory) {
        throw StateError(
          'Unable to restore task factory for "$taskName". Use a top-level/static function.',
        );
      }

      final SmartBackgroundTask task = restored.call();
      final DateTime now = DateTime.now();

      final _RunningTask runningTask = _RunningTask(
        task: task,
        context: context,
        snapshot: SmartTaskSnapshot(
          id: taskId,
          name: taskName,
          status: SmartTaskStatus.queued,
          progress: 0,
          message: 'Queued',
          payload: payload,
          createdAt: now,
          updatedAt: now,
        ),
        localNotificationId: _nextNotificationId++,
      );

      _tasks[taskId] = runningTask;

      await task.onStart(context);

      _tasks[taskId] = runningTask.copyWith(
        snapshot: runningTask.snapshot.copyWith(
          status: SmartTaskStatus.running,
          message: 'Running',
          updatedAt: DateTime.now(),
        ),
      );
    } catch (error) {
      _tasks[taskId] = _RunningTask.failed(
        taskId: taskId,
        taskName: taskName,
        payload: payload,
        error: error.toString(),
        localNotificationId: _nextNotificationId++,
      );
    }

    await _refreshForegroundNotification();
    _emitState();
  }

  Future<void> _handlePause(String? taskId) async {
    if (taskId == null) {
      return;
    }

    final _RunningTask? current = _tasks[taskId];
    if (current == null || current.snapshot.status != SmartTaskStatus.running) {
      return;
    }

    try {
      await current.task?.onPause(current.context!);
      _tasks[taskId] = current.copyWith(
        snapshot: current.snapshot.copyWith(
          status: SmartTaskStatus.paused,
          message: 'Paused',
          updatedAt: DateTime.now(),
        ),
      );
      await _showOrUpdateTaskNotification(_tasks[taskId]!);
      await _refreshForegroundNotification();
      _emitState();
    } catch (error) {
      _markFailed(taskId, error.toString());
    }
  }

  Future<void> _handleResume(String? taskId) async {
    if (taskId == null) {
      return;
    }

    final _RunningTask? current = _tasks[taskId];
    if (current == null || current.snapshot.status != SmartTaskStatus.paused) {
      return;
    }

    try {
      await current.task?.onResume(current.context!);
      _tasks[taskId] = current.copyWith(
        snapshot: current.snapshot.copyWith(
          status: SmartTaskStatus.running,
          message: 'Running',
          updatedAt: DateTime.now(),
        ),
      );
      await _showOrUpdateTaskNotification(_tasks[taskId]!);
      await _refreshForegroundNotification();
      _emitState();
    } catch (error) {
      _markFailed(taskId, error.toString());
    }
  }

  Future<void> _handleCancel(String? taskId) async {
    if (taskId == null) {
      return;
    }

    final _RunningTask? current = _tasks[taskId];
    if (current == null) {
      return;
    }

    try {
      await current.task?.onCancel(current.context!);
    } catch (_) {}

    final DateTime now = DateTime.now();
    _tasks[taskId] = current.copyWith(
      snapshot: current.snapshot.copyWith(
        status: SmartTaskStatus.cancelled,
        message: 'Cancelled',
        updatedAt: now,
      ),
      terminalAt: now,
    );

    await _showOrUpdateTaskNotification(_tasks[taskId]!);
    await _refreshForegroundNotification();
    _emitState();
  }

  Future<void> _handleCancelAll() async {
    final List<String> ids = _tasks.keys.toList(growable: false);
    for (final String taskId in ids) {
      await _handleCancel(taskId);
    }
  }

  Future<void> _tick() async {
    final List<String> taskIds = _tasks.keys.toList(growable: false);
    for (final String taskId in taskIds) {
      final _RunningTask? current = _tasks[taskId];
      if (current == null ||
          current.snapshot.status != SmartTaskStatus.running) {
        continue;
      }

      try {
        final SmartTaskStep step = await current.task!.onTick(current.context!);
        _applyStep(taskId, step);
      } catch (error) {
        _markFailed(taskId, error.toString());
      }
    }

    _pruneOldTerminalTasks();
    await _refreshForegroundNotification();
    _emitState();
  }

  void _applyStep(String taskId, SmartTaskStep step) {
    final _RunningTask? current = _tasks[taskId];
    if (current == null) {
      return;
    }

    final DateTime now = DateTime.now();
    final double nextProgress = step.progress == null
        ? current.snapshot.progress
        : step.progress!.clamp(0, 1).toDouble();

    SmartTaskSnapshot nextSnapshot = current.snapshot.copyWith(
      progress: nextProgress,
      updatedAt: now,
      message: step.message ?? current.snapshot.message,
    );

    DateTime? terminalAt;

    if (step.isCompleted) {
      nextSnapshot = nextSnapshot.copyWith(
        status: SmartTaskStatus.completed,
        progress: 1,
        message: step.message ?? 'Completed',
      );
      terminalAt = now;
    } else if (step.isFailed) {
      nextSnapshot = nextSnapshot.copyWith(
        status: SmartTaskStatus.failed,
        message: step.message ?? 'Failed',
        error: step.error ?? 'Task failed',
      );
      terminalAt = now;
    }

    _tasks[taskId] = current.copyWith(
      snapshot: nextSnapshot,
      terminalAt: terminalAt,
    );

    unawaited(_showOrUpdateTaskNotification(_tasks[taskId]!));
  }

  void _markFailed(String taskId, String error) {
    final _RunningTask? current = _tasks[taskId];
    if (current == null) {
      return;
    }

    final DateTime now = DateTime.now();
    _tasks[taskId] = current.copyWith(
      snapshot: current.snapshot.copyWith(
        status: SmartTaskStatus.failed,
        message: 'Failed',
        error: error,
        updatedAt: now,
      ),
      terminalAt: now,
    );

    unawaited(_showOrUpdateTaskNotification(_tasks[taskId]!));
  }

  void _pruneOldTerminalTasks() {
    final DateTime now = DateTime.now();
    final List<String> idsToRemove = <String>[];

    for (final MapEntry<String, _RunningTask> entry in _tasks.entries) {
      final DateTime? terminalAt = entry.value.terminalAt;
      if (terminalAt == null) {
        continue;
      }

      final Duration age = now.difference(terminalAt);
      if (age.inSeconds >= 10) {
        idsToRemove.add(entry.key);
      }
    }

    for (final String taskId in idsToRemove) {
      final _RunningTask? task = _tasks.remove(taskId);
      if (task != null) {
        unawaited(_localNotifications.cancel(task.localNotificationId));
      }
    }
  }

  Future<void> _refreshForegroundNotification() async {
    final List<_RunningTask> runningTasks = _tasks.values
        .where((task) => task.snapshot.status == SmartTaskStatus.running)
        .toList(growable: false);

    final int pausedCount = _tasks.values
        .where((task) => task.snapshot.status == SmartTaskStatus.paused)
        .length;

    if (runningTasks.isEmpty && pausedCount == 0) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Smart tasks idle',
        notificationText: 'No running task',
      );
    } else {
      final double averageProgress = runningTasks.isEmpty
          ? 0
          : runningTasks
                    .map((task) => task.snapshot.progress)
                    .reduce((a, b) => a + b) /
                runningTasks.length;

      final String title =
          'Running: ${runningTasks.length}  Paused: $pausedCount';
      final String body =
          'Average progress ${(averageProgress * 100).toStringAsFixed(0)}%';

      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: body,
      );
    }

    if (_notificationMode == SmartNotificationMode.perTask) {
      for (final _RunningTask task in _tasks.values) {
        await _showOrUpdateTaskNotification(task);
      }
    } else {
      await _localNotifications.cancelAll();
    }
  }

  Future<void> _showOrUpdateTaskNotification(_RunningTask task) async {
    if (_notificationMode != SmartNotificationMode.perTask) {
      return;
    }

    await _ensureLocalNotificationPlugin();

    final int max = 100;
    final int progressValue = (task.snapshot.progress * max).round().clamp(
      0,
      max,
    );

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _localChannelId,
          _localChannelName,
          channelDescription: 'Per task progress notifications',
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: max,
          progress: progressValue,
          ongoing: !task.snapshot.isTerminal,
          autoCancel: task.snapshot.isTerminal,
          actions: task.snapshot.isTerminal
              ? null
              : const <AndroidNotificationAction>[
                  AndroidNotificationAction(
                    _cancelActionId,
                    'Cancel',
                    cancelNotification: false,
                  ),
                ],
        );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    String subtitle =
        '${task.snapshot.status.name.toUpperCase()} • $progressValue%';
    if (task.snapshot.error != null) {
      subtitle = '$subtitle • ${task.snapshot.error}';
    }

    await _localNotifications.show(
      task.localNotificationId,
      task.snapshot.name,
      subtitle,
      details,
      payload: task.snapshot.id,
    );
  }

  Future<void> _ensureLocalNotificationPlugin() async {
    if (_localNotificationsInitialized) {
      return;
    }

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationResponse,
    );
    _localNotificationsInitialized = true;
  }

  void _onLocalNotificationResponse(NotificationResponse response) {
    if (response.actionId != _cancelActionId) {
      return;
    }

    final taskId = response.payload;
    if (taskId == null || taskId.isEmpty) {
      return;
    }

    unawaited(_handleCancel(taskId));
  }

  void _emitState({String? message}) {
    final List<SmartTaskSnapshot> tasks =
        _tasks.values.map((item) => item.snapshot).toList(growable: false)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final int runningCount = tasks
        .where((task) => task.status == SmartTaskStatus.running)
        .length;

    final SmartTaskEvent event = SmartTaskEvent(
      type: SmartTaskEventType.state,
      tasks: tasks,
      runningCount: runningCount,
      timestamp: DateTime.now(),
      message: message,
    );

    FlutterForegroundTask.sendDataToMain(<String, dynamic>{
      'envelope': kSmartEnvelope,
      'type': kEventType,
      'event': event.toMap(),
    });
  }
}

class _RunningTask {
  const _RunningTask({
    required this.task,
    required this.context,
    required this.snapshot,
    required this.localNotificationId,
    this.terminalAt,
  });

  factory _RunningTask.failed({
    required String taskId,
    required String taskName,
    required Map<String, dynamic> payload,
    required String error,
    required int localNotificationId,
  }) {
    final DateTime now = DateTime.now();
    return _RunningTask(
      task: null,
      context: null,
      snapshot: SmartTaskSnapshot(
        id: taskId,
        name: taskName,
        status: SmartTaskStatus.failed,
        progress: 0,
        message: 'Failed',
        payload: payload,
        createdAt: now,
        updatedAt: now,
        error: error,
      ),
      localNotificationId: localNotificationId,
      terminalAt: now,
    );
  }

  final SmartBackgroundTask? task;
  final SmartTaskContext? context;
  final SmartTaskSnapshot snapshot;
  final int localNotificationId;
  final DateTime? terminalAt;

  _RunningTask copyWith({
    SmartBackgroundTask? task,
    SmartTaskContext? context,
    SmartTaskSnapshot? snapshot,
    int? localNotificationId,
    Object? terminalAt = _unset,
  }) {
    return _RunningTask(
      task: task ?? this.task,
      context: context ?? this.context,
      snapshot: snapshot ?? this.snapshot,
      localNotificationId: localNotificationId ?? this.localNotificationId,
      terminalAt: identical(terminalAt, _unset)
          ? this.terminalAt
          : terminalAt as DateTime?,
    );
  }

  static const Object _unset = Object();
}
