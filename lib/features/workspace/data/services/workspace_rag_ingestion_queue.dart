import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/logger.dart';
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/workspace/data/models/workspace_document_ingestion_status.dart';
import 'package:gena/features/workspace/data/services/document_processing_foreground_service.dart';
import 'package:gena/features/workspace/data/services/workspace_document_parser.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_vector_store.dart';

class WorkspaceRagIngestionQueue {
  WorkspaceRagIngestionQueue({
    required db.GenaDatabase database,
    required WorkspaceDocumentParser parser,
    required WorkspaceRagVectorStore vectorStore,
    DocumentProcessingForegroundController? foregroundController,
    AppCapabilities? capabilities,
  }) : _database = database,
       _parser = parser,
       _vectorStore = vectorStore,
       _foregroundController =
           foregroundController ??
           const AndroidDocumentProcessingForegroundController(),
       _capabilities = capabilities ?? AppCapabilities.current;

  final db.GenaDatabase _database;
  final WorkspaceDocumentParser _parser;
  final WorkspaceRagVectorStore _vectorStore;
  final DocumentProcessingForegroundController _foregroundController;
  final AppCapabilities _capabilities;

  final List<int> _queue = <int>[];
  final Set<int> _queuedSet = <int>{};
  bool _draining = false;

  Future<void> enqueue(int documentId) async {
    _capabilities.requireWorkspaceRag();

    if (_queuedSet.add(documentId)) {
      _queue.add(documentId);
    }
    unawaited(_drain());
  }

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

    var foregroundStarted = false;
    try {
      final sourceFile = File(row.sourcePath);
      final sizeBytes = await sourceFile.length();
      foregroundStarted = await _foregroundController.startIfNeeded(
        documentName: row.name,
        sizeBytes: sizeBytes,
      );
      final parsed = await _parser.parseStoredSource(
        sourcePath: row.sourcePath,
        sourceType: row.sourceType,
      );

      // Remove an older source id before replacing a re-ingested document so
      // the workspace collection never accumulates stale duplicates.
      if (row.ragSourceId != null) {
        await _vectorStore.removeDocument(
          workspaceId: workspaceId,
          sourceId: row.ragSourceId!,
        );
      }

      if (foregroundStarted) {
        await _foregroundController.update(
          documentName: row.name,
          phase: 'Indexing for private search',
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
    } finally {
      if (foregroundStarted) {
        await _foregroundController.stop();
      }
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
