import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/logger.dart';
import 'package:gena/features/workspace/data/models/workspace_document_ingestion_status.dart';
import 'package:gena/features/workspace/data/services/workspace_document_parser.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_vector_store.dart';

class WorkspaceRagIngestionController {
  WorkspaceRagIngestionController({
    required db.GenaDatabase database,
    required WorkspaceDocumentParser parser,
    required WorkspaceRagVectorStore vectorStore,
  }) : _database = database,
       _parser = parser,
       _vectorStore = vectorStore;

  final db.GenaDatabase _database;
  final WorkspaceDocumentParser _parser;
  final WorkspaceRagVectorStore _vectorStore;

  final List<int> _queue = <int>[];
  final Set<int> _queuedSet = <int>{};
  bool _draining = false;

  Future<void> resumePending() async {
    final rows =
        await (_database.select(_database.workspaceDocuments)..where(
              (t) => t.ingestionStatus.isIn(const ['queued', 'processing']),
            ))
            .get();

    for (final row in rows) {
      if (_queuedSet.add(row.id)) {
        _queue.add(row.id);
      }
    }

    if (rows.isNotEmpty) {
      unawaited(_drain());
    }
  }

  Future<void> enqueue(int documentId) async {
    if (_queuedSet.add(documentId)) {
      _queue.add(documentId);
    }
    unawaited(_drain());
  }

  Future<void> retryDocumentIngestion(int documentId) async {
    await (_database.update(
      _database.workspaceDocuments,
    )..where((t) => t.id.equals(documentId))).write(
      db.WorkspaceDocumentsCompanion(
        ingestionStatus: Value(WorkspaceDocumentIngestionStatus.queued.value),
        ingestionError: const Value(null),
      ),
    );
    await enqueue(documentId);
  }

  Future<void> deleteDocument(int documentId) async {
    final row =
        await (_database.select(_database.workspaceDocuments)
              ..where((t) => t.id.equals(documentId))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return;

    await (_database.delete(
      _database.workspaceDocuments,
    )..where((t) => t.id.equals(documentId))).go();

    try {
      final file = File(row.sourcePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Keep DB source of truth even when file cleanup fails.
    }

    await rebuildReadyIndex();
  }

  Future<void> rebuildReadyIndex() async {
    final rows =
        await (_database.select(_database.workspaceDocuments)
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
            chunks: _parser.splitText(row.content),
          ),
        )
        .toList(growable: false);

    await _vectorStore.rebuildIndex(docs);
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final documentId = _queue.removeAt(0);
        _queuedSet.remove(documentId);
        await _processDocument(documentId);
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _processDocument(int documentId) async {
    final row =
        await (_database.select(_database.workspaceDocuments)
              ..where((t) => t.id.equals(documentId))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return;

    await _setStatus(
      documentId,
      WorkspaceDocumentIngestionStatus.processing,
      error: null,
    );

    try {
      final parsed = await _parser.parseStoredSource(
        sourcePath: row.sourcePath,
        sourceType: row.sourceType,
      );

      await (_database.update(
        _database.workspaceDocuments,
      )..where((t) => t.id.equals(documentId))).write(
        db.WorkspaceDocumentsCompanion(
          content: Value(parsed.content),
          chunkCount: Value(parsed.chunks.length),
          ingestionError: const Value(null),
          ingestionStatus: Value(WorkspaceDocumentIngestionStatus.ready.value),
        ),
      );
      await rebuildReadyIndex();
    } catch (error, stackTrace) {
      logger.e(
        'Workspace RAG ingestion failed for document=$documentId',
        error: error,
        stackTrace: stackTrace,
      );
      await _setStatus(
        documentId,
        WorkspaceDocumentIngestionStatus.failed,
        error: error.toString(),
      );
      await rebuildReadyIndex();
    }
  }

  Future<void> _setStatus(
    int documentId,
    WorkspaceDocumentIngestionStatus status, {
    String? error,
  }) async {
    await (_database.update(
      _database.workspaceDocuments,
    )..where((t) => t.id.equals(documentId))).write(
      db.WorkspaceDocumentsCompanion(
        ingestionStatus: Value(status.value),
        ingestionError: Value(error),
      ),
    );
  }
}
