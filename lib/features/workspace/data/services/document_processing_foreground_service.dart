import 'dart:io';

import 'package:flutter/services.dart';
import 'package:gena/core/platform/task_notification_permission.dart';

bool requiresDocumentProcessingForeground({
  required String platform,
  required int sizeBytes,
}) {
  return platform.toLowerCase() == 'android';
}

abstract interface class DocumentProcessingForegroundController {
  Future<bool> startIfNeeded({
    required String documentName,
    required int sizeBytes,
  });

  Future<void> update({required String documentName, required String phase});

  Future<void> stop();
}

class AndroidDocumentProcessingForegroundController
    implements DocumentProcessingForegroundController {
  AndroidDocumentProcessingForegroundController({
    TaskNotificationPermissionService? notificationPermission,
  }) : _notificationPermission =
           notificationPermission ?? TaskNotificationPermissionService.instance;

  static const MethodChannel _channel = MethodChannel(
    'gena/document_processing',
  );
  final TaskNotificationPermissionService _notificationPermission;

  @override
  Future<bool> startIfNeeded({
    required String documentName,
    required int sizeBytes,
  }) async {
    if (!requiresDocumentProcessingForeground(
      platform: Platform.operatingSystem,
      sizeBytes: sizeBytes,
    )) {
      return false;
    }
    await _notificationPermission.ensureGranted();
    try {
      await _channel.invokeMethod<void>('start', {'name': documentName});
      return true;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> update({
    required String documentName,
    required String phase,
  }) async {
    try {
      await _channel.invokeMethod<void>('update', {
        'name': documentName,
        'phase': phase,
      });
    } on PlatformException {
      // Processing continues even if Android cannot refresh its notification.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // The OS also removes the notification when the process exits.
    }
  }
}
