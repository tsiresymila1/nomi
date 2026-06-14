import 'package:gena/core/logger.dart';
import 'package:gena/features/mcp/data/models/mcp_server.dart';
import 'package:gena/features/mcp/data/services/mcp_client_manager.dart';
import 'package:mcp_dart/mcp_dart.dart' as mcp;

/// Default client implementation backed by `mcp_dart` over Streamable HTTP.
///
/// Caches one [mcp.McpClient] per server id, connecting lazily. Auth headers
/// are passed to the transport via `requestInit.headers` and are never logged.
class McpDartClientManager implements McpClientManager {
  McpDartClientManager({McpDartClientFactory? clientFactory})
    : _clientFactory = clientFactory ?? _defaultClientFactory;

  final McpDartClientFactory _clientFactory;
  final Map<String, mcp.McpClient> _clients = <String, mcp.McpClient>{};
  final Map<String, McpServer> _serversById = <String, McpServer>{};

  @override
  Future<List<McpToolDef>> discoverTools(List<McpServer> servers) async {
    final defs = <McpToolDef>[];
    for (final server in servers) {
      _serversById[server.serverId] = server;
      try {
        final client = await _ensureConnected(server);
        final result = await client.listTools();
        for (final tool in result.tools) {
          defs.add(
            McpToolDef(
              serverId: server.serverId,
              toolName: tool.name,
              namespacedName: buildMcpToolName(server.serverId, tool.name),
              description: tool.description ?? '',
              parameters: normalizeMcpInputSchema(tool.inputSchema.toJson()),
            ),
          );
        }
      } catch (error) {
        // Never block other servers or leak the auth header.
        logger.w(
          'MCP server "${server.name}" (id=${server.serverId}) discovery '
          'failed; skipping. error=$error',
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
    final server = _serversById[serverId];
    if (server == null) {
      return <String, dynamic>{
        'status': 'error',
        'error': 'unknown_server',
        'message': 'MCP server "$serverId" is not available in this session.',
      };
    }

    try {
      final client = await _ensureConnected(server);
      final result = await client.callTool(
        mcp.CallToolRequest(name: toolName, arguments: args),
      );
      final content = result.content
          .map(_renderContent)
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      return <String, dynamic>{
        'status': result.isError ? 'error' : 'success',
        'server': server.name,
        'tool': toolName,
        'content': content,
        if (result.structuredContent != null)
          'structured_content': result.structuredContent,
      };
    } catch (error) {
      logger.w(
        'MCP tool call failed on server id=$serverId tool=$toolName: $error',
      );
      return <String, dynamic>{
        'status': 'error',
        'error': 'mcp_call_failed',
        'server': server.name,
        'tool': toolName,
        'message': 'MCP tool call failed: $error',
      };
    }
  }

  @override
  Future<void> dispose() async {
    final clients = List<mcp.McpClient>.from(_clients.values);
    _clients.clear();
    _serversById.clear();
    for (final client in clients) {
      try {
        await client.close();
      } catch (_) {
        // Ignore close failures.
      }
    }
  }

  Future<mcp.McpClient> _ensureConnected(McpServer server) async {
    final existing = _clients[server.serverId];
    if (existing != null) return existing;

    final client = _clientFactory(server);
    final transport = mcp.StreamableHttpClientTransport(
      Uri.parse(server.url),
      opts: mcp.StreamableHttpClientTransportOptions(
        requestInit: _buildRequestInit(server.authHeader),
      ),
    );
    await client.connect(transport);
    _clients[server.serverId] = client;
    return client;
  }

  Map<String, dynamic>? _buildRequestInit(String? authHeader) {
    final trimmed = authHeader?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return <String, dynamic>{
      'headers': <String, dynamic>{'Authorization': trimmed},
    };
  }

  String _renderContent(mcp.Content content) {
    if (content is mcp.TextContent) return content.text;
    final json = content.toJson();
    final text = json['text'];
    if (text is String) return text;
    return json.toString();
  }
}

/// Builds an [mcp.McpClient] for a given server (without connecting).
typedef McpDartClientFactory = mcp.McpClient Function(McpServer server);

mcp.McpClient _defaultClientFactory(McpServer server) {
  return mcp.McpClient(
    const mcp.Implementation(name: 'gena', version: '1.0.0'),
    options: const mcp.McpClientOptions(capabilities: mcp.ClientCapabilities()),
  );
}
