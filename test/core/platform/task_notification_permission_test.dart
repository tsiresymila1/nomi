import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/core/platform/task_notification_permission.dart';

void main() {
  test('requests Android notification permission when denied', () async {
    var requestCount = 0;
    final service = TaskNotificationPermissionService(
      status: () async => PermissionStatus.denied,
      request: () async {
        requestCount++;
        return PermissionStatus.granted;
      },
      platform: AppPlatform.android,
    );

    await service.ensureGranted();

    expect(requestCount, 1);
  });

  test('does not request permission when already granted', () async {
    var requestCount = 0;
    final service = TaskNotificationPermissionService(
      status: () async => PermissionStatus.granted,
      request: () async {
        requestCount++;
        return PermissionStatus.granted;
      },
      platform: AppPlatform.android,
    );

    await service.ensureGranted();

    expect(requestCount, 0);
  });

  test('rejects an Android background task when refused', () async {
    final service = TaskNotificationPermissionService(
      status: () async => PermissionStatus.denied,
      request: () async => PermissionStatus.denied,
      platform: AppPlatform.android,
    );

    await expectLater(
      service.ensureGranted(),
      throwsA(isA<TaskNotificationPermissionException>()),
    );
  });

  test('does not request Android permission on other platforms', () async {
    var statusCount = 0;
    var requestCount = 0;
    final service = TaskNotificationPermissionService(
      status: () async {
        statusCount++;
        return PermissionStatus.denied;
      },
      request: () async {
        requestCount++;
        return PermissionStatus.denied;
      },
      platform: AppPlatform.iOS,
    );

    await service.ensureGranted();

    expect(statusCount, 0);
    expect(requestCount, 0);
  });
}
