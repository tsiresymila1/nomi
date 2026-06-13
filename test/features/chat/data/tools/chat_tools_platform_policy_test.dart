import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/chat/data/tools/chat_tools.dart';

void main() {
  test('unsupported platform omits RAG tool even when requested', () {
    final tools = _buildTools(
      capabilities: AppCapabilities.forPlatform(AppPlatform.web),
      enableRagTool: true,
    );

    expect(tools.map((tool) => tool.name), isNot(contains(ragSearchToolName)));
  });

  test('supported platform preserves requested RAG tool', () {
    final tools = _buildTools(
      capabilities: AppCapabilities.forPlatform(AppPlatform.android),
      enableRagTool: true,
    );

    expect(tools.map((tool) => tool.name), contains(ragSearchToolName));
  });
}

List<UnifiedChatToolDefinition> _buildTools({
  required AppCapabilities capabilities,
  required bool enableRagTool,
}) {
  return buildUnifiedChatToolDefinitions(
    supportsFunctionCalls: true,
    enableRagTool: enableRagTool,
    enableNativeOpenUrlTool: false,
    enableNativeOpenAppTool: false,
    enableNativePhoneCallTool: false,
    enableNativeContactsTool: false,
    enableNativeSmsTool: false,
    enableNativeSendEmailTool: false,
    enableNativeFlashlightTool: false,
    capabilities: capabilities,
  );
}
