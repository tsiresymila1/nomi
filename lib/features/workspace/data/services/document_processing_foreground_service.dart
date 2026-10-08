import 'dart:io';

import 'package:flutter/services.dart';

const int documentProcessingForegroundThresholdBytes = 8 * 1024 * 1024;

bool requiresDocumentProcessingForeground({
  required String platform,
  required int sizeBytes,
}) {
  return platform.toLowerCase() == 'android' &&
      sizeBytes >= documentProcessingForegroundThresholdBytes;
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
  const AndroidDocumentProcessingForegroundController();

  static const MethodChannel _channel = MethodChannel(
    'gena/document_processing',
  );

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
