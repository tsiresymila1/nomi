import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/tools/chat_tools.dart';

void main() {
  group('buildUnifiedChatToolDefinitions memory tools', () {
    test('includes remember/forget when enabled', () {
      final tools = buildUnifiedChatToolDefinitions(
        supportsFunctionCalls: true,
        enableRagTool: false,
        enableNativeOpenUrlTool: false,
        enableNativeOpenAppTool: false,
        enableNativePhoneCallTool: false,
        enableNativeContactsTool: false,
        enableNativeSmsTool: false,
        enableNativeSendEmailTool: false,
        enableNativeFlashlightTool: false,
        enableMemoryTools: true,
      );
      final names = tools.map((t) => t.name).toList();
      expect(names, contains(rememberToolName));
      expect(names, contains(forgetToolName));
    });

    test('omits remember/forget when disabled', () {
      final tools = buildUnifiedChatToolDefinitions(
        supportsFunctionCalls: true,
        enableRagTool: false,
        enableNativeOpenUrlTool: false,
        enableNativeOpenAppTool: false,
        enableNativePhoneCallTool: false,
        enableNativeContactsTool: false,
        enableNativeSmsTool: false,
        enableNativeSendEmailTool: false,
        enableNativeFlashlightTool: false,
        enableMemoryTools: false,
      );
      final names = tools.map((t) => t.name).toList();
      expect(names, isNot(contains(rememberToolName)));
      expect(names, isNot(contains(forgetToolName)));
    });
  });

  group('executeChatToolByName memory routing', () {
    test('remember routes to the injected handler (no approval)', () async {
      String? capturedOp;
      String? capturedContent;
      var nativeCalled = false;

      final result = await executeChatToolByName(
        rememberToolName,
        <String, dynamic>{'content': 'Remember this fact'},
        memoryToolHandler: (op, {content}) async {
          capturedOp = op;
          capturedContent = content;
          return <String, dynamic>{'status': 'success', 'stored': true};
        },
        nativeToolHandler: (toolName, args) async {
          nativeCalled = true;
          return <String, dynamic>{'status': 'success'};
        },
      );

      expect(capturedOp, rememberToolName);
      expect(capturedContent, 'Remember this fact');
      expect(result['status'], 'success');
      // Memory tools never go through the native approval path.
      expect(nativeCalled, isFalse);
    });

    test('forget routes to the injected handler', () async {
      String? capturedOp;
      final result = await executeChatToolByName(
        forgetToolName,
        <String, dynamic>{'content': 'Drop this'},
        memoryToolHandler: (op, {content}) async {
          capturedOp = op;
          return <String, dynamic>{'status': 'success', 'removed': 1};
        },
      );
      expect(capturedOp, forgetToolName);
      expect(result['removed'], 1);
    });

    test('returns memory_disabled error when no handler is wired', () async {
      final result = await executeChatToolByName(
        rememberToolName,
        <String, dynamic>{'content': 'x'},
      );
      expect(result['status'], 'error');
      expect(result['error'], 'memory_disabled');
    });
  });
}
