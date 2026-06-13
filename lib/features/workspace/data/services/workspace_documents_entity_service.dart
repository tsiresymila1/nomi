import 'dart:async';

import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/workspace/presentation/cubit/selected_workspace_cubit.dart';
import 'package:gena/features/workspace/data/models/workspace_document_entity.dart';
import 'package:gena/features/workspace/data/models/workspace_document_ingestion_status.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_ingestion_queue.dart';

class WorkspaceDocumentsRepository {
  WorkspaceDocumentsRepository({
    required db.GenaDatabase database,
    required SelectedWorkspaceCubit selectedWorkspaceCubit,
    required WorkspaceRagIngestionQueue ingestionQueue,
    AppCapabilities? capabilities,
  }) : _database = database,
       _selectedWorkspaceCubit = selectedWorkspaceCubit,
       _ingestionQueue = ingestionQueue,
       _capabilities = capabilities ?? AppCapabilities.current;

  final db.GenaDatabase _database;
  final SelectedWorkspaceCubit _selectedWorkspaceCubit;
  final WorkspaceRagIngestionQueue _ingestionQueue;
  final AppCapabilities _capabilities;

  Stream<List<WorkspaceDocumentEntity>> watchWorkspaceDocuments(
    String workspaceId,
  ) {
    if (_capabilities.supportsWorkspaceRag) {
      unawaited(_ingestionQueue.resumePending());
    }

    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) {
      return Stream<List<WorkspaceDocumentEntity>>.value(
        const <WorkspaceDocumentEntity>[],
      );
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

  Stream<List<WorkspaceDocumentEntity>> watchActiveWorkspaceDocuments() {
    late final StreamController<List<WorkspaceDocumentEntity>> controller;
    StreamSubscription<String?>? selectedSub;
    StreamSubscription<List<WorkspaceDocumentEntity>>? docsSub;

    Future<void> rebind(String? workspaceId) async {
      await docsSub?.cancel();
      if (workspaceId == null) {
        if (!controller.isClosed) {
          controller.add(const <WorkspaceDocumentEntity>[]);
        }
        return;
      }
      docsSub = watchWorkspaceDocuments(workspaceId).listen((items) {
        if (!controller.isClosed) {
          controller.add(items);
        }
      });
    }

    controller = StreamController<List<WorkspaceDocumentEntity>>.broadcast(
      onListen: () {
        unawaited(rebind(_selectedWorkspaceCubit.state));
        selectedSub = _selectedWorkspaceCubit.stream.listen((workspaceId) {
          unawaited(rebind(workspaceId));
        });
      },
      onCancel: () async {
        await docsSub?.cancel();
        await selectedSub?.cancel();
      },
    );

    return controller.stream;
  }
}
