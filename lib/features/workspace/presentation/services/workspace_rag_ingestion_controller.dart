import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/logger.dart';
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/workspace/data/models/workspace_document_ingestion_status.dart';
import 'package:gena/features/workspace/data/services/workspace_document_parser.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_vector_store.dart';

class WorkspaceRagIngestionController {
  WorkspaceRagIngestionController({
    required db.GenaDatabase database,
    required WorkspaceDocumentParser parser,
    required WorkspaceRagVectorStore vectorStore,
    AppCapabilities? capabilities,
  }) : _database = database,
       _parser = parser,
       _vectorStore = vectorStore,
       _capabilities = capabilities ?? AppCapabilities.current;

  final db.GenaDatabase _database;
  final WorkspaceDocumentParser _parser;
  final WorkspaceRagVectorStore _vectorStore;
  final AppCapabilities _capabilities;

  final List<int> _queue = <int>[];
  final Set<int> _queuedSet = <int>{};
  bool _draining = false;

  Future<void> resumePending() async {
    _capabilities.requireWorkspaceRag();

    final rows =
        await (_database.select(_database.workspaceDocuments)..where(
              (t) =>
                  t.ingestionStatus.isIn(const ['queued', 'processing']) |
                  (t.ingestionStatus.equals(
                        WorkspaceDocumentIngestionStatus.ready.value,
                      ) &
                      t.ragSourceId.isNull()),
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
    _capabilities.requireWorkspaceRag();

    if (_queuedSet.add(documentId)) {
      _queue.add(documentId);
    }
    unawaited(_drain());
  }

  Future<void> retryDocumentIngestion(int documentId) async {
    _capabilities.requireWorkspaceRag();

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

    final workspaceId = row.workspace.toString();

    if (_capabilities.supportsWorkspaceRag && row.ragSourceId != null) {
      try {
        await _vectorStore.removeDocument(
          workspaceId: workspaceId,
          sourceId: row.ragSourceId!,
        );
      } catch (error) {
        logger.w('Failed to remove RAG source ${row.ragSourceId}: $error');
      }
    }

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

    if (_capabilities.supportsWorkspaceRag) {
      await _vectorStore.rebuildWorkspace(workspaceId);
    }
  }

  /// Rebuild every workspace collection that has ready documents. Each
  /// workspace is rebuilt independently; no global index is cleared.
  Future<void> rebuildReadyIndex() async {
    _capabilities.requireWorkspaceRag();

    final rows =
        await (_database.select(_database.workspaceDocuments)..where(
              (t) => t.ingestionStatus.equals(
                WorkspaceDocumentIngestionStatus.ready.value,
              ),
            ))
            .get();

    final workspaceIds = <String>{
      for (final row in rows) row.workspace.toString(),
    };

    for (final workspaceId in workspaceIds) {
      await _vectorStore.rebuildWorkspace(workspaceId);
    }
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

    final workspaceId = row.workspace.toString();

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

      if (row.ragSourceId != null) {
        await _vectorStore.removeDocument(
          workspaceId: workspaceId,
          sourceId: row.ragSourceId!,
        );
      }

      final ingest = await _vectorStore.addDocument(
        workspaceId: workspaceId,
        documentId: documentId,
        sourceType: row.sourceType,
        sourcePath: row.sourcePath,
        name: row.name,
        content: parsed.content,
      );

      await (_database.update(
        _database.workspaceDocuments,
      )..where((t) => t.id.equals(documentId))).write(
        db.WorkspaceDocumentsCompanion(
          content: Value(parsed.content),
          chunkCount: Value(ingest.chunkCount),
          ragSourceId: Value(ingest.sourceId),
          ingestionError: const Value(null),
          ingestionStatus: Value(WorkspaceDocumentIngestionStatus.ready.value),
        ),
      );

      await _vectorStore.rebuildWorkspace(workspaceId);
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
