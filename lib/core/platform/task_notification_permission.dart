import 'package:background_downloader/background_downloader.dart';
import 'package:gena/core/platform/app_capabilities.dart';

typedef NotificationPermissionAction = Future<PermissionStatus> Function();

class TaskNotificationPermissionException implements Exception {
  const TaskNotificationPermissionException();

  @override
  String toString() =>
      'Notifications are required for background tasks. Enable Nomi '
      'notifications in Android settings and try again.';
}

class TaskNotificationPermissionService {
  TaskNotificationPermissionService({
    NotificationPermissionAction? status,
    NotificationPermissionAction? request,
    AppPlatform? platform,
  }) : _status =
           status ??
           (() => FileDownloader().permissions.status(
             PermissionType.notifications,
           )),
       _request =
           request ??
           (() => FileDownloader().permissions.request(
             PermissionType.notifications,
           )),
       _platform = platform ?? AppCapabilities.current.platform;

  static final instance = TaskNotificationPermissionService();

  final NotificationPermissionAction _status;
  final NotificationPermissionAction _request;
  final AppPlatform _platform;
  Future<void>? _inFlight;

  Future<void> ensureGranted() {
    if (_platform != AppPlatform.android) return Future<void>.value();
    final active = _inFlight;
    if (active != null) return active;

    late final Future<void> operation;
    operation = _ensureGranted().whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
    _inFlight = operation;
    return operation;
  }

  Future<void> _ensureGranted() async {
    var status = await _status();
    if (status != PermissionStatus.granted) {
      status = await _request();
    }
    if (status != PermissionStatus.granted) {
      throw const TaskNotificationPermissionException();
    }
  }
}
