import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/features/workspace/data/models/workspace_document_entity.dart';
import 'package:gena/features/workspace/data/models/workspace_document_ingestion_status.dart';
import 'package:gena/features/workspace/data/providers/workspace_rag_core_provider.dart';
import 'package:gena/features/workspace/data/providers/selected_workspace_provider.dart';

final workspaceDocumentsProvider =
    StreamProvider.family<List<WorkspaceDocumentEntity>, String>((
      ref,
      workspaceId,
    ) {
      ref.read(workspaceRagIngestionBootstrapProvider);

      final parsedWorkspaceId = int.tryParse(workspaceId);
      if (parsedWorkspaceId == null) {
        return Stream.value(const <WorkspaceDocumentEntity>[]);
      }

      final database = ref.watch(genaDatabaseProvider);
      final query = database.select(database.workspaceDocuments)
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
    });

final activeWorkspaceDocumentsProvider =
    Provider<AsyncValue<List<WorkspaceDocumentEntity>>>((ref) {
      final workspaceId = ref.watch(selectedWorkspaceIdProvider);
      if (workspaceId == null) {
        return const AsyncValue.data(<WorkspaceDocumentEntity>[]);
      }
      return ref.watch(workspaceDocumentsProvider(workspaceId));
    });
