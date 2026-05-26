class SmartTaskStep {
  const SmartTaskStep._({
    this.progress,
    this.message,
    this.error,
    required this.isCompleted,
    required this.isFailed,
  });

  final double? progress;
  final String? message;
  final String? error;
  final bool isCompleted;
  final bool isFailed;

  factory SmartTaskStep.progress({double? progress, String? message}) {
    return SmartTaskStep._(
      progress: progress,
      message: message,
      isCompleted: false,
      isFailed: false,
    );
  }

  factory SmartTaskStep.completed({String? message}) {
    return SmartTaskStep._(
      progress: 1,
      message: message,
      isCompleted: true,
      isFailed: false,
    );
  }

  factory SmartTaskStep.failed({required String error, String? message}) {
    return SmartTaskStep._(
      message: message,
      error: error,
      isCompleted: false,
      isFailed: true,
    );
  }
}
