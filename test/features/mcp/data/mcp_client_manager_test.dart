import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/mcp/data/models/mcp_server.dart';
import 'package:gena/features/mcp/data/services/mcp_client_manager.dart';
import 'package:gena/features/mcp/data/services/mcp_dart_client_manager.dart';

/// A fake MCP client manager that simulates the per-server connection layer.
///
/// Each server id maps to either a tool list (success) or a thrown error
/// (failure). It reuses the real namespacing/schema helpers so the discovery
/// contract is exercised exactly as the production manager would produce it.
class _FakeMcpClientManager implements McpClientManager {
  _FakeMcpClientManager({
    required this.toolsByServer,
    this.failingServerIds = const <String>{},
  });

  /// serverId -> list of (toolName, description, inputSchema).
  final Map<String, List<(String, String, Map<String, dynamic>)>> toolsByServer;
  final Set<String> failingServerIds;

  final List<(String, String, Map<String, dynamic>)> calls =
      <(String, String, Map<String, dynamic>)>[];

  @override
  Future<List<McpToolDef>> discoverTools(List<McpServer> servers) async {
    final defs = <McpToolDef>[];
    for (final server in servers) {
      if (failingServerIds.contains(server.serverId)) {
        // Simulate a connect/list failure: skip, don't throw.
        continue;
      }
      final tools = toolsByServer[server.serverId] ?? const [];
      for (final tool in tools) {
        defs.add(
          McpToolDef(
            serverId: server.serverId,
            toolName: tool.$1,
            namespacedName: buildMcpToolName(server.serverId, tool.$1),
            description: tool.$2,
            parameters: normalizeMcpInputSchema(tool.$3),
          ),
        );
      }
    }
    return defs;
  }

  @override
  Future<Map<String, dynamic>> callTool(
    String serverId,
    String toolName,
    Map<String, dynamic> args,
  ) async {
    calls.add((serverId, toolName, args));
    if (failingServerIds.contains(serverId)) {
      return <String, dynamic>{'status': 'error', 'error': 'mcp_call_failed'};
    }
    return <String, dynamic>{
      'status': 'success',
      'server': serverId,
      'tool': toolName,
      'echo': args,
    };
  }

  @override
  Future<void> dispose() async {}
}

McpServer _server(int id, String name) => McpServer(
  id: id,
  name: name,
  url: 'https://example.com/$id/mcp',
  authHeader: null,
  enabled: true,
  createdAt: DateTime(2026),
);

void main() {
  group('McpClientManager discovery (fake)', () {
    test('returns namespaced defs with description + parameters', () async {
      final manager = _FakeMcpClientManager(
        toolsByServer: {
          '1': [
            (
              'search',
              'Search the web',
              <String, dynamic>{
                'type': 'object',
                'properties': <String, dynamic>{
                  'q': <String, dynamic>{'type': 'string'},
                },
                'required': <String>['q'],
              },
            ),
          ],
        },
      );

      final defs = await manager.discoverTools([_server(1, 'A')]);

      expect(defs, hasLength(1));
      final def = defs.single;
      expect(def.namespacedName, 'mcp__1__search');
      expect(def.serverId, '1');
      expect(def.toolName, 'search');
      expect(def.description, 'Search the web');
      expect(def.parameters['properties'], contains('q'));
      expect(def.parameters['required'], contains('q'));
    });

    test('routes callTool to the correct server and tool', () async {
      final manager = _FakeMcpClientManager(
        toolsByServer: {
          '1': [('a', '', <String, dynamic>{})],
          '2': [('b', '', <String, dynamic>{})],
        },
      );

      final result = await manager.callTool('2', 'b', <String, dynamic>{
        'x': 1,
      });

      expect(result['status'], 'success');
      expect(result['server'], '2');
      expect(result['tool'], 'b');
      expect(manager.calls, hasLength(1));
      expect(manager.calls.single.$1, '2');
      expect(manager.calls.single.$2, 'b');
    });

    test('a failing server is skipped while others still return', () async {
      final manager = _FakeMcpClientManager(
        toolsByServer: {
          '1': [('a', '', <String, dynamic>{})],
          '2': [('b', '', <String, dynamic>{})],
        },
        failingServerIds: {'1'},
      );

      final defs = await manager.discoverTools([
        _server(1, 'failing'),
        _server(2, 'ok'),
      ]);

      expect(defs, hasLength(1));
      expect(defs.single.namespacedName, 'mcp__2__b');
    });
  });

  group('McpDartClientManager', () {
    test('callTool on an undiscovered server returns an error map', () async {
      final manager = McpDartClientManager();
      final result = await manager.callTool('999', 'x', <String, dynamic>{});
      expect(result['status'], 'error');
      expect(result['error'], 'unknown_server');
      await manager.dispose();
    });
  });
}
