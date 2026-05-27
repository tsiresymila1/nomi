import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/workspace/data/models/workspace_document_entity.dart';
import 'package:gena/features/workspace/presentation/cubit/workspace_config_cubit.dart';

class WorkspaceConfigActions {
  const WorkspaceConfigActions._();

  static Future<void> save(WorkspaceConfigCubit cubit) async {
    try {
      await cubit.save();
      await AppToast.show('Workspace config saved', type: AppToastType.success);
    } on WorkspaceConfigValidationException catch (error) {
      await AppToast.show(error.message, type: AppToastType.error);
    } catch (error) {
      await AppToast.show('Save failed: $error', type: AppToastType.error);
    }
  }

  static Future<void> installEmbedder(WorkspaceConfigCubit cubit) async {
    try {
      await cubit.ensureEmbedderInstalled();
    } catch (error) {
      await AppToast.show('Install failed: $error', type: AppToastType.error);
    }
  }

  static Future<void> importDocument(
    BuildContext context,
    WorkspaceConfigCubit cubit,
  ) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'txt',
          'md',
          'markdown',
          'text',
          'doc',
          'docx',
        ],
        dialogTitle: 'Choose a document (PDF, DOC/DOCX, text)',
      );
      final path = picked?.files.single.path;
      if (path == null || path.trim().isEmpty || !context.mounted) return;

      await cubit.importDocument(path);
      await AppToast.show(
        'Document queued for background ingestion',
        type: AppToastType.success,
      );
    } catch (error) {
      if (!context.mounted) return;
      await AppToast.show('Import failed: $error', type: AppToastType.error);
    }
  }

  static Future<void> deleteDocument(
    BuildContext context,
    WorkspaceConfigCubit cubit,
    WorkspaceDocumentEntity document,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete document'),
        content: Text('Remove "${document.name}" from workspace RAG?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      await cubit.deleteDocument(document.id);
      await AppToast.show('Document deleted', type: AppToastType.success);
    } catch (error) {
      if (!context.mounted) return;
      await AppToast.show('Delete failed: $error', type: AppToastType.error);
    }
  }

  static Future<void> retryDocument(
    BuildContext context,
    WorkspaceConfigCubit cubit,
    WorkspaceDocumentEntity document,
  ) async {
    try {
      await cubit.retryDocumentIngestion(document.id);
    } catch (error) {
      if (!context.mounted) return;
      await AppToast.show('Retry failed: $error', type: AppToastType.error);
    }
  }
}
