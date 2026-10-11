import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_entry.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_protocol.dart';

void main() {
  test('round-trips the selected API protocol', () {
    final entry = RemoteServerEntry(
      id: 'server-1',
      name: 'Claude',
      baseUrl: 'https://api.anthropic.com',
      token: 'secret',
      autoDiscovered: false,
      createdAt: DateTime.utc(2026, 1, 2),
      lastSeenAt: DateTime.utc(2026, 1, 3),
      protocol: RemoteServerProtocol.anthropic,
    );

    final restored = RemoteServerEntry.fromJson(entry.toJson());

    expect(restored.protocol, RemoteServerProtocol.anthropic);
    expect(restored.baseUrl, 'https://api.anthropic.com');
  });

  test('treats legacy entries as OpenAI compatible', () {
    final restored = RemoteServerEntry.fromJson({
      'id': 'legacy',
      'name': 'Ollama',
      'baseUrl': 'http://localhost:11434',
      'token': '',
      'autoDiscovered': false,
      'createdAt': '2026-01-02T00:00:00.000Z',
    });

    expect(restored.protocol, RemoteServerProtocol.openAiCompatible);
  });
}
