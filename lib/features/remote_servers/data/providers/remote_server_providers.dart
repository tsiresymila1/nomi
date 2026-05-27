import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_entry.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_model_spec.dart';
import 'package:gena/features/remote_servers/data/services/remote_server_catalog_service.dart';
import 'package:gena/features/remote_servers/data/services/remote_server_model_sync_service.dart';
import 'package:gena/features/remote_servers/data/services/remote_server_network_discovery_service.dart';
import 'package:gena/features/remote_servers/data/services/remote_server_store.dart';

final remoteServerStoreProvider = Provider<RemoteServerStore>((ref) {
  return RemoteServerStore();
});

final remoteServerCatalogServiceProvider = Provider<RemoteServerCatalogService>(
  (ref) {
    return RemoteServerCatalogService();
  },
);

final remoteServerNetworkDiscoveryProvider =
    Provider<RemoteServerNetworkDiscoveryService>((ref) {
      return RemoteServerNetworkDiscoveryService();
    });

final remoteServersControllerProvider =
    AsyncNotifierProvider<RemoteServersController, List<RemoteServerEntry>>(
      RemoteServersController.new,
    );

class RemoteServersController extends AsyncNotifier<List<RemoteServerEntry>> {
  @override
  Future<List<RemoteServerEntry>> build() async {
    final servers = await ref.read(remoteServerStoreProvider).load();
    return _sortServers(servers);
  }

  Future<void> addOrUpdateManualServer({
    String? id,
    required String name,
    required String baseUrl,
    required String token,
  }) async {
    final current = await future;
    final service = ref.read(remoteServerCatalogServiceProvider);
    final normalizedUrl = service.normalizeApiBaseUrl(baseUrl);

    final now = DateTime.now();
    final next = [...current];

    if (id == null) {
      next.add(
        RemoteServerEntry(
          id: _createId(),
          name: name.trim(),
          baseUrl: normalizedUrl,
          token: token.trim(),
          autoDiscovered: false,
          createdAt: now,
          lastSeenAt: now,
        ),
      );
    } else {
      final index = next.indexWhere((entry) => entry.id == id);
      if (index == -1) return;
      final previous = next[index];
      next[index] = previous.copyWith(
        name: name.trim(),
        baseUrl: normalizedUrl,
        token: token.trim(),
        autoDiscovered: false,
        lastSeenAt: now,
      );
    }

    await _persist(next);
  }

  Future<void> removeServer(RemoteServerEntry entry) async {
    final current = await future;
    final next = current.where((server) => server.id != entry.id).toList();

    await ref
        .read(remoteServerModelSyncServiceProvider)
        .deleteAllModelsForServer(entry.id);
    await _persist(next);
  }

  Future<RemoteServerProbeResult> testConnection(
    RemoteServerEntry entry,
  ) async {
    return ref
        .read(remoteServerCatalogServiceProvider)
        .probeAndFetchModels(baseUrl: entry.baseUrl, token: entry.token);
  }

  Future<int> syncModelsForServer(RemoteServerEntry entry) async {
    final probe = await testConnection(entry);
    if (!probe.success) {
      throw StateError(probe.message);
    }

    final synced = await ref
        .read(remoteServerModelSyncServiceProvider)
        .syncServerModels(
          server: entry,
          effectiveApiBaseUrl: probe.effectiveApiBaseUrl,
          models: probe.models,
        );

    await _touchServer(entry.id);
    return synced;
  }

  Future<int> syncAllServers() async {
    final servers = await future;
    var totalModels = 0;

    for (final server in servers) {
      final probe = await testConnection(server);
      if (!probe.success) continue;

      final synced = await ref
          .read(remoteServerModelSyncServiceProvider)
          .syncServerModels(
            server: server,
            effectiveApiBaseUrl: probe.effectiveApiBaseUrl,
            models: probe.models,
          );
      totalModels += synced;
      await _touchServer(server.id);
    }

    return totalModels;
  }

  Future<int> scanNetworkAndAutoManageServers() async {
    final discovered = await ref
        .read(remoteServerNetworkDiscoveryProvider)
        .scanLocalNetwork();

    final current = await future;
    final manual = current.where((entry) => !entry.autoDiscovered).toList();
    final autoExisting = current
        .where((entry) => entry.autoDiscovered)
        .toList();

    final byUrlManual = {
      for (final entry in manual) _normalizeUrl(entry.baseUrl): entry,
    };

    final autoByUrl = {
      for (final entry in autoExisting) _normalizeUrl(entry.baseUrl): entry,
    };

    final now = DateTime.now();
    final discoveredUrlSet = <String>{};
    final nextAuto = <RemoteServerEntry>[];

    for (final candidate in discovered) {
      final normalizedUrl = _normalizeUrl(candidate.baseUrl);
      discoveredUrlSet.add(normalizedUrl);
      if (byUrlManual.containsKey(normalizedUrl)) continue;

      final existing = autoByUrl[normalizedUrl];
      if (existing != null) {
        nextAuto.add(existing.copyWith(name: candidate.name, lastSeenAt: now));
      } else {
        nextAuto.add(
          RemoteServerEntry(
            id: _createId(),
            name: candidate.name,
            baseUrl: candidate.baseUrl,
            token: '',
            autoDiscovered: true,
            createdAt: now,
            lastSeenAt: now,
          ),
        );
      }
    }

    final removedAuto = autoExisting
        .where(
          (entry) => !discoveredUrlSet.contains(_normalizeUrl(entry.baseUrl)),
        )
        .toList(growable: false);

    for (final removed in removedAuto) {
      await ref
          .read(remoteServerModelSyncServiceProvider)
          .deleteAllModelsForServer(removed.id);
    }

    final merged = [...manual, ...nextAuto];
    await _persist(merged);

    var syncedTotal = 0;
    for (final server in nextAuto) {
      final probe = await testConnection(server);
      if (!probe.success) continue;
      final synced = await ref
          .read(remoteServerModelSyncServiceProvider)
          .syncServerModels(
            server: server,
            effectiveApiBaseUrl: probe.effectiveApiBaseUrl,
            models: probe.models,
          );
      syncedTotal += synced;
    }

    return syncedTotal;
  }

  Future<void> _touchServer(String id) async {
    final current = await future;
    final now = DateTime.now();
    final next = current
        .map((entry) {
          if (entry.id != id) return entry;
          return entry.copyWith(lastSeenAt: now);
        })
        .toList(growable: false);

    await _persist(next);
  }

  Future<void> _persist(List<RemoteServerEntry> servers) async {
    final sorted = _sortServers(servers);
    await ref.read(remoteServerStoreProvider).save(sorted);
    state = AsyncData(sorted);
  }

  List<RemoteServerEntry> _sortServers(List<RemoteServerEntry> servers) {
    final next = [...servers];
    next.sort((a, b) {
      if (a.autoDiscovered != b.autoDiscovered) {
        return a.autoDiscovered ? 1 : -1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return next;
  }

  String _createId() {
    final random = Random();
    final millis = DateTime.now().millisecondsSinceEpoch;
    final tail = random.nextInt(1 << 32).toRadixString(16);
    return 'srv_$millis$tail';
  }

  String _normalizeUrl(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
  }
}
