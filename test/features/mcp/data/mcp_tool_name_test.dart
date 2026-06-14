import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/mcp/data/services/mcp_client_manager.dart';

void main() {
  group('MCP tool name namespacing', () {
    test('builds the namespaced name', () {
      expect(buildMcpToolName('7', 'search'), 'mcp__7__search');
    });

    test('round-trips serverId and toolName', () {
      const namespaced = 'mcp__42__get_weather';
      final ref = parseMcpToolName(namespaced);
      expect(ref, isNotNull);
      expect(ref!.serverId, '42');
      expect(ref.toolName, 'get_weather');
      expect(buildMcpToolName(ref.serverId, ref.toolName), namespaced);
    });

    test('tool names containing double underscores round-trip', () {
      final name = buildMcpToolName('3', 'do__thing');
      final ref = parseMcpToolName(name);
      expect(ref, isNotNull);
      expect(ref!.serverId, '3');
      expect(ref.toolName, 'do__thing');
    });

    test('rejects non-mcp names', () {
      expect(parseMcpToolName('calculator'), isNull);
      expect(parseMcpToolName('mcp__'), isNull);
      expect(parseMcpToolName('mcp__server__'), isNull);
      expect(isMcpToolName('calculator'), isFalse);
      expect(isMcpToolName('mcp__1__x'), isTrue);
    });
  });

  group('normalizeMcpInputSchema', () {
    test('fills defaults for a null schema', () {
      final schema = normalizeMcpInputSchema(null);
      expect(schema['type'], 'object');
      expect(schema['properties'], isA<Map<String, dynamic>>());
      expect(schema['required'], isA<List<dynamic>>());
    });

    test('preserves existing properties and required', () {
      final schema = normalizeMcpInputSchema(<String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'q': <String, dynamic>{'type': 'string'},
        },
        'required': <String>['q'],
      });
      expect(schema['properties'], contains('q'));
      expect(schema['required'], contains('q'));
    });
  });
}
