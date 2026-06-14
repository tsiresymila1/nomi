import 'dart:convert';

import 'package:gena/features/mcp/data/models/mcp_server.dart';

/// A tool discovered from a remote MCP server, mapped into the app's
/// provider-neutral shape so it can be bridged into the chat tool set.
class McpToolDef {
  const McpToolDef({
    required this.serverId,
    required this.toolName,
    required this.namespacedName,
    required this.description,
    required this.parameters,
  });

  /// The owning server's stable id.
  final String serverId;

  /// The raw tool name as reported by the MCP server.
  final String toolName;

  /// The namespaced unified tool name: `mcp__<serverId>__<toolName>`.
  final String namespacedName;

  /// Human-readable tool description (may be empty).
  final String description;

  /// JSON Schema for the tool input (`type: object`, properties, required).
  final Map<String, dynamic> parameters;
}

const String mcpToolNamePrefix = 'mcp__';

/// Builds the namespaced unified tool name for an MCP tool.
String buildMcpToolName(String serverId, String toolName) {
  return '$mcpToolNamePrefix${serverId}__$toolName';
}

/// Parsed components of a namespaced MCP tool name.
class McpToolRef {
  const McpToolRef({required this.serverId, required this.toolName});

  final String serverId;
  final String toolName;
}

/// Parses a namespaced MCP tool name back into its [McpToolRef].
///
/// Returns `null` when [namespacedName] is not a valid `mcp__<server>__<tool>`
/// name. The separator between server id and tool name is the first `__`
/// after the prefix, so tool names that themselves contain `__` round-trip.
McpToolRef? parseMcpToolName(String namespacedName) {
  if (!namespacedName.startsWith(mcpToolNamePrefix)) return null;
  final rest = namespacedName.substring(mcpToolNamePrefix.length);
  final separatorIndex = rest.indexOf('__');
  if (separatorIndex <= 0) return null;
  final serverId = rest.substring(0, separatorIndex);
  final toolName = rest.substring(separatorIndex + 2);
  if (serverId.isEmpty || toolName.isEmpty) return null;
  return McpToolRef(serverId: serverId, toolName: toolName);
}

/// Returns whether [toolName] is a namespaced MCP tool name.
bool isMcpToolName(String toolName) => toolName.startsWith(mcpToolNamePrefix);

/// Provider-neutral boundary over the remote MCP clients.
///
/// Kept behind an interface so chat generation can depend on it while tests
/// substitute a fake. Implementations connect lazily, never log auth headers,
/// and must skip (not throw for) a server that fails to connect or list tools.
abstract interface class McpClientManager {
  /// Connects to each enabled server, lists its tools, and returns the merged
  /// set of namespaced tool definitions. A server that fails is skipped with a
  /// logged warning; the others still return.
  Future<List<McpToolDef>> discoverTools(List<McpServer> servers);

  /// Invokes [toolName] on the server identified by [serverId] and returns a
  /// compact `{status, content, ...}` result map.
  Future<Map<String, dynamic>> callTool(
    String serverId,
    String toolName,
    Map<String, dynamic> args,
  );

  /// Closes and clears any cached clients.
  Future<void> dispose();
}

/// Normalizes a JSON schema map so it is always a valid `type: object` schema.
Map<String, dynamic> normalizeMcpInputSchema(Map<String, dynamic>? schema) {
  final cloned = schema == null
      ? <String, dynamic>{}
      : jsonDecode(jsonEncode(schema)) as Map<String, dynamic>;
  if (cloned['type'] == null) {
    cloned['type'] = 'object';
  }
  cloned['properties'] ??= <String, dynamic>{};
  cloned['required'] ??= <String>[];
  return cloned;
}
