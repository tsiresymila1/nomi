import 'package:gena/features/chat/presentation/cubit/chat_ui_cubits.dart';
import 'package:gena/features/chat/data/tools/native_tool_actions_service.dart';
import 'package:gena/features/workspace/data/services/workspace_queries_entity_service.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_actions.dart';

class ChatRuntimeDependencies {
  ChatRuntimeDependencies({
    required this.chatDraftResponseCubit,
    required this.chatDraftThinkingCubit,
    required this.chatToolWaitingCubit,
    required this.chatContextWindowCubit,
    required this.nativeToolActions,
    required this.workspaceQueries,
    required this.workspaceRagActions,
  });

  final ChatDraftResponseCubit chatDraftResponseCubit;
  final ChatDraftThinkingCubit chatDraftThinkingCubit;
  final ChatToolWaitingCubit chatToolWaitingCubit;
  final ChatContextWindowCubit chatContextWindowCubit;
  final NativeToolActions nativeToolActions;
  final WorkspaceQueries workspaceQueries;
  final WorkspaceRagActions workspaceRagActions;
}
