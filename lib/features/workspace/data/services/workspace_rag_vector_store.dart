import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

class WorkspaceRagReindexDocument {
  final String workspaceId;
  final int documentId;
  final String sourceType;
  final String name;
  final List<String> chunks;

  const WorkspaceRagReindexDocument({
    required this.workspaceId,
    required this.documentId,
    required this.sourceType,
    required this.name,
    required this.chunks,
  });
}

class WorkspaceRagVectorStore {
  static const _dbName = 'gena_workspace_rag.db';

  bool _ready = false;

  Future<void> ensureReady() async {
    if (_ready) return;

    if (!FlutterGemma.hasActiveEmbedder()) {
      throw StateError(
        'No embedding model is active. Install/select an embedder first.',
      );
    }

    await FlutterGemma.getActiveEmbedder();
    final databasePath = await _resolveVectorDatabasePath();
    await FlutterGemmaPlugin.instance.initializeVectorStore(databasePath);
    _ready = true;
  }

  Future<void> addDocumentChunks({
    required String workspaceId,
    required int documentId,
    required String sourceType,
    required String name,
    required List<String> chunks,
  }) async {
    if (chunks.isEmpty) return;
    await ensureReady();

    for (var index = 0; index < chunks.length; index++) {
      final text = chunks[index].trim();
      if (text.isEmpty) continue;
      final metadata = jsonEncode({
        'workspace_id': workspaceId,
        'document_id': documentId,
        'chunk_index': index,
        'source_type': sourceType,
        'name': name,
      });
      await FlutterGemmaPlugin.instance.addDocument(
        id: _chunkId(documentId, index),
        content: text,
        metadata: metadata,
      );
    }
  }

  Future<void> rebuildIndex(List<WorkspaceRagReindexDocument> documents) async {
    await ensureReady();
    await FlutterGemmaPlugin.instance.clearVectorStore();

    for (final document in documents) {
      await addDocumentChunks(
        workspaceId: document.workspaceId,
        documentId: document.documentId,
        sourceType: document.sourceType,
        name: document.name,
        chunks: document.chunks,
      );
    }
  }

  Future<List<RetrievalResult>> searchWorkspace({
    required String workspaceId,
    required String query,
    int topK = 4,
    double threshold = 0.15,
  }) async {
    final cleanedQuery = query.trim();
    if (cleanedQuery.isEmpty) return const [];

    await ensureReady();

    return FlutterGemmaPlugin.instance.searchSimilar(
      query: cleanedQuery,
      topK: topK,
      threshold: threshold,
      filter: Filter(
        must: [FieldEquals(key: 'workspace_id', value: workspaceId)],
      ),
    );
  }

  Future<String> _resolveVectorDatabasePath() async {
    if (kIsWeb) {
      return _dbName;
    }
    final supportDir = await getApplicationSupportDirectory();
    return '${supportDir.path}/$_dbName';
  }

  String _chunkId(int documentId, int chunkIndex) {
    return 'wsdoc_${documentId}_chunk_$chunkIndex';
  }
}
