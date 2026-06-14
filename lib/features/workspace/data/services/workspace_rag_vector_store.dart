import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/workspace/data/models/workspace_rag_result.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_backend.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_backend_factory.dart';

/// App-facing RAG boundary. Delegates all storage and retrieval to a
/// platform-selected [WorkspaceRagBackend] (native `mobile_rag_engine` on
/// supported platforms, unsupported elsewhere) while keeping per-workspace
/// isolation and app-owned [WorkspaceRagResult]s.
class WorkspaceRagVectorStore {
  WorkspaceRagVectorStore({
    AppCapabilities? capabilities,
    WorkspaceRagBackend? backend,
  }) : _capabilities = capabilities ?? AppCapabilities.current,
       _backend = backend ?? createWorkspaceRagBackend();

  final AppCapabilities _capabilities;
  final WorkspaceRagBackend _backend;

  Future<void> ensureReady() async {
    _capabilities.requireWorkspaceRag();
    await _backend.ensureReady();
  }

  /// Ingest a single parsed document into its workspace collection and return
  /// the engine source id + chunk count to persist on the app document row.
  Future<WorkspaceRagIngestResult> addDocument({
    required String workspaceId,
    required int documentId,
    required String sourceType,
    required String sourcePath,
    required String name,
    required String content,
  }) async {
    _capabilities.requireWorkspaceRag();
    await ensureReady();
    return _backend.addDocument(
      workspaceId,
      WorkspaceRagDocument(
        documentId: documentId,
        name: name,
        sourceType: sourceType,
        sourcePath: sourcePath,
        content: content,
      ),
    );
  }

  /// Remove a previously-ingested source from its workspace collection.
  Future<void> removeDocument({
    required String workspaceId,
    required int sourceId,
  }) async {
    _capabilities.requireWorkspaceRag();
    await ensureReady();
    await _backend.removeDocument(workspaceId, sourceId);
  }

  /// Rebuild only the given workspace collection. Never clears a global index.
  Future<void> rebuildWorkspace(String workspaceId) async {
    _capabilities.requireWorkspaceRag();
    await ensureReady();
    await _backend.rebuildWorkspace(workspaceId);
  }

  Future<List<WorkspaceRagResult>> searchWorkspace({
    required String workspaceId,
    required String query,
    int topK = 4,
    double threshold = 0.0,
  }) async {
    _capabilities.requireWorkspaceRag();
    final cleanedQuery = query.trim();
    if (cleanedQuery.isEmpty) return const [];

    await ensureReady();
    return _backend.search(
      workspaceId,
      cleanedQuery,
      topK: topK,
      threshold: threshold,
    );
  }
}
