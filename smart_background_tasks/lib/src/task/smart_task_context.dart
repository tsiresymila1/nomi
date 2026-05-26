class SmartTaskContext {
  const SmartTaskContext({
    required this.taskId,
    required this.taskName,
    required this.payload,
  });

  final String taskId;
  final String taskName;
  final Map<String, dynamic> payload;
}
