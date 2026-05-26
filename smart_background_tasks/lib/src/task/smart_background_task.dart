import 'smart_task_context.dart';
import 'smart_task_step.dart';

abstract class SmartBackgroundTask {
  Future<void> onStart(SmartTaskContext context) async {}

  Future<SmartTaskStep> onTick(SmartTaskContext context);

  Future<void> onPause(SmartTaskContext context) async {}

  Future<void> onResume(SmartTaskContext context) async {}

  Future<void> onCancel(SmartTaskContext context) async {}
}

typedef SmartBackgroundTaskFactory = SmartBackgroundTask Function();
