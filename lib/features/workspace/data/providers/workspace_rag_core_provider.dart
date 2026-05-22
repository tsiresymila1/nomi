import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/workspace/data/services/workspace_document_parser.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_ingestion_queue.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_vector_store.dart';

final workspaceDocumentParserProvider = Provider<WorkspaceDocumentParser>(
  (ref) => WorkspaceDocumentParser(),
);

final workspaceRagVectorStoreProvider = Provider<WorkspaceRagVectorStore>(
  (ref) => WorkspaceRagVectorStore(),
);

final workspaceRagIngestionQueueProvider = Provider<WorkspaceRagIngestionQueue>(
  (ref) => WorkspaceRagIngestionQueue(ref),
);

final workspaceRagIngestionBootstrapProvider = Provider<void>((ref) {
  unawaited(ref.read(workspaceRagIngestionQueueProvider).resumePending());
});
