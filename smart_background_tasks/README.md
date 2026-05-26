# smart_background_tasks

`smart_background_tasks` is a reusable Flutter package for long-running tasks using an Android foreground service.

It provides:

- Foreground service support using `flutter_foreground_task`
- Progress/state events streamed back to Flutter UI
- Multiple concurrent tasks
- Pause / resume / cancel / cancel all
- Custom task implementations in your app (outside the package)
- Notification modes:
  - `grouped`: one foreground notification with global summary
  - `perTask`: required foreground notification + one local notification per task

## Dependencies

This package is built with:

- `flutter_foreground_task: ^9.1.0`
- `flutter_local_notifications: ^18.0.1`

## Android setup

Add the following inside `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_REMOTE_MESSAGING" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<application>
  <service
      android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
      android:foregroundServiceType="dataSync|remoteMessaging"
      android:exported="false" />
</application>
```

## Usage

### 1) Create a custom task outside the package

```dart
import 'dart:io';
import 'package:dio/dio.dart';

SmartBackgroundTask createMyTask() => MyTask();

class MyTask extends SmartBackgroundTask {
  final Dio _dio = Dio();
  CancelToken? _cancelToken;
  int _received = 0;
  int _total = 0;
  bool _done = false;
  String? _error;

  @override
  Future<void> onStart(SmartTaskContext context) async {
    final String url = context.payload['downloadUrl'] as String;
    final String fileName = context.payload['fileName'] as String;
    final String path = '${Directory.systemTemp.path}/$fileName';
    _cancelToken = CancelToken();

    _download(url, path);
  }

  @override
  Future<SmartTaskStep> onTick(SmartTaskContext context) async {
    if (_error != null) {
      return SmartTaskStep.failed(error: _error!);
    }
    if (_done) {
      return SmartTaskStep.completed(message: 'Done');
    }
    if (_total <= 0) {
      return SmartTaskStep.progress(progress: 0, message: 'Connecting...');
    }

    final double progress = _received / _total;
    return SmartTaskStep.progress(progress: progress, message: 'Downloading...');
  }

  @override
  Future<void> onCancel(SmartTaskContext context) async {
    _cancelToken?.cancel('cancelled');
  }

  Future<void> _download(String url, String path) async {
    IOSink? sink;
    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(responseType: ResponseType.stream),
        cancelToken: _cancelToken,
      );
      final body = response.data!;
      _total = body.contentLength > 0 ? body.contentLength : 0;

      final file = File(path);
      sink = file.openWrite();
      await for (final chunk in body.stream) {
        sink.add(chunk);
        _received += chunk.length;
      }
      await sink.flush();
      _done = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      await sink?.close();
    }
  }
}
```

Important: task factory must be a top-level or static function.

If your custom task uses `dio`, add it to your app:

```yaml
dependencies:
  dio: ^5.9.0
```

### 2) Initialize controller

```dart
final controller = SmartBackgroundTasksController();

await controller.initialize(
  notificationMode: SmartNotificationMode.grouped,
);

await controller.requestEssentialPermissions();
```

### 3) Start task

```dart
await controller.startTask(
  SmartTaskRequest(
    name: 'Download model',
    factoryHandle: SmartTaskFactoryHandle.fromFactory(createMyTask),
    payload: {
      'downloadUrl': 'https://speed.cloudflare.com/__down?bytes=5000000',
      'fileName': 'model.bin',
    },
  ),
);
```

### 4) Observe progress

```dart
controller.tasksStream.listen((tasks) {
  // Update UI
});
```

### 5) Control tasks

```dart
await controller.pauseTask(taskId);
await controller.resumeTask(taskId);
await controller.cancelTask(taskId);
await controller.cancelAll();
```

## Default model sources

The package also includes a default list of Flutter Gemma model sources:

- Gemma 4 E2B
- Qwen3 0.6B
- DeepSeek R1

Available as `kDefaultFlutterGemmaModelSources`.

## Example app

See `example/` for a full app with:

- Start one task
- Start three tasks
- Pause/resume/cancel selected task
- Cancel all
- Progress list with `LinearProgressIndicator`
- Notification mode switch (`grouped` / `perTask`)
- Real `dio` streaming download task example
- Uses `dio.download(..., onReceiveProgress: ...)` for progress updates
