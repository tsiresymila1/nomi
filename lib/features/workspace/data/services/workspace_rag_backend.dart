import 'package:gena/features/workspace/data/models/workspace_rag_result.dart';

/// A parsed workspace document to ingest into a workspace RAG collection.
class WorkspaceRagDocument {
  const WorkspaceRagDocument({
    required this.documentId,
    required this.name,
    required this.sourceType,
    required this.sourcePath,
    required this.content,
  });

  final int documentId;
  final String name;
  final String sourceType;
  final String sourcePath;
  final String content;
}

/// Result of ingesting a [WorkspaceRagDocument] into a workspace collection.
class WorkspaceRagIngestResult {
  const WorkspaceRagIngestResult({
    required this.sourceId,
    required this.chunkCount,
  });

  /// Engine-owned source id used to remove/replace the document later.
  final int sourceId;

  /// Number of chunks the engine produced for the document.
  final int chunkCount;
}

/// App-facing boundary over the underlying RAG engine.
///
/// Every operation is scoped to a single workspace via a stable workspace id
/// so that ingestion, removal, rebuild, and search never leak across
/// workspaces. The native implementation maps each workspace to a
/// `workspace_<id>` collection; the unsupported implementation rejects all
/// operations on platforms without local RAG support.
abstract interface class WorkspaceRagBackend {
  /// Initialize the engine once. Safe to call repeatedly.
  Future<void> ensureReady();

  /// Ingest [document] into the [workspaceId] collection and return the
  /// engine source id and chunk count to persist on the app document row.
  Future<WorkspaceRagIngestResult> addDocument(
    String workspaceId,
    WorkspaceRagDocument document,
  );

  /// Remove a previously-ingested source from the [workspaceId] collection.
  Future<void> removeDocument(String workspaceId, int sourceId);

  /// Rebuild only the [workspaceId] collection index.
  Future<void> rebuildWorkspace(String workspaceId);

  /// Search only within the [workspaceId] collection, translating engine hits
  /// into provider-neutral [WorkspaceRagResult]s and filtering out hits below
  /// [threshold].
  Future<List<WorkspaceRagResult>> search(
    String workspaceId,
    String query, {
    required int topK,
    required double threshold,
  });
}

/// Stable collection name for a workspace.
String workspaceRagCollectionId(String workspaceId) => 'workspace_$workspaceId';
