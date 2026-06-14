import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/database/gena_database.dart';
import 'package:gena/features/mcp/data/mcp_repository.dart';

void main() {
  late GenaDatabase database;
  late McpRepository repository;

  setUp(() {
    database = GenaDatabase(NativeDatabase.memory());
    repository = McpRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('add then list returns the inserted server', () async {
    final id = await repository.addServer(
      name: 'My MCP',
      url: 'https://example.com/mcp',
      authHeader: 'Bearer secret',
    );

    final servers = await repository.listServers();
    expect(servers, hasLength(1));
    expect(servers.single.id, id);
    expect(servers.single.name, 'My MCP');
    expect(servers.single.url, 'https://example.com/mcp');
    expect(servers.single.authHeader, 'Bearer secret');
    expect(servers.single.enabled, isTrue);
  });

  test('blank auth header is normalized to null', () async {
    await repository.addServer(
      name: 'No auth',
      url: 'https://example.com/mcp',
      authHeader: '   ',
    );
    final servers = await repository.listServers();
    expect(servers.single.authHeader, isNull);
  });

  test('update mutates the stored server', () async {
    final id = await repository.addServer(
      name: 'Old',
      url: 'https://old.example.com',
    );

    final updated = await repository.updateServer(
      id: id,
      name: 'New',
      url: 'https://new.example.com',
      authHeader: 'Bearer t',
      enabled: false,
    );
    expect(updated, isTrue);

    final servers = await repository.listServers();
    expect(servers.single.name, 'New');
    expect(servers.single.url, 'https://new.example.com');
    expect(servers.single.authHeader, 'Bearer t');
    expect(servers.single.enabled, isFalse);
  });

  test('setEnabled toggles a single server', () async {
    final id = await repository.addServer(
      name: 'Toggle',
      url: 'https://example.com/mcp',
    );

    await repository.setEnabled(id: id, enabled: false);
    expect((await repository.listServers()).single.enabled, isFalse);

    await repository.setEnabled(id: id, enabled: true);
    expect((await repository.listServers()).single.enabled, isTrue);
  });

  test('listEnabledServers filters disabled servers', () async {
    final enabledId = await repository.addServer(
      name: 'A enabled',
      url: 'https://a.example.com',
    );
    final disabledId = await repository.addServer(
      name: 'B disabled',
      url: 'https://b.example.com',
      enabled: false,
    );

    final enabled = await repository.listEnabledServers();
    expect(enabled.map((s) => s.id), contains(enabledId));
    expect(enabled.map((s) => s.id), isNot(contains(disabledId)));
  });

  test('delete removes the server', () async {
    final id = await repository.addServer(
      name: 'Doomed',
      url: 'https://example.com/mcp',
    );
    final deleted = await repository.deleteServer(id);
    expect(deleted, 1);
    expect(await repository.listServers(), isEmpty);
  });

  test('watchServers emits the current server list', () async {
    final stream = repository.watchServers();
    await repository.addServer(name: 'Watched', url: 'https://example.com/mcp');
    final emitted = await stream.firstWhere((list) => list.isNotEmpty);
    expect(emitted.single.name, 'Watched');
  });
}
