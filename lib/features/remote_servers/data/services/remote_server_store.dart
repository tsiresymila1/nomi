import 'dart:convert';

import 'package:gena/features/remote_servers/data/models/remote_server_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RemoteServerStore {
  static const _storageKey = 'remote_servers_v1';

  Future<List<RemoteServerEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map>()
          .map(
            (entry) =>
                RemoteServerEntry.fromJson(Map<String, dynamic>.from(entry)),
          )
          .where(
            (entry) =>
                entry.id.trim().isNotEmpty &&
                entry.name.trim().isNotEmpty &&
                entry.baseUrl.trim().isNotEmpty,
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<RemoteServerEntry> servers) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = servers
        .map((entry) => entry.toJson())
        .toList(growable: false);
    await prefs.setString(_storageKey, jsonEncode(payload));
  }
}
