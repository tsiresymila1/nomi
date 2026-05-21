import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/toast/app_toast.dart';
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

  @override
  void dispose() {
    _instructionController.dispose();
    super.dispose();
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
    }

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
}
