import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/features/workspace/data/models/workspace_memory_entity.dart';
import 'package:gena/features/workspace/presentation/cubit/workspace_config_cubit.dart';
import 'package:gena/features/workspace/presentation/cubit/workspace_config_state.dart';
import 'package:gena/features/workspace/presentation/services/workspace_config_actions.dart';
import 'package:gena/features/workspace/presentation/widgets/workspace_documents_list.dart';
import 'package:gena/features/workspace/presentation/widgets/workspace_embedder_status_card.dart';
import 'package:gena/features/workspace/presentation/widgets/workspace_native_tools_list_card.dart';
import 'package:go_router/go_router.dart';

class WorkspaceConfigForm extends StatefulWidget {
  const WorkspaceConfigForm({super.key});

  @override
  State<WorkspaceConfigForm> createState() => _WorkspaceConfigFormState();
}

class _WorkspaceConfigFormState extends State<WorkspaceConfigForm> {
  late final TextEditingController _memoryController;

  @override
  void initState() {
    super.initState();
    _memoryController = TextEditingController();
  }

  @override
  void dispose() {
    _memoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkspaceConfigCubit, WorkspaceConfigState>(
      builder: (context, state) {
        final cubit = context.read<WorkspaceConfigCubit>();
        final capabilities = cubit.capabilities;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.edit_note_rounded),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'General prompt',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.instruction.trim().isEmpty
                            ? 'No custom prompt. Nomi will use the default instructions.'
                            : state.instruction.trim(),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _openPromptEditor(
                          context,
                          cubit,
                          state.instruction,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Edit Markdown prompt'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: state.ragEnabled,
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable RAG'),
                subtitle: Text(
                  !capabilities.supportsWorkspaceRag
                      ? capabilities.workspaceRagUnavailableMessage
                      : state.ragEnabled
                      ? 'RAG runs an on-device engine. Status: ${state.embedderState.message}'
                      : 'Use workspace documents as retrieval context in chat.',
                ),
                onChanged: capabilities.supportsWorkspaceRag
                    ? cubit.setRagEnabled
                    : null,
              ),
              if (capabilities.supportsWorkspaceRag && state.ragEnabled) ...[
                const SizedBox(height: 8),
                WorkspaceEmbedderStatusCard(
                  state: state.embedderState,
                  onInstallPressed: () =>
                      unawaited(WorkspaceConfigActions.installEmbedder(cubit)),
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                value: state.nativeToolsEnabled,
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable Native Action Tools'),
                subtitle: const Text(
                  'Allow model tool calls to request device actions with user approval sheet.',
                ),
                onChanged: cubit.setNativeToolsEnabled,
              ),
              SwitchListTile(
                value: state.nativeOpenUrlEnabled,
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow open URL'),
                subtitle: const Text('Native tool: open external link'),
                onChanged: state.nativeToolsEnabled
                    ? cubit.setNativeOpenUrlEnabled
                    : null,
              ),
              SwitchListTile(
                value: state.nativeOpenAppEnabled,
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow open app'),
                subtitle: const Text('Native tool: launch app URI/deep link'),
                onChanged: state.nativeToolsEnabled
                    ? cubit.setNativeOpenAppEnabled
                    : null,
              ),
              SwitchListTile(
                value: state.nativeSendEmailEnabled,
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow send email'),
                subtitle: const Text('Native tool: compose email via mail app'),
                onChanged: state.nativeToolsEnabled
                    ? cubit.setNativeSendEmailEnabled
                    : null,
              ),
              SwitchListTile(
                value: state.nativeFlashlightEnabled,
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow flashlight'),
                subtitle: const Text('Native tool: turn flashlight on/off'),
                onChanged: state.nativeToolsEnabled
                    ? cubit.setNativeFlashlightEnabled
                    : null,
              ),
              const SizedBox(height: 4),
              WorkspaceNativeToolsListCard(
                allEnabled: state.nativeToolsEnabled,
                openUrlEnabled: state.nativeOpenUrlEnabled,
                openAppEnabled: state.nativeOpenAppEnabled,
                sendEmailEnabled: state.nativeSendEmailEnabled,
                flashlightEnabled: state.nativeFlashlightEnabled,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: capabilities.supportsMcp && state.mcpEnabled,
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable MCP tools'),
                subtitle: const Text(
                  'Expose tools from connected MCP servers to the model. '
                  'Each MCP tool call requires user approval.',
                ),
                onChanged: capabilities.supportsMcp
                    ? cubit.setMcpEnabled
                    : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: state.memoryEnabled,
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable persistent memory'),
                subtitle: const Text(
                  'Let the assistant remember durable facts about you across '
                  'chats in this workspace, and inject them automatically.',
                ),
                onChanged: cubit.setMemoryEnabled,
              ),
              if (state.memoryEnabled) ...[
                const SizedBox(height: 8),
                _MemorySection(
                  memories: state.memories,
                  controller: _memoryController,
                  onAdd: () {
                    final text = _memoryController.text.trim();
                    if (text.isEmpty) return;
                    unawaited(cubit.addMemory(text));
                    _memoryController.clear();
                  },
                  onDelete: (id) => unawaited(cubit.deleteMemory(id)),
                ),
              ],
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
                    onPressed:
                        !capabilities.supportsWorkspaceRag || state.isImporting
                        ? null
                        : () => unawaited(
                            WorkspaceConfigActions.importDocument(
                              context,
                              cubit,
                            ),
                          ),
                    icon: state.isImporting
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
              WorkspaceDocumentsList(
                documents: state.documents,
                retryEnabled: capabilities.supportsWorkspaceRag,
                onRetry: (document) => unawaited(
                  WorkspaceConfigActions.retryDocument(
                    context,
                    cubit,
                    document,
                  ),
                ),
                onDelete: (document) => unawaited(
                  WorkspaceConfigActions.deleteDocument(
                    context,
                    cubit,
                    document,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: state.isSaving
                      ? null
                      : () => unawaited(WorkspaceConfigActions.save(cubit)),
                  child: state.isSaving
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
        );
      },
    );
  }

  Future<void> _openPromptEditor(
    BuildContext context,
    WorkspaceConfigCubit cubit,
    String instruction,
  ) async {
    final result = await context.pushNamed<String>(
      'workspace-prompt-editor',
      extra: instruction,
    );
    if (!mounted || result == null) return;
    cubit.setInstruction(result);
  }
}

class _MemorySection extends StatelessWidget {
  const _MemorySection({
    required this.memories,
    required this.controller,
    required this.onAdd,
    required this.onDelete,
  });

  final List<WorkspaceMemoryEntity>? memories;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final void Function(int id) onDelete;

  @override
  Widget build(BuildContext context) {
    final items = memories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Remembered facts',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Add a fact to remember',
                  isDense: true,
                ),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (items.isEmpty)
          Text(
            'No remembered facts yet.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          )
        else
          Column(
            children: [
              for (final memory in items)
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      memory.content,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      tooltip: 'Forget',
                      onPressed: () => onDelete(memory.id),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
