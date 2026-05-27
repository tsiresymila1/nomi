import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/features/workspace/presentation/cubit/workspace_config_cubit.dart';
import 'package:gena/features/workspace/presentation/cubit/workspace_config_state.dart';
import 'package:gena/features/workspace/presentation/services/workspace_config_actions.dart';
import 'package:gena/features/workspace/presentation/widgets/workspace_documents_list.dart';
import 'package:gena/features/workspace/presentation/widgets/workspace_embedder_status_card.dart';
import 'package:gena/features/workspace/presentation/widgets/workspace_native_tools_list_card.dart';

class WorkspaceConfigForm extends StatefulWidget {
  const WorkspaceConfigForm({super.key});

  @override
  State<WorkspaceConfigForm> createState() => _WorkspaceConfigFormState();
}

class _WorkspaceConfigFormState extends State<WorkspaceConfigForm> {
  late final TextEditingController _instructionController;

  @override
  void initState() {
    super.initState();
    _instructionController = TextEditingController();
  }

  @override
  void dispose() {
    _instructionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkspaceConfigCubit, WorkspaceConfigState>(
      builder: (context, state) {
        if (_instructionController.text != state.instruction) {
          _instructionController.value = TextEditingValue(
            text: state.instruction,
            selection: TextSelection.collapsed(offset: state.instruction.length),
          );
        }

        final cubit = context.read<WorkspaceConfigCubit>();
        return SingleChildScrollView(
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
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(hintText: 'Workspace prompt'),
                onChanged: cubit.setInstruction,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: state.ragEnabled,
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable RAG'),
                subtitle: Text(
                  state.ragEnabled
                      ? 'RAG uses an embedding model. Status: ${state.embedderState.message}'
                      : 'Use workspace documents as retrieval context in chat.',
                ),
                onChanged: cubit.setRagEnabled,
              ),
              if (state.ragEnabled) ...[
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
                onChanged:
                    state.nativeToolsEnabled ? cubit.setNativeOpenUrlEnabled : null,
              ),
              SwitchListTile(
                value: state.nativeOpenAppEnabled,
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow open app'),
                subtitle: const Text('Native tool: launch app URI/deep link'),
                onChanged:
                    state.nativeToolsEnabled ? cubit.setNativeOpenAppEnabled : null,
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
                    onPressed: state.isImporting
                        ? null
                        : () => unawaited(
                            WorkspaceConfigActions.importDocument(context, cubit),
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
                onRetry: (document) => unawaited(
                  WorkspaceConfigActions.retryDocument(context, cubit, document),
                ),
                onDelete: (document) => unawaited(
                  WorkspaceConfigActions.deleteDocument(context, cubit, document),
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
}
