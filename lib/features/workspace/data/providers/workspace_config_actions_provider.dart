import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/providers/chat_session_provider.dart';
import 'package:gena/features/workspace/data/providers/workspace_actions_provider.dart';

final workspaceConfigActionsProvider = Provider<WorkspaceConfigActions>(
  (ref) => WorkspaceConfigActions(ref),
);

class WorkspaceConfigValidationException implements Exception {
  final String message;
  const WorkspaceConfigValidationException(this.message);

  @override
  String toString() => message;
}

class WorkspaceConfigSaveInput {
  final String workspaceId;
  final String generalInstruction;

  const WorkspaceConfigSaveInput({
    required this.workspaceId,
    required this.generalInstruction,
  });
}

class WorkspaceConfigActions {
  final Ref ref;
  WorkspaceConfigActions(this.ref);

  Future<void> save(WorkspaceConfigSaveInput input) async {
    if (input.workspaceId.trim().isEmpty) {
      throw const WorkspaceConfigValidationException('No workspace selected');
    }

    await ref
        .read(workspaceActionsProvider)
        .updateGeneralInstruction(
          workspaceId: input.workspaceId,
          instruction: input.generalInstruction,
        );

    ref.invalidate(activeGemmaChatProvider);
  }
}
