import 'dart:async';

import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_ingestion_queue.dart';

class WorkspaceRagIngestionBootstrap {
  WorkspaceRagIngestionBootstrap(this._queue, {AppCapabilities? capabilities})
    : _capabilities = capabilities ?? AppCapabilities.current;

  final WorkspaceRagIngestionQueue _queue;
  final AppCapabilities _capabilities;
  bool _started = false;

  void ensureStarted() {
    _capabilities.requireWorkspaceRag();
    if (_started) return;
    _started = true;
    unawaited(_queue.resumePending());
  }
}
