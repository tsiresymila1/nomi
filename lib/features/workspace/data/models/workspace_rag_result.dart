/// Provider-neutral RAG search hit returned by [WorkspaceRagBackend].
///
/// This is the app-owned result type that decouples the rest of the workspace
/// feature (and the chat RAG tool) from any concrete RAG engine. Translations
/// from the underlying engine (e.g. `mobile_rag_engine` hybrid hits) happen in
/// the backend adapter so consumers only ever see this shape.
class WorkspaceRagResult {
  const WorkspaceRagResult({
    required this.id,
    required this.similarity,
    required this.content,
    required this.metadata,
  });

  /// Stable identifier for the hit (engine source id + chunk index).
  final String id;

  /// Relevance score in the range produced by the engine. Higher is better.
  final double similarity;

  /// Chunk text content of the hit.
  final String content;

  /// JSON-encoded metadata carried through ingestion (document id, source
  /// type, source path, name, workspace id).
  final String metadata;
}
