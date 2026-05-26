/// The status of a background task.
enum SmartTaskStatus {
  /// The task has been created but not yet started.
  queued,

  /// The task is currently executing.
  running,

  /// The task has been manually paused.
  paused,

  /// The task completed successfully.
  completed,

  /// The task was manually cancelled.
  cancelled,

  /// The task encountered an error and could not complete.
  failed,
}
