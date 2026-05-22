enum WorkspaceEmbedderInstallPhase {
  idle,
  checking,
  downloading,
  ready,
  failed,
}

class WorkspaceEmbedderInstallState {
  final WorkspaceEmbedderInstallPhase phase;
  final int modelProgress;
  final int tokenizerProgress;
  final String message;
  final String? error;

  const WorkspaceEmbedderInstallState({
    required this.phase,
    required this.modelProgress,
    required this.tokenizerProgress,
    required this.message,
    required this.error,
  });

  const WorkspaceEmbedderInstallState.idle()
    : this(
        phase: WorkspaceEmbedderInstallPhase.idle,
        modelProgress: 0,
        tokenizerProgress: 0,
        message: 'Embedder not checked yet',
        error: null,
      );

  WorkspaceEmbedderInstallState copyWith({
    WorkspaceEmbedderInstallPhase? phase,
    int? modelProgress,
    int? tokenizerProgress,
    String? message,
    String? error,
    bool clearError = false,
  }) {
    return WorkspaceEmbedderInstallState(
      phase: phase ?? this.phase,
      modelProgress: modelProgress ?? this.modelProgress,
      tokenizerProgress: tokenizerProgress ?? this.tokenizerProgress,
      message: message ?? this.message,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
