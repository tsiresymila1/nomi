import 'package:gena/features/workspace/data/models/workspace_document_entity.dart';
import 'package:gena/features/workspace/data/models/workspace_embedder_install_state.dart';
import 'package:gena/features/workspace/data/models/workspace_entity.dart';
import 'package:gena/features/workspace/data/models/workspace_memory_entity.dart';

class WorkspaceConfigState {
  const WorkspaceConfigState({
    required this.workspaceLoading,
    required this.workspace,
    required this.documents,
    required this.memories,
    required this.embedderState,
    required this.isSaving,
    required this.isImporting,
    required this.instruction,
    required this.ragEnabled,
    required this.nativeToolsEnabled,
    required this.nativeOpenUrlEnabled,
    required this.nativeOpenAppEnabled,
    required this.nativeSendEmailEnabled,
    required this.nativeFlashlightEnabled,
    required this.mcpEnabled,
    required this.memoryEnabled,
    required this.hydratedWorkspaceId,
  });

  factory WorkspaceConfigState.initial() {
    return const WorkspaceConfigState(
      workspaceLoading: true,
      workspace: null,
      documents: null,
      memories: null,
      embedderState: WorkspaceEmbedderInstallState.idle(),
      isSaving: false,
      isImporting: false,
      instruction: '',
      ragEnabled: false,
      nativeToolsEnabled: true,
      nativeOpenUrlEnabled: true,
      nativeOpenAppEnabled: true,
      nativeSendEmailEnabled: true,
      nativeFlashlightEnabled: true,
      mcpEnabled: false,
      memoryEnabled: true,
      hydratedWorkspaceId: null,
    );
  }

  final bool workspaceLoading;
  final WorkspaceEntity? workspace;
  final List<WorkspaceDocumentEntity>? documents;
  final List<WorkspaceMemoryEntity>? memories;
  final WorkspaceEmbedderInstallState embedderState;
  final bool isSaving;
  final bool isImporting;
  final String instruction;
  final bool ragEnabled;
  final bool nativeToolsEnabled;
  final bool nativeOpenUrlEnabled;
  final bool nativeOpenAppEnabled;
  final bool nativeSendEmailEnabled;
  final bool nativeFlashlightEnabled;
  final bool mcpEnabled;
  final bool memoryEnabled;
  final String? hydratedWorkspaceId;

  bool get workspaceNotFound => !workspaceLoading && workspace == null;

  WorkspaceConfigState copyWith({
    bool? workspaceLoading,
    WorkspaceEntity? workspace,
    bool clearWorkspace = false,
    List<WorkspaceDocumentEntity>? documents,
    List<WorkspaceMemoryEntity>? memories,
    WorkspaceEmbedderInstallState? embedderState,
    bool? isSaving,
    bool? isImporting,
    String? instruction,
    bool? ragEnabled,
    bool? nativeToolsEnabled,
    bool? nativeOpenUrlEnabled,
    bool? nativeOpenAppEnabled,
    bool? nativeSendEmailEnabled,
    bool? nativeFlashlightEnabled,
    bool? mcpEnabled,
    bool? memoryEnabled,
    String? hydratedWorkspaceId,
    bool clearHydratedWorkspaceId = false,
  }) {
    return WorkspaceConfigState(
      workspaceLoading: workspaceLoading ?? this.workspaceLoading,
      workspace: clearWorkspace ? null : workspace ?? this.workspace,
      documents: documents ?? this.documents,
      memories: memories ?? this.memories,
      embedderState: embedderState ?? this.embedderState,
      isSaving: isSaving ?? this.isSaving,
      isImporting: isImporting ?? this.isImporting,
      instruction: instruction ?? this.instruction,
      ragEnabled: ragEnabled ?? this.ragEnabled,
      nativeToolsEnabled: nativeToolsEnabled ?? this.nativeToolsEnabled,
      nativeOpenUrlEnabled: nativeOpenUrlEnabled ?? this.nativeOpenUrlEnabled,
      nativeOpenAppEnabled: nativeOpenAppEnabled ?? this.nativeOpenAppEnabled,
      nativeSendEmailEnabled:
          nativeSendEmailEnabled ?? this.nativeSendEmailEnabled,
      nativeFlashlightEnabled:
          nativeFlashlightEnabled ?? this.nativeFlashlightEnabled,
      mcpEnabled: mcpEnabled ?? this.mcpEnabled,
      memoryEnabled: memoryEnabled ?? this.memoryEnabled,
      hydratedWorkspaceId: clearHydratedWorkspaceId
          ? null
          : hydratedWorkspaceId ?? this.hydratedWorkspaceId,
    );
  }
}
