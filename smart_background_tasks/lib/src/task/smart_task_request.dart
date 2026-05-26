import 'smart_task_factory_handle.dart';

class SmartTaskRequest {
  const SmartTaskRequest({
    required this.name,
    required this.factoryHandle,
    this.payload = const <String, dynamic>{},
    this.taskId,
  });

  final String? taskId;
  final String name;
  final SmartTaskFactoryHandle factoryHandle;
  final Map<String, dynamic> payload;
}
