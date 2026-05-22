enum WorkspaceDocumentIngestionStatus {
  queued,
  processing,
  ready,
  failed;

  String get value => name;

  static WorkspaceDocumentIngestionStatus fromDb(String raw) {
    return switch (raw) {
      'queued' => WorkspaceDocumentIngestionStatus.queued,
      'processing' => WorkspaceDocumentIngestionStatus.processing,
      'ready' => WorkspaceDocumentIngestionStatus.ready,
      'failed' => WorkspaceDocumentIngestionStatus.failed,
      _ => WorkspaceDocumentIngestionStatus.ready,
    };
  }
}
