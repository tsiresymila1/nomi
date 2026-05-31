import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_entry.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_model_spec.dart';
import 'package:gena/features/remote_servers/data/services/remote_server_catalog_service.dart';
import 'package:gena/features/remote_servers/data/services/remote_server_model_sync_service.dart';
import 'package:gena/features/remote_servers/data/services/remote_server_network_discovery_service.dart';
import 'package:gena/features/remote_servers/data/services/remote_server_store.dart';

class RemoteServersState {
  const RemoteServersState({
    this.servers = const [],
    this.loading = true,
    this.busy = false,
    this.errorMessage,
  });

  final List<RemoteServerEntry> servers;
  final bool loading;
  final bool busy;
  final String? errorMessage;

  RemoteServersState copyWith({
    List<RemoteServerEntry>? servers,
    bool? loading,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RemoteServersState(
      servers: servers ?? this.servers,
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class RemoteServersCubit extends Cubit<RemoteServersState> {
  RemoteServersCubit({
    required RemoteServerStore remoteServerStore,
    required RemoteServerCatalogService remoteServerCatalogService,
    required RemoteServerNetworkDiscoveryService remoteServerNetworkDiscovery,
    required RemoteServerModelSyncService remoteServerModelSyncService,
  }) : _remoteServerStore = remoteServerStore,
       _remoteServerCatalogService = remoteServerCatalogService,
       _remoteServerNetworkDiscovery = remoteServerNetworkDiscovery,
       _remoteServerModelSyncService = remoteServerModelSyncService,
       super(const RemoteServersState()) {
    load();
  }

  final RemoteServerStore _remoteServerStore;
  final RemoteServerCatalogService _remoteServerCatalogService;
  final RemoteServerNetworkDiscoveryService _remoteServerNetworkDiscovery;
  final RemoteServerModelSyncService _remoteServerModelSyncService;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final servers = await _remoteServerStore.load();
      emit(
        state.copyWith(
          servers: _sortServers(servers),
          loading: false,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      logger.e(error, error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          loading: false,
          errorMessage: 'Failed to load remote servers: $error',
        ),
      );
    }
  }

  Future<void> addOrUpdateManualServer({
    String? id,
    required String name,
    required String baseUrl,
    required String token,
  }) async {
    final normalizedUrl = _remoteServerCatalogService.normalizeApiBaseUrl(
      baseUrl,
    );
    final now = DateTime.now();
    final next = [...state.servers];

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
    final next = state.servers
        .where((server) => server.id != entry.id)
        .toList(growable: false);
    await _remoteServerModelSyncService.deleteAllModelsForServer(entry.id);
    await _persist(next);
  }

  Future<RemoteServerProbeResult> testConnection(RemoteServerEntry entry) {
    return _remoteServerCatalogService.probeAndFetchModels(
      baseUrl: entry.baseUrl,
      token: entry.token,
    );
  }

  Future<int> syncModelsForServer(RemoteServerEntry entry) async {
    final probe = await testConnection(entry);
    if (!probe.success) throw StateError(probe.message);

    final synced = await _remoteServerModelSyncService.syncServerModels(
      server: entry,
      effectiveApiBaseUrl: probe.effectiveApiBaseUrl,
      models: probe.models,
    );
    await _touchServer(entry.id);
    return synced;
  }

  Future<int> syncAllServers() async {
    var totalModels = 0;
    for (final server in state.servers) {
      final probe = await testConnection(server);
      if (!probe.success) continue;
      totalModels += await _remoteServerModelSyncService.syncServerModels(
        server: server,
        effectiveApiBaseUrl: probe.effectiveApiBaseUrl,
        models: probe.models,
      );
      await _touchServer(server.id);
    }
    return totalModels;
  }

  Future<int> scanNetworkAndAutoManageServers() async {
    final discovered = await _remoteServerNetworkDiscovery.scanLocalNetwork();
    final manual = state.servers
        .where((entry) => !entry.autoDiscovered)
        .toList(growable: false);
    final autoExisting = state.servers
        .where((entry) => entry.autoDiscovered)
        .toList(growable: false);

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
      await _remoteServerModelSyncService.deleteAllModelsForServer(removed.id);
    }

    await _persist([...manual, ...nextAuto]);
    var syncedTotal = 0;
    for (final server in nextAuto) {
      final probe = await testConnection(server);
      if (!probe.success) continue;
      syncedTotal += await _remoteServerModelSyncService.syncServerModels(
        server: server,
        effectiveApiBaseUrl: probe.effectiveApiBaseUrl,
        models: probe.models,
      );
    }
    return syncedTotal;
  }

  Future<T> runBusyTask<T>(Future<T> Function() task) async {
    if (state.busy) {
      throw StateError('Another remote server operation is already running.');
    }
    emit(state.copyWith(busy: true, clearError: true));
    try {
      return await task();
    } catch (error, stackTrace) {
      logger.e(error, error: error, stackTrace: stackTrace);
      emit(state.copyWith(errorMessage: '$error'));
      rethrow;
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  Future<void> _touchServer(String id) async {
    final now = DateTime.now();
    final next = state.servers
        .map(
          (entry) => entry.id == id ? entry.copyWith(lastSeenAt: now) : entry,
        )
        .toList(growable: false);
    await _persist(next);
  }

  Future<void> _persist(List<RemoteServerEntry> servers) async {
    final sorted = _sortServers(servers);
    await _remoteServerStore.save(sorted);
    emit(state.copyWith(servers: sorted, loading: false, clearError: true));
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
