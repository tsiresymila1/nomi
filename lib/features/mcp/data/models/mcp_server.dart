/// App-level model for a configured remote MCP (Model Context Protocol) server.
///
/// An MCP server in gena is a Streamable HTTP endpoint (`url`) with an optional
/// bearer auth header. The [authHeader] is the raw header value (for example
/// `Bearer abc123`) and must never be logged.
class McpServer {
  const McpServer({
    required this.id,
    required this.name,
    required this.url,
    required this.authHeader,
    required this.enabled,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String url;
  final String? authHeader;
  final bool enabled;
  final DateTime createdAt;

  /// Stable string id used for tool namespacing (`mcp__<serverId>__<tool>`).
  String get serverId => id.toString();

  McpServer copyWith({
    int? id,
    String? name,
    String? url,
    String? authHeader,
    bool clearAuthHeader = false,
    bool? enabled,
    DateTime? createdAt,
  }) {
    return McpServer(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      authHeader: clearAuthHeader ? null : (authHeader ?? this.authHeader),
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
