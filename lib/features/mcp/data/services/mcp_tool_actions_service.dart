import 'package:gena/features/chat/data/models/native_tool_request.dart';
import 'package:gena/features/chat/presentation/cubit/native_tool_execution_cubit.dart';
import 'package:gena/features/mcp/data/services/mcp_client_manager.dart';

/// Bridges MCP tool calls through the shared approval flow.
///
/// MCP tools are external actions, so every call is approval-gated using the
/// same [NativeToolExecutionCubit] / approval sheet as native tools. A denied
/// or cancelled approval returns a tool error map and never invokes the server.
class McpToolActions {
  McpToolActions({
    required McpClientManager clientManager,
    required NativeToolExecutionCubit executionCubit,
  }) : _clientManager = clientManager,
       _executionCubit = executionCubit;

  final McpClientManager _clientManager;
  final NativeToolExecutionCubit _executionCubit;

  /// Requests user approval for [namespacedName] then routes the call to the
  /// owning MCP server. [namespacedName] is `mcp__<serverId>__<toolName>`.
  Future<Map<String, dynamic>> requestAndExecute({
    required String namespacedName,
    required Map<String, dynamic> args,
  }) async {
    final ref = parseMcpToolName(namespacedName);
    if (ref == null) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'invalid_mcp_tool',
        'message': 'Malformed MCP tool name "$namespacedName".',
      };
    }

    final request = NativeToolRequest(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      toolName: namespacedName,
      args: Map<String, dynamic>.from(args),
      needApproval: true,
      createdAt: DateTime.now(),
    );

    final approved = await _executionCubit.requestApproval(request);
    if (!approved) {
      return <String, dynamic>{
        'status': 'cancelled',
        'message': 'User rejected MCP tool execution.',
        'tool': namespacedName,
      };
    }

    return _clientManager.callTool(ref.serverId, ref.toolName, args);
  }
}
