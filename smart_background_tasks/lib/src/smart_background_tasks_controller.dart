import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'core/protocol.dart';
import 'models/smart_notification_mode.dart';
import 'models/smart_task_event.dart';
import 'models/smart_task_snapshot.dart';
import 'models/smart_task_status.dart';
import 'service/smart_service_task_handler.dart';
import 'task/smart_task_request.dart';

@pragma('vm:entry-point')
void smartBackgroundTasksStartCallback() {
  DartPluginRegistrant.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(
    SmartServiceTaskHandler(initialMode: SmartNotificationMode.grouped),
  );
}

class SmartBackgroundTasksController {
  SmartBackgroundTasksController({
    this.foregroundServiceId = 2471,
    this.foregroundServiceTitle = 'Smart background tasks',
    this.foregroundServiceText = 'Task service is active',
    this.foregroundEventIntervalMs = 1000,
  });

  final int foregroundServiceId;
  final String foregroundServiceTitle;
  final String foregroundServiceText;
  final int foregroundEventIntervalMs;

  final StreamController<SmartTaskEvent> _eventController =
      StreamController<SmartTaskEvent>.broadcast();
  final StreamController<List<SmartTaskSnapshot>> _tasksController =
      StreamController<List<SmartTaskSnapshot>>.broadcast();

  final Map<String, SmartTaskSnapshot> _tasksById =
      <String, SmartTaskSnapshot>{};

  bool _initialized = false;
  int _taskSequence = 0;
  SmartNotificationMode _notificationMode = SmartNotificationMode.grouped;

  Stream<SmartTaskEvent> get events => _eventController.stream;

  Stream<List<SmartTaskSnapshot>> get tasksStream => _tasksController.stream;

  List<SmartTaskSnapshot> get tasks {
    return _sortedTasks();
  }

  Future<void> initialize({
    SmartNotificationMode notificationMode = SmartNotificationMode.grouped,
  }) async {
    if (_initialized) {
      await setNotificationMode(notificationMode);
      return;
    }

    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'smart_background_tasks_service',
        channelName: 'Smart Background Tasks Service',
        channelDescription:
            'Required foreground notification for background tasks',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          foregroundEventIntervalMs,
        ),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _initialized = true;
    await setNotificationMode(notificationMode);
  }

  Future<void> requestEssentialPermissions({
    bool requestBatteryOptimizationIgnore = false,
  }) async {
    final NotificationPermission permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (Platform.isAndroid && requestBatteryOptimizationIgnore) {
      final bool ignoring =
          await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!ignoring) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
  }

  Future<void> setNotificationMode(SmartNotificationMode mode) async {
    _notificationMode = mode;
    if (await FlutterForegroundTask.isRunningService) {
      _sendCommand(<String, dynamic>{
        'command': kCmdSetMode,
        'mode': mode == SmartNotificationMode.perTask
            ? kModePerTask
            : kModeGrouped,
      });
    }
  }

  Future<String> startTask(SmartTaskRequest request) async {
    _assertInitialized();
    await _ensureServiceRunning();

    final String taskId = request.taskId ?? _nextTaskId();

    final SmartTaskSnapshot optimistic = SmartTaskSnapshot(
      id: taskId,
      name: request.name,
      status: SmartTaskStatus.queued,
      progress: 0,
      message: 'Queued',
      payload: request.payload,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _tasksById[taskId] = optimistic;
    _tasksController.add(_sortedTasks());

    _sendCommand(<String, dynamic>{
      'command': kCmdStart,
      'taskId': taskId,
      'name': request.name,
      'factoryHandle': request.factoryHandle.rawHandle,
      'payload': request.payload,
    });

    return taskId;
  }

  Future<List<String>> startTasks(List<SmartTaskRequest> requests) async {
    final List<String> ids = <String>[];
    for (final SmartTaskRequest request in requests) {
      final String id = await startTask(request);
      ids.add(id);
    }
    return ids;
  }

  Future<void> pauseTask(String taskId) async {
    _sendCommand(<String, dynamic>{'command': kCmdPause, 'taskId': taskId});
  }

  Future<void> resumeTask(String taskId) async {
    _sendCommand(<String, dynamic>{'command': kCmdResume, 'taskId': taskId});
  }

  Future<void> cancelTask(String taskId) async {
    _sendCommand(<String, dynamic>{'command': kCmdCancel, 'taskId': taskId});
  }

  Future<void> cancelAll() async {
    _sendCommand(<String, dynamic>{'command': kCmdCancelAll});
  }

  Future<void> stopService() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  Future<void> dispose() async {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    await _eventController.close();
    await _tasksController.close();
  }

  Future<void> _ensureServiceRunning() async {
    if (await FlutterForegroundTask.isRunningService) {
      await setNotificationMode(_notificationMode);
      return;
    }

    final ServiceRequestResult result =
        await FlutterForegroundTask.startService(
          serviceId: foregroundServiceId,
          notificationTitle: foregroundServiceTitle,
          notificationText: foregroundServiceText,
          callback: smartBackgroundTasksStartCallback,
        );

    if (result is ServiceRequestFailure) {
      throw StateError('Unable to start foreground service: ${result.error}');
    }

    await setNotificationMode(_notificationMode);
  }

  void _sendCommand(Map<String, dynamic> command) {
    FlutterForegroundTask.sendDataToTask(<String, dynamic>{
      'envelope': kSmartEnvelope,
      'type': kCommandType,
      ...command,
    });
  }

  void _onTaskData(Object data) {
    if (data is! Map) {
      return;
    }

    final Map<String, dynamic> map = Map<String, dynamic>.from(data);
    if (map['envelope'] != kSmartEnvelope || map['type'] != kEventType) {
      return;
    }

    final Map<String, dynamic> rawEvent = Map<String, dynamic>.from(
      map['event'] as Map? ?? const <String, dynamic>{},
    );

    final SmartTaskEvent event = SmartTaskEvent.fromMap(rawEvent);

    _tasksById
      ..clear()
      ..addEntries(event.tasks.map((task) => MapEntry(task.id, task)));

    _eventController.add(event);
    _tasksController.add(_sortedTasks());
  }

  String _nextTaskId() {
    _taskSequence += 1;
    return 'task_${DateTime.now().millisecondsSinceEpoch}_$_taskSequence';
  }

  List<SmartTaskSnapshot> _sortedTasks() {
    final List<SmartTaskSnapshot> items = _tasksById.values.toList(
      growable: false,
    )..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  void _assertInitialized() {
    if (!_initialized) {
      throw StateError(
        'Call initialize() before using SmartBackgroundTasksController.',
      );
    }
  }
}
