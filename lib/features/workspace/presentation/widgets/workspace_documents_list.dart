import 'package:flutter/material.dart';
import 'package:gena/features/workspace/data/models/workspace_document_entity.dart';
import 'package:gena/features/workspace/data/models/workspace_document_ingestion_status.dart';

class WorkspaceDocumentsList extends StatelessWidget {
  const WorkspaceDocumentsList({
    super.key,
    required this.documents,
    required this.onRetry,
    required this.onDelete,
  });

  final List<WorkspaceDocumentEntity>? documents;
  final ValueChanged<WorkspaceDocumentEntity> onRetry;
  final ValueChanged<WorkspaceDocumentEntity> onDelete;

  @override
  Widget build(BuildContext context) {
    final docs = documents;
    if (docs == null) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (docs.isEmpty) {
      return const Text(
        'No documents yet. Add PDF or text files to enable retrieval.',
        style: TextStyle(fontSize: 12),
      );
    }

    return Column(
      children: [
        for (final document in docs)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              document.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              '${document.sourceType.toUpperCase()} · ${_statusLabel(document)}',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (document.ingestionStatus ==
                        WorkspaceDocumentIngestionStatus.queued ||
                    document.ingestionStatus ==
                        WorkspaceDocumentIngestionStatus.processing)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (document.ingestionStatus ==
                    WorkspaceDocumentIngestionStatus.failed)
                  IconButton(
                    tooltip: 'Retry ingestion',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => onRetry(document),
                  ),
                IconButton(
                  tooltip: 'Delete document',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => onDelete(document),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _statusLabel(WorkspaceDocumentEntity document) {
    return switch (document.ingestionStatus) {
      WorkspaceDocumentIngestionStatus.queued => 'Queued',
      WorkspaceDocumentIngestionStatus.processing => 'Processing',
      WorkspaceDocumentIngestionStatus.ready =>
        '${document.chunkCount} chunks ready',
      WorkspaceDocumentIngestionStatus.failed =>
        'Failed: ${document.ingestionError ?? 'Unknown error'}',
    };
  }
}
