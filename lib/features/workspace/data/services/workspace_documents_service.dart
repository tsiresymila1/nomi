import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/workspace/data/models/workspace_document_entity.dart';
import 'package:gena/features/workspace/data/models/workspace_document_ingestion_status.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_ingestion_bootstrap.dart';

class WorkspaceDocumentsService {
  WorkspaceDocumentsService({
    required db.GenaDatabase database,
    required WorkspaceRagIngestionBootstrap ingestionBootstrap,
  }) : _database = database,
       _ingestionBootstrap = ingestionBootstrap;

  final db.GenaDatabase _database;
  final WorkspaceRagIngestionBootstrap _ingestionBootstrap;

  Stream<List<WorkspaceDocumentEntity>> watchWorkspaceDocuments(
    String workspaceId,
  ) {
    _ingestionBootstrap.ensureStarted();

    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) {
      return Stream.value(const <WorkspaceDocumentEntity>[]);
    }

    final query = _database.select(_database.workspaceDocuments)
      ..where((t) => t.workspace.equals(parsedWorkspaceId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => WorkspaceDocumentEntity(
              id: row.id,
              workspaceId: row.workspace.toString(),
              name: row.name,
              sourceType: row.sourceType,
              sourcePath: row.sourcePath,
              content: row.content,
              ingestionStatus: WorkspaceDocumentIngestionStatus.fromDb(
                row.ingestionStatus,
              ),
              ingestionError: row.ingestionError,
              chunkCount: row.chunkCount,
              createdAt: row.createdAt,
            ),
          )
          .toList(growable: false),
    );
  }
}
