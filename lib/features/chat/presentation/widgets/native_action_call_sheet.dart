import 'package:flutter/material.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/chat/data/models/native_tool_request.dart';
import 'package:gena/features/chat/data/providers/native_tool_actions_provider.dart';
import 'package:gena/features/chat/data/tools/chat_tools.dart';

String _toolLabel(String toolName) {
  return switch (toolName) {
    nativeOpenUrlToolName => 'Open URL',
    nativeOpenAppToolName => 'Open App',
    nativePhoneCallToolName => 'Direct Phone Call',
    nativeReadContactsToolName => 'Read Contacts',
    nativeSearchContactsToolName => 'Search Contacts',
    nativeCreateContactToolName => 'Create Contact',
    nativeSendSmsToolName => 'Send SMS',
    nativeSendEmailToolName => 'Send Email',
    nativeFlashlightToolName => 'Flashlight',
    _ => toolName,
  };
}

class NativeActionCallSheet extends StatelessWidget {
  final NativeToolRequest request;

  const NativeActionCallSheet({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final nativeToolActions = sl<NativeToolActions>();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Approve Native Action',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'The assistant requests action: ${_toolLabel(request.toolName)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                request.args.isEmpty
                    ? 'No arguments'
                    : nativeToolActions.formatArgsForDisplay(request.args),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
