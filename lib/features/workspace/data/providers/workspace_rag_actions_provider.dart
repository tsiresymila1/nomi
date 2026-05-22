import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/features/workspace/data/models/workspace_document_ingestion_status.dart';
import 'package:gena/features/workspace/data/providers/workspace_rag_core_provider.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_vector_store.dart';

final workspaceRagActionsProvider = Provider<WorkspaceRagActions>(
  (ref) => WorkspaceRagActions(ref),
);

class WorkspaceRagActions {
  final Ref ref;
  WorkspaceRagActions(this.ref);

  Future<void> importDocument({
    required String workspaceId,
    required String rawPath,
  }) async {
    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) {
      throw const FormatException('Invalid workspace id');
    }

    final parser = ref.read(workspaceDocumentParserProvider);
    final database = ref.read(genaDatabaseProvider);

    final prepared = await parser.prepareSource(
      workspaceId: workspaceId,
      rawPath: rawPath,
    );

    final insertedId = await database
        .into(database.workspaceDocuments)
        .insert(
          db.WorkspaceDocumentsCompanion.insert(
            workspace: parsedWorkspaceId,
            name: prepared.name,
            sourceType: prepared.sourceType,
            sourcePath: prepared.sourcePath,
            content: '',
            ingestionStatus: Value(
              WorkspaceDocumentIngestionStatus.queued.value,
            ),
            ingestionError: const Value(null),
            chunkCount: const Value(0),
          ),
        );

    await ref.read(workspaceRagIngestionQueueProvider).enqueue(insertedId);
  }

  Future<void> retryDocumentIngestion(int documentId) async {
    final database = ref.read(genaDatabaseProvider);
    await (database.update(
      database.workspaceDocuments,
    )..where((t) => t.id.equals(documentId))).write(
      db.WorkspaceDocumentsCompanion(
        ingestionStatus: Value(WorkspaceDocumentIngestionStatus.queued.value),
        ingestionError: const Value(null),
      ),
    );

    await ref.read(workspaceRagIngestionQueueProvider).enqueue(documentId);
  }

  Future<void> deleteDocument(int documentId) async {
    final database = ref.read(genaDatabaseProvider);

    final row =
        await (database.select(database.workspaceDocuments)
              ..where((t) => t.id.equals(documentId))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return;

    await (database.delete(
      database.workspaceDocuments,
    )..where((t) => t.id.equals(documentId))).go();

    try {
      final file = File(row.sourcePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore file cleanup errors and keep DB source of truth consistent.
    }

    await rebuildAllDocumentsIndex();
  }

  Future<void> rebuildAllDocumentsIndex() async {
    final database = ref.read(genaDatabaseProvider);
    final parser = ref.read(workspaceDocumentParserProvider);
    final vectorStore = ref.read(workspaceRagVectorStoreProvider);

    final rows =
        await (database.select(database.workspaceDocuments)
              ..where(
                (t) => t.ingestionStatus.equals(
                  WorkspaceDocumentIngestionStatus.ready.value,
                ),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();

    final docs = rows
        .where((row) => row.content.trim().isNotEmpty)
        .map(
          (row) => WorkspaceRagReindexDocument(
            workspaceId: row.workspace.toString(),
            documentId: row.id,
            sourceType: row.sourceType,
            name: row.name,
            chunks: parser.splitText(row.content),
          ),
        )
        .toList(growable: false);

    await vectorStore.rebuildIndex(docs);
  }

  Future<Map<String, dynamic>> runRagTool({
    required String workspaceId,
    required String query,
    int topK = 4,
    double threshold = 0.15,
  }) async {
    ref.read(workspaceRagIngestionBootstrapProvider);

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'invalid_query',
        'message': 'Query is empty.',
      };
    }

    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'invalid_workspace',
        'message': 'Workspace id is invalid.',
      };
    }

    final database = ref.read(genaDatabaseProvider);
    final workspace =
        await (database.select(database.workspaces)
              ..where((t) => t.id.equals(parsedWorkspaceId))
              ..limit(1))
            .getSingleOrNull();
    if (workspace == null) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'workspace_not_found',
        'message': 'Workspace not found.',
      };
    }
    if (!workspace.ragEnabled) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'rag_disabled',
        'message': 'RAG is disabled for this workspace.',
      };
    }

    final readyCount =
        await (database.select(database.workspaceDocuments)..where(
              (t) =>
                  t.workspace.equals(parsedWorkspaceId) &
                  t.ingestionStatus.equals(
                    WorkspaceDocumentIngestionStatus.ready.value,
                  ),
            ))
            .get()
            .then((rows) => rows.length);
    if (readyCount == 0) {
      return <String, dynamic>{
        'status': 'success',
        'query': trimmed,
        'hits': const <Map<String, dynamic>>[],
        'message':
            'No indexed workspace documents are ready yet. Import and wait for ingestion.',
      };
    }

    try {
      final vectorStore = ref.read(workspaceRagVectorStoreProvider);
      final results = await vectorStore.searchWorkspace(
        workspaceId: workspaceId,
        query: trimmed,
        topK: topK,
        threshold: threshold,
      );
      return <String, dynamic>{
        'status': 'success',
        'query': trimmed,
        'hits': results
            .map(
              (item) => <String, dynamic>{
                'id': item.id,
                'similarity': item.similarity,
                'content': _normalizeSnippet(item.content),
                'metadata': item.metadata,
              },
            )
            .toList(growable: false),
      };
    } catch (e) {
      logger.w('workspace_rag_search tool failed: $e');
      return <String, dynamic>{
        'status': 'error',
        'error': 'rag_search_failed',
        'message': e.toString(),
      };
    }
  }

  Future<String> buildAugmentedPrompt({
    required String workspaceId,
    required String userPrompt,
  }) async {
    ref.read(workspaceRagIngestionBootstrapProvider);

    final trimmedPrompt = userPrompt.trim();
    if (trimmedPrompt.isEmpty) return userPrompt;

    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) return userPrompt;

    final database = ref.read(genaDatabaseProvider);
    final workspace =
        await (database.select(database.workspaces)
              ..where((t) => t.id.equals(parsedWorkspaceId))
              ..limit(1))
            .getSingleOrNull();
    if (workspace == null || !workspace.ragEnabled) {
      return userPrompt;
    }

    try {
      final vectorStore = ref.read(workspaceRagVectorStoreProvider);
      final results = await vectorStore.searchWorkspace(
        workspaceId: workspaceId,
        query: trimmedPrompt,
      );
      if (results.isEmpty) return userPrompt;

      final snippets = results
          .take(4)
          .map((result) => _normalizeSnippet(result.content))
          .where((snippet) => snippet.isNotEmpty)
          .toList(growable: false);
      if (snippets.isEmpty) return userPrompt;

      final buffer = StringBuffer();
      buffer.writeln(
        'Use the workspace knowledge below only when it is relevant to the user request.',
      );
      buffer.writeln('If it is unrelated, ignore it and answer normally.');
      for (var i = 0; i < snippets.length; i++) {
        buffer.writeln('[$i] ${snippets[i]}');
      }
      buffer.writeln();
      buffer.writeln('User request: $trimmedPrompt');
      return buffer.toString();
    } catch (e) {
      logger.w('RAG search failed, falling back to raw prompt: $e');
      return userPrompt;
    }
  }

  String _normalizeSnippet(String input) {
    final compact = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 900) return compact;
    return '${compact.substring(0, 900)}...';
  }
}
