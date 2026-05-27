import 'package:gena/features/chat/data/providers/chat_session_provider.dart';
import 'package:gena/features/workspace/data/cubits/workspace_embedder_install_cubit.dart';
import 'package:gena/features/workspace/data/providers/workspace_actions_provider.dart';

class WorkspaceConfigValidationException implements Exception {
  const WorkspaceConfigValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WorkspaceConfigSaveInput {
  const WorkspaceConfigSaveInput({
    required this.workspaceId,
    required this.generalInstruction,
    required this.ragEnabled,
    required this.nativeToolsEnabled,
    required this.nativeOpenUrlEnabled,
    required this.nativeOpenAppEnabled,
    required this.nativeSendEmailEnabled,
    required this.nativeFlashlightEnabled,
  });

  final String workspaceId;
  final String generalInstruction;
  final bool ragEnabled;
  final bool nativeToolsEnabled;
  final bool nativeOpenUrlEnabled;
  final bool nativeOpenAppEnabled;
  final bool nativeSendEmailEnabled;
  final bool nativeFlashlightEnabled;
}

class WorkspaceConfigActions {
  WorkspaceConfigActions({
    required WorkspaceEmbedderInstallCubit embedderInstallCubit,
    required WorkspaceActions workspaceActions,
    required ChatSessionController chatSessionController,
  }) : _embedderInstallCubit = embedderInstallCubit,
       _workspaceActions = workspaceActions,
       _chatSessionController = chatSessionController;

  final WorkspaceEmbedderInstallCubit _embedderInstallCubit;
  final WorkspaceActions _workspaceActions;
  final ChatSessionController _chatSessionController;

  Future<void> save(WorkspaceConfigSaveInput input) async {
    if (input.workspaceId.trim().isEmpty) {
      throw const WorkspaceConfigValidationException('No workspace selected');
    }

    if (input.ragEnabled) {
      await _embedderInstallCubit.ensureInstalled();
    }

    await _workspaceActions.updateGeneralInstruction(
      workspaceId: input.workspaceId,
      instruction: input.generalInstruction,
    );
    await _workspaceActions.updateRagEnabled(
      workspaceId: input.workspaceId,
      enabled: input.ragEnabled,
    );
    await _workspaceActions.updateNativeToolsEnabled(
      workspaceId: input.workspaceId,
      enabled: input.nativeToolsEnabled,
    );
    await _workspaceActions.updateNativeToolPermissions(
      workspaceId: input.workspaceId,
      openUrlEnabled: input.nativeOpenUrlEnabled,
      openAppEnabled: input.nativeOpenAppEnabled,
      sendEmailEnabled: input.nativeSendEmailEnabled,
      flashlightEnabled: input.nativeFlashlightEnabled,
    );

    _chatSessionController.resetActiveChatSession();
  }
}
