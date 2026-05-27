import 'dart:async';

import 'package:gena/features/workspace/data/services/workspace_rag_ingestion_queue.dart';

class WorkspaceRagIngestionBootstrap {
  WorkspaceRagIngestionBootstrap(this._queue);

  final WorkspaceRagIngestionQueue _queue;
  bool _started = false;

  void ensureStarted() {
    if (_started) return;
    _started = true;
    unawaited(_queue.resumePending());
  }
}
