import 'package:gena/features/chat/presentation/cubit/chat_ui_cubits.dart';
import 'package:gena/features/chat/data/services/local_model_runtime.dart';
import 'package:gena/features/chat/data/tools/native_tool_actions_service.dart';
import 'package:gena/features/mcp/data/mcp_repository.dart';
import 'package:gena/features/mcp/data/services/mcp_client_manager.dart';
import 'package:gena/features/mcp/data/services/mcp_tool_actions_service.dart';
import 'package:gena/features/workspace/data/services/workspace_queries_entity_service.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_actions.dart';

class ChatRuntimeDependencies {
  ChatRuntimeDependencies({
    required this.chatDraftResponseCubit,
    required this.chatDraftThinkingCubit,
    required this.chatToolWaitingCubit,
    required this.chatContextWindowCubit,
    required this.localModelRuntime,
    required this.nativeToolActions,
    required this.workspaceQueries,
    required this.workspaceRagActions,
    required this.mcpRepository,
    required this.mcpClientManager,
    required this.mcpToolActions,
  });

  final ChatDraftResponseCubit chatDraftResponseCubit;
  final ChatDraftThinkingCubit chatDraftThinkingCubit;
  final ChatToolWaitingCubit chatToolWaitingCubit;
  final ChatContextWindowCubit chatContextWindowCubit;
  final LocalModelRuntime localModelRuntime;
  final NativeToolActions nativeToolActions;
  final WorkspaceQueries workspaceQueries;
  final WorkspaceRagActions workspaceRagActions;
  final McpRepository mcpRepository;
  final McpClientManager mcpClientManager;
  final McpToolActions mcpToolActions;
}
