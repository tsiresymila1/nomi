import 'dart:convert';

import 'package:gena/features/chat/data/cubits/native_tool_execution_cubit.dart';
import 'package:gena/features/chat/data/models/native_tool_request.dart';
import 'package:gena/features/chat/data/services/native_tool_bridge_service.dart';

class NativeToolActions {
  NativeToolActions({
    required NativeToolBridgeService bridgeService,
    required NativeToolExecutionCubit executionCubit,
  }) : _bridgeService = bridgeService,
       _executionCubit = executionCubit;

  final NativeToolBridgeService _bridgeService;
  final NativeToolExecutionCubit _executionCubit;

  Future<Map<String, dynamic>> requestAndExecute({
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    final needApproval = _requiresApproval(toolName);

    final request = NativeToolRequest(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      toolName: toolName,
      args: Map<String, dynamic>.from(args),
      needApproval: needApproval,
      createdAt: DateTime.now(),
    );

    final approved = await _executionCubit.requestApproval(request);
    if (!approved) {
      return <String, dynamic>{
        'status': 'cancelled',
        'message': 'User rejected native action execution.',
        'tool': toolName,
      };
    }

    return _bridgeService.execute(toolName: toolName, args: args);
  }

  String formatArgsForDisplay(Map<String, dynamic> args) {
    return const JsonEncoder.withIndent('  ').convert(args);
  }

  bool _requiresApproval(String toolName) {
    final normalized = toolName.trim().toLowerCase();
    const mutatePrefixes = <String>[
      'native_create_',
      'native_delete_',
      'native_update_',
      'native_mutate_',
      'native_send_',
    ];
    return mutatePrefixes.any(normalized.startsWith);
  }
}
