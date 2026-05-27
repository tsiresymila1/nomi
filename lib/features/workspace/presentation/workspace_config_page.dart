import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/workspace/data/models/workspace_document_entity.dart';
import 'package:gena/features/workspace/data/models/workspace_document_ingestion_status.dart';
import 'package:gena/features/workspace/data/models/workspace_embedder_install_state.dart';
import 'package:gena/features/workspace/data/models/workspace_entity.dart';
import 'package:gena/features/workspace/data/providers/workspace_config_actions_provider.dart';
import 'package:gena/features/workspace/data/providers/workspace_provider.dart';

class WorkspaceConfigPage extends ConsumerStatefulWidget {
  final String workspaceId;

  const WorkspaceConfigPage({super.key, required this.workspaceId});

  @override
  ConsumerState<WorkspaceConfigPage> createState() =>
      _WorkspaceConfigPageState();
}

class _WorkspaceConfigPageState extends ConsumerState<WorkspaceConfigPage> {
  final _instructionController = TextEditingController();

  bool _hydrated = false;
  String? _hydratedWorkspaceId;
  bool _isSaving = false;
  bool _isImporting = false;
  bool _ragEnabled = false;
  bool _nativeToolsEnabled = true;
  bool _nativeOpenUrlEnabled = true;
  bool _nativeOpenAppEnabled = true;
  bool _nativeSendEmailEnabled = true;
  bool _nativeFlashlightEnabled = true;

  @override
  void dispose() {
    _instructionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ref.read(workspaceRagIngestionBootstrapProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(workspaceEmbedderInstallStateProvider.notifier)
            .refreshStatus(),
      );
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(workspaceConfigActionsProvider)
          .save(
            WorkspaceConfigSaveInput(
              workspaceId: widget.workspaceId,
              generalInstruction: _instructionController.text,
              ragEnabled: _ragEnabled,
              nativeToolsEnabled: _nativeToolsEnabled,
              nativeOpenUrlEnabled: _nativeOpenUrlEnabled,
              nativeOpenAppEnabled: _nativeOpenAppEnabled,
              nativeSendEmailEnabled: _nativeSendEmailEnabled,
              nativeFlashlightEnabled: _nativeFlashlightEnabled,
            ),
          );
      await AppToast.show('Workspace config saved', type: AppToastType.success);
    } on WorkspaceConfigValidationException catch (e) {
      await AppToast.show(e.message, type: AppToastType.error);
    } catch (e) {
      await AppToast.show('Save failed: $e', type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _importDocument() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);
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
      if (path == null || path.trim().isEmpty || !mounted) return;

      await ref
          .read(workspaceRagActionsProvider)
          .importDocument(workspaceId: widget.workspaceId, rawPath: path);
      await AppToast.show(
        'Document queued for background ingestion',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      await AppToast.show('Import failed: $e', type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _deleteDocument(WorkspaceDocumentEntity document) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document'),
        content: Text('Remove "${document.name}" from workspace RAG?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      await ref.read(workspaceRagActionsProvider).deleteDocument(document.id);
      await AppToast.show('Document deleted', type: AppToastType.success);
    } catch (e) {
      if (!mounted) return;
      await AppToast.show('Delete failed: $e', type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspaces = ref.watch(workspaceListProvider).asData?.value;
    if (workspaces == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (workspaces.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    WorkspaceEntity? workspace;
    for (final item in workspaces) {
      if (item.id == widget.workspaceId) {
        workspace = item;
        break;
      }
    }

    if (workspace == null) {
      return const Scaffold(body: Center(child: Text('Workspace not found')));
    }

    if (!_hydrated || _hydratedWorkspaceId != workspace.id) {
      _hydrated = true;
      _hydratedWorkspaceId = workspace.id;
      _instructionController.text = workspace.generalInstruction;
      _ragEnabled = workspace.ragEnabled;
      _nativeToolsEnabled = workspace.nativeToolsEnabled;
      _nativeOpenUrlEnabled = workspace.nativeOpenUrlEnabled;
      _nativeOpenAppEnabled = workspace.nativeOpenAppEnabled;
      _nativeSendEmailEnabled = workspace.nativeSendEmailEnabled;
      _nativeFlashlightEnabled = workspace.nativeFlashlightEnabled;
    }
    final documentsAsync = ref.watch(workspaceDocumentsProvider(workspace.id));
    final embedderState = ref.watch(workspaceEmbedderInstallStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Workspace Config · ${workspace.name}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('General prompt'),
            const SizedBox(height: 8),
            TextField(
              controller: _instructionController,
              minLines: 8,
              maxLines: 16,
              style: TextStyle(fontSize: 13),
              decoration: const InputDecoration(hintText: 'Workspace prompt'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _ragEnabled,
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable RAG'),
              subtitle: Text(
                _ragEnabled
                    ? 'RAG uses an embedding model. Status: ${embedderState.message}'
                    : 'Use workspace documents as retrieval context in chat.',
              ),
              onChanged: (value) {
                setState(() => _ragEnabled = value);
                if (value) {
                  unawaited(
                    ref
                        .read(workspaceEmbedderInstallStateProvider.notifier)
                        .refreshStatus(),
                  );
                }
              },
            ),
            if (_ragEnabled) ...[
              const SizedBox(height: 8),
              _EmbedderStatusCard(state: embedderState),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              value: _nativeToolsEnabled,
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Native Action Tools'),
              subtitle: const Text(
                'Allow model tool calls to request device actions with user approval sheet.',
              ),
              onChanged: (value) => setState(() => _nativeToolsEnabled = value),
            ),
            SwitchListTile(
              value: _nativeOpenUrlEnabled,
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow open URL'),
              subtitle: const Text('Native tool: open external link'),
              onChanged: !_nativeToolsEnabled
                  ? null
                  : (value) => setState(() => _nativeOpenUrlEnabled = value),
            ),
            SwitchListTile(
              value: _nativeOpenAppEnabled,
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow open app'),
              subtitle: const Text('Native tool: launch app URI/deep link'),
              onChanged: !_nativeToolsEnabled
                  ? null
                  : (value) => setState(() => _nativeOpenAppEnabled = value),
            ),
            SwitchListTile(
              value: _nativeSendEmailEnabled,
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow send email'),
              subtitle: const Text('Native tool: compose email via mail app'),
              onChanged: !_nativeToolsEnabled
                  ? null
                  : (value) => setState(() => _nativeSendEmailEnabled = value),
            ),
            SwitchListTile(
              value: _nativeFlashlightEnabled,
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow flashlight'),
              subtitle: const Text('Native tool: turn flashlight on/off'),
              onChanged: !_nativeToolsEnabled
                  ? null
                  : (value) => setState(() => _nativeFlashlightEnabled = value),
            ),
            const SizedBox(height: 4),
            _NativeToolsListCard(
              allEnabled: _nativeToolsEnabled,
              openUrlEnabled: _nativeOpenUrlEnabled,
              openAppEnabled: _nativeOpenAppEnabled,
              sendEmailEnabled: _nativeSendEmailEnabled,
              flashlightEnabled: _nativeFlashlightEnabled,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Workspace documents',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _isImporting
                      ? null
                      : () => unawaited(_importDocument()),
                  icon: _isImporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_rounded),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            documentsAsync.when(
              data: (docs) {
                if (docs.isEmpty) {
                  return const Text(
                    'No documents yet. Add PDF or text files to enable retrieval.',
                    style: TextStyle(fontSize: 12),
                  );
                }
                return Column(
                  children: [
                    for (final doc in docs)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          doc.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          '${doc.sourceType.toUpperCase()} · ${_statusLabel(doc)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (doc.ingestionStatus ==
                                    WorkspaceDocumentIngestionStatus.queued ||
                                doc.ingestionStatus ==
                                    WorkspaceDocumentIngestionStatus.processing)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            if (doc.ingestionStatus ==
                                WorkspaceDocumentIngestionStatus.failed)
                              IconButton(
                                tooltip: 'Retry ingestion',
                                icon: const Icon(Icons.refresh_rounded),
                                onPressed: () => unawaited(
                                  ref
                                      .read(workspaceRagActionsProvider)
                                      .retryDocumentIngestion(doc.id),
                                ),
                              ),
                            IconButton(
                              tooltip: 'Delete document',
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () => unawaited(_deleteDocument(doc)),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (err, _) => Text(
                'Failed to load documents: $err',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : () => unawaited(_save()),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(WorkspaceDocumentEntity doc) {
    return switch (doc.ingestionStatus) {
      WorkspaceDocumentIngestionStatus.queued => 'Queued',
      WorkspaceDocumentIngestionStatus.processing => 'Processing',
      WorkspaceDocumentIngestionStatus.ready =>
        '${doc.chunkCount} chunks ready',
      WorkspaceDocumentIngestionStatus.failed =>
        'Failed: ${doc.ingestionError ?? 'Unknown error'}',
    };
  }
}

class _NativeToolsListCard extends StatelessWidget {
  const _NativeToolsListCard({
    required this.allEnabled,
    required this.openUrlEnabled,
    required this.openAppEnabled,
    required this.sendEmailEnabled,
    required this.flashlightEnabled,
  });

  final bool allEnabled;
  final bool openUrlEnabled;
  final bool openAppEnabled;
  final bool sendEmailEnabled;
  final bool flashlightEnabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabledColor = colorScheme.onSurfaceVariant;

    bool enabled(bool featureEnabled) => allEnabled && featureEnabled;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Native tools list',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _ToolListRow(
            label: 'Open URL',
            enabled: enabled(openUrlEnabled),
            disabledColor: disabledColor,
          ),
          _ToolListRow(
            label: 'Open app / deep link',
            enabled: enabled(openAppEnabled),
            disabledColor: disabledColor,
          ),
          _ToolListRow(
            label: 'Phone call',
            enabled: enabled(openAppEnabled),
            disabledColor: disabledColor,
          ),
          _ToolListRow(
            label: 'Contacts (read/search/create)',
            enabled: enabled(openAppEnabled),
            disabledColor: disabledColor,
          ),
          _ToolListRow(
            label: 'Send SMS',
            enabled: enabled(openAppEnabled),
            disabledColor: disabledColor,
          ),
          _ToolListRow(
            label: 'Send email',
            enabled: enabled(sendEmailEnabled),
            disabledColor: disabledColor,
          ),
          _ToolListRow(
            label: 'Flashlight',
            enabled: enabled(flashlightEnabled),
            disabledColor: disabledColor,
          ),
        ],
      ),
    );
  }
}

class _ToolListRow extends StatelessWidget {
  const _ToolListRow({
    required this.label,
    required this.enabled,
    required this.disabledColor,
  });

  final String label;
  final bool enabled;
  final Color disabledColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.remove_circle_outline,
            size: 16,
            color: enabled ? Colors.green : disabledColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: enabled ? null : disabledColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmbedderStatusCard extends ConsumerWidget {
  final WorkspaceEmbedderInstallState state;

  const _EmbedderStatusCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBusy =
        state.phase == WorkspaceEmbedderInstallPhase.downloading ||
        state.phase == WorkspaceEmbedderInstallPhase.checking;
    final isFailed = state.phase == WorkspaceEmbedderInstallPhase.failed;
    final canInstall =
        state.phase == WorkspaceEmbedderInstallPhase.idle || isFailed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.message,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (isFailed && state.error != null) ...[
            const SizedBox(height: 6),
            Text(
              state.error!,
              style: const TextStyle(fontSize: 11),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (isBusy ||
              state.modelProgress > 0 ||
              state.tokenizerProgress > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Model: ${state.modelProgress}%',
              style: const TextStyle(fontSize: 11),
            ),
            LinearProgressIndicator(value: state.modelProgress / 100),
            const SizedBox(height: 6),
            Text(
              'Tokenizer: ${state.tokenizerProgress}%',
              style: const TextStyle(fontSize: 11),
            ),
            LinearProgressIndicator(value: state.tokenizerProgress / 100),
          ],
          if (canInstall) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => unawaited(
                  ref
                      .read(workspaceEmbedderInstallStateProvider.notifier)
                      .ensureInstalled(),
                ),
                child: const Text('Install embedder'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
