import 'dart:ui';

import 'smart_background_task.dart';

class SmartTaskFactoryHandle {
  const SmartTaskFactoryHandle(this.rawHandle);

  final int rawHandle;

  static SmartTaskFactoryHandle fromFactory(
    SmartBackgroundTaskFactory factory,
  ) {
    final CallbackHandle? callbackHandle = PluginUtilities.getCallbackHandle(
      factory,
    );
    if (callbackHandle == null) {
      throw ArgumentError(
        'Task factory must be a top-level or static function so it can be restored in background isolate.',
      );
    }
    return SmartTaskFactoryHandle(callbackHandle.toRawHandle());
  }
}
