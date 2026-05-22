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
    final request = NativeToolRequest(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      toolName: toolName,
      args: Map<String, dynamic>.from(args),
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

    final service = ref.read(nativeToolBridgeServiceProvider);
    return service.execute(toolName: toolName, args: args);
  }

  String formatArgsForDisplay(Map<String, dynamic> args) {
    return const JsonEncoder.withIndent('  ').convert(args);
  }
}
