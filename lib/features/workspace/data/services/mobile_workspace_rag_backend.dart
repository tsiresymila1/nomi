import 'dart:convert';

import 'package:gena/features/workspace/data/models/workspace_rag_result.dart';
import 'package:gena/features/workspace/data/services/rag_model_provisioner.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_backend.dart';
import 'package:mobile_rag_engine/mobile_rag_engine.dart';

/// Builds the native `mobile_rag_engine`-backed RAG backend.
WorkspaceRagBackend createWorkspaceRagBackend() => MobileWorkspaceRagBackend();

/// Native workspace RAG backend powered by `mobile_rag_engine`.
///
/// Each workspace maps to a `workspace_<id>` collection so ingest, removal,
/// rebuild, and search are fully isolated per workspace.
class MobileWorkspaceRagBackend implements WorkspaceRagBackend {
  MobileWorkspaceRagBackend({RagModelProvisioner? provisioner})
    : _provisioner = provisioner ?? RagModelProvisioner();

  // Basenames must match the files RagModelProvisioner downloads into the app
  // documents directory, so the engine reuses them instead of loading a bundled
  // asset (the assets are intentionally not shipped).
  static const _tokenizerAsset = 'assets/rag/tokenizer.json';
  static const _modelAsset = 'assets/rag/model.onnx';

  final RagModelProvisioner _provisioner;

  Future<void>? _readyFuture;

  @override
  Future<void> ensureReady() => _readyFuture ??= _initialize();

  Future<void> _initialize() async {
    try {
      await _provisioner.ensure();
      await MobileRag.initialize(
        tokenizerAsset: _tokenizerAsset,
        modelAsset: _modelAsset,
        deferIndexWarmup: true,
      );
    } catch (error) {
      // Allow a later retry (e.g. after the network returns) to re-provision.
      _readyFuture = null;
      rethrow;
    }
  }

  CollectionRag _collection(String workspaceId) =>
      MobileRag.instance.inCollection(workspaceRagCollectionId(workspaceId));

  @override
  Future<WorkspaceRagIngestResult> addDocument(
    String workspaceId,
    WorkspaceRagDocument document,
  ) async {
    await ensureReady();
    final result = await _collection(workspaceId).addDocument(
      document.content,
      name: document.name,
      metadata: _encodeMetadata(workspaceId, document),
    );
    return WorkspaceRagIngestResult(
      sourceId: result.sourceId,
      chunkCount: result.chunkCount,
    );
  }

  @override
  Future<void> removeDocument(String workspaceId, int sourceId) async {
    await ensureReady();
    await _collection(workspaceId).removeSource(sourceId);
  }

  @override
  Future<void> rebuildWorkspace(String workspaceId) async {
    await ensureReady();
    await _collection(workspaceId).rebuildIndex(force: true);
  }

  @override
  Future<List<WorkspaceRagResult>> search(
    String workspaceId,
    String query, {
    required int topK,
    required double threshold,
  }) async {
    await ensureReady();
    final collection = _collection(workspaceId);
    if (!collection.isIndexReady) {
      await collection.warmupFuture;
    }
    final hits = await collection.searchHybrid(query, topK: topK);
    // `score` is an RRF-fused hybrid rank score (typically ~0.01-0.02), not a
    // 0-1 cosine similarity. `topK` already ranks the best hits; the default
    // threshold is 0 so callers keep them. A threshold above ~0.05 discards
    // everything.
    return hits
        .where((hit) => hit.score >= threshold)
        .map(
          (hit) => WorkspaceRagResult(
            id: 'wsdoc_${hit.sourceId.toInt()}_chunk_${hit.chunkIndex}',
            similarity: hit.score,
            content: hit.content,
            metadata: hit.metadata ?? '',
          ),
        )
        .toList(growable: false);
  }

  String _encodeMetadata(String workspaceId, WorkspaceRagDocument document) {
    return jsonEncode({
      'workspace_id': workspaceId,
      'document_id': document.documentId,
      'source_type': document.sourceType,
      'source_path': document.sourcePath,
      'name': document.name,
    });
  }
}
