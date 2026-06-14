import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/presentation/cubit/native_tool_execution_cubit.dart';
import 'package:gena/features/mcp/data/models/mcp_server.dart';
import 'package:gena/features/mcp/data/services/mcp_client_manager.dart';
import 'package:gena/features/mcp/data/services/mcp_tool_actions_service.dart';

class _RecordingClientManager implements McpClientManager {
  final List<(String, String, Map<String, dynamic>)> calls =
      <(String, String, Map<String, dynamic>)>[];

  @override
  Future<List<McpToolDef>> discoverTools(List<McpServer> servers) async => [];

  @override
  Future<Map<String, dynamic>> callTool(
    String serverId,
    String toolName,
    Map<String, dynamic> args,
  ) async {
    calls.add((serverId, toolName, args));
    return <String, dynamic>{'status': 'success', 'tool': toolName};
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late NativeToolExecutionCubit cubit;
  late _RecordingClientManager clientManager;
  late McpToolActions actions;

  setUp(() {
    cubit = NativeToolExecutionCubit();
    clientManager = _RecordingClientManager();
    actions = McpToolActions(
      clientManager: clientManager,
      executionCubit: cubit,
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  test('approval invokes the client manager', () async {
    final future = actions.requestAndExecute(
      namespacedName: 'mcp__5__do_thing',
      args: <String, dynamic>{'a': 1},
    );

    // The request must be pending approval.
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.currentRequest, isNotNull);
    expect(cubit.state.currentRequest!.toolName, 'mcp__5__do_thing');
    expect(cubit.state.currentRequest!.needApproval, isTrue);

    cubit.approveCurrent();
    final result = await future;

    expect(result['status'], 'success');
    expect(clientManager.calls, hasLength(1));
    expect(clientManager.calls.single.$1, '5');
    expect(clientManager.calls.single.$2, 'do_thing');
  });

  test('denial returns a tool error and never calls the server', () async {
    final future = actions.requestAndExecute(
      namespacedName: 'mcp__5__do_thing',
      args: <String, dynamic>{},
    );

    await Future<void>.delayed(Duration.zero);
    cubit.rejectCurrent();
    final result = await future;

    expect(result['status'], 'cancelled');
    expect(clientManager.calls, isEmpty);
  });

  test('malformed tool name returns an error without approval', () async {
    final result = await actions.requestAndExecute(
      namespacedName: 'not_mcp',
      args: <String, dynamic>{},
    );
    expect(result['status'], 'error');
    expect(result['error'], 'invalid_mcp_tool');
    expect(clientManager.calls, isEmpty);
  });
}
