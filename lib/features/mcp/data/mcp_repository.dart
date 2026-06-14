import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/mcp/data/models/mcp_server.dart';

/// CRUD access to the configured MCP servers stored in the Drift database.
class McpRepository {
  McpRepository({required db.GenaDatabase database}) : _database = database;

  final db.GenaDatabase _database;

  Future<List<McpServer>> listServers() async {
    final rows = await (_database.select(
      _database.mcpServers,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
    return rows.map(_mapRow).toList(growable: false);
  }

  Future<List<McpServer>> listEnabledServers() async {
    final rows =
        await (_database.select(_database.mcpServers)
              ..where((t) => t.enabled.equals(true))
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    return rows.map(_mapRow).toList(growable: false);
  }

  Stream<List<McpServer>> watchServers() {
    final query = _database.select(_database.mcpServers)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch().map(
      (rows) => rows.map(_mapRow).toList(growable: false),
    );
  }

  Future<int> addServer({
    required String name,
    required String url,
    String? authHeader,
    bool enabled = true,
  }) {
    return _database
        .into(_database.mcpServers)
        .insert(
          db.McpServersCompanion.insert(
            name: name,
            url: url,
            authHeader: Value(_normalizeAuthHeader(authHeader)),
            enabled: Value(enabled),
          ),
        );
  }

  Future<bool> updateServer({
    required int id,
    required String name,
    required String url,
    String? authHeader,
    required bool enabled,
  }) async {
    final count =
        await (_database.update(
          _database.mcpServers,
        )..where((t) => t.id.equals(id))).write(
          db.McpServersCompanion(
            name: Value(name),
            url: Value(url),
            authHeader: Value(_normalizeAuthHeader(authHeader)),
            enabled: Value(enabled),
          ),
        );
    return count > 0;
  }

  Future<bool> setEnabled({required int id, required bool enabled}) async {
    final count =
        await (_database.update(_database.mcpServers)
              ..where((t) => t.id.equals(id)))
            .write(db.McpServersCompanion(enabled: Value(enabled)));
    return count > 0;
  }

  Future<int> deleteServer(int id) {
    return (_database.delete(
      _database.mcpServers,
    )..where((t) => t.id.equals(id))).go();
  }

  String? _normalizeAuthHeader(String? authHeader) {
    final trimmed = authHeader?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  McpServer _mapRow(db.McpServer row) {
    return McpServer(
      id: row.id,
      name: row.name,
      url: row.url,
      authHeader: row.authHeader,
      enabled: row.enabled,
      createdAt: row.createdAt,
    );
  }
}
