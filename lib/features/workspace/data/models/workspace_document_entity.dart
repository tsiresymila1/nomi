import 'package:gena/features/workspace/data/models/workspace_document_ingestion_status.dart';

class WorkspaceDocumentEntity {
  final int id;
  final String workspaceId;
  final String name;
  final String sourceType;
  final String sourcePath;
  final String content;
  final WorkspaceDocumentIngestionStatus ingestionStatus;
  final String? ingestionError;
  final int chunkCount;
  final DateTime createdAt;

  const WorkspaceDocumentEntity({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.sourceType,
    required this.sourcePath,
    required this.content,
    required this.ingestionStatus,
    required this.ingestionError,
    required this.chunkCount,
    required this.createdAt,
  });
}
