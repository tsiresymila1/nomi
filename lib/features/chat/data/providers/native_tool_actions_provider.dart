import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/models/native_tool_request.dart';
import 'package:gena/features/chat/data/providers/native_tool_execution_provider.dart';
import 'package:gena/features/chat/data/services/native_tool_bridge_service.dart';

final nativeToolBridgeServiceProvider = Provider<NativeToolBridgeService>(
  (ref) => NativeToolBridgeService(),
);

final nativeToolActionsProvider = Provider<NativeToolActions>(
  (ref) => NativeToolActions(ref),
);

class NativeToolActions {
  final Ref ref;
  NativeToolActions(this.ref);

  Future<Map<String, dynamic>> requestAndExecute({
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    final service = ref.read(nativeToolBridgeServiceProvider);
    final needApproval = _requiresApproval(toolName);

    final request = NativeToolRequest(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      toolName: toolName,
      args: Map<String, dynamic>.from(args),
      needApproval: needApproval,
      createdAt: DateTime.now(),
    );

    final approved = await ref
        .read(nativeToolExecutionProvider.notifier)
        .requestApproval(request);
    if (!approved) {
      return <String, dynamic>{
        'status': 'cancelled',
        'message': 'User rejected native action execution.',
        'tool': toolName,
      };
    }

    return service.execute(toolName: toolName, args: args);
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
