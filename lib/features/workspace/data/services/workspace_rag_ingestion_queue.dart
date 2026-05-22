import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/features/workspace/data/models/workspace_document_ingestion_status.dart';
import 'package:gena/features/workspace/data/providers/workspace_rag_core_provider.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_vector_store.dart';

class WorkspaceRagIngestionQueue {
  WorkspaceRagIngestionQueue(this.ref);

  final Ref ref;

  final List<int> _queue = <int>[];
  final Set<int> _queuedSet = <int>{};
  bool _draining = false;

  Future<void> enqueue(int documentId) async {
    if (_queuedSet.add(documentId)) {
      _queue.add(documentId);
    }
    unawaited(_drain());
  }

  Future<void> resumePending() async {
    final database = ref.read(genaDatabaseProvider);
    final rows =
        await (database.select(database.workspaceDocuments)..where(
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
    final database = ref.read(genaDatabaseProvider);
    final parser = ref.read(workspaceDocumentParserProvider);

    final row =
        await (database.select(database.workspaceDocuments)
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
      final parsed = await parser.parseStoredSource(
        sourcePath: row.sourcePath,
        sourceType: row.sourceType,
      );

      await (database.update(
        database.workspaceDocuments,
      )..where((t) => t.id.equals(documentId))).write(
        db.WorkspaceDocumentsCompanion(
          content: Value(parsed.content),
          chunkCount: Value(parsed.chunks.length),
          ingestionError: const Value(null),
          ingestionStatus: Value(WorkspaceDocumentIngestionStatus.ready.value),
        ),
      );
      await _rebuildReadyIndex();
    } catch (e, stackTrace) {
      logger.e(
        'Workspace RAG ingestion failed for document=$documentId',
        error: e,
        stackTrace: stackTrace,
      );
      await _setStatus(
        documentId,
        WorkspaceDocumentIngestionStatus.failed,
        error: e.toString(),
      );
      await _rebuildReadyIndex();
    }
  }

  Future<void> _setStatus(
    int documentId,
    WorkspaceDocumentIngestionStatus status, {
    String? error,
  }) async {
    final database = ref.read(genaDatabaseProvider);
    await (database.update(
      database.workspaceDocuments,
    )..where((t) => t.id.equals(documentId))).write(
      db.WorkspaceDocumentsCompanion(
        ingestionStatus: Value(status.value),
        ingestionError: Value(error),
      ),
    );
  }

  Future<void> _rebuildReadyIndex() async {
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
}
