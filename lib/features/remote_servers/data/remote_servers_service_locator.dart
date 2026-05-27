import 'package:gena/core/database/gena_database.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/remote_servers/data/providers/remote_server_providers.dart';
import 'package:gena/features/remote_servers/data/services/remote_server_catalog_service.dart';
import 'package:gena/features/remote_servers/data/services/remote_server_model_sync_service.dart';
import 'package:gena/features/remote_servers/data/services/remote_server_network_discovery_service.dart';
import 'package:gena/features/remote_servers/data/services/remote_server_store.dart';

void registerRemoteServersDependencies() {
  if (!sl.isRegistered<RemoteServerStore>()) {
    sl.registerLazySingleton<RemoteServerStore>(RemoteServerStore.new);
  }
  if (!sl.isRegistered<RemoteServerCatalogService>()) {
    sl.registerLazySingleton<RemoteServerCatalogService>(
      RemoteServerCatalogService.new,
    );
  }
  if (!sl.isRegistered<RemoteServerNetworkDiscoveryService>()) {
    sl.registerLazySingleton<RemoteServerNetworkDiscoveryService>(
      RemoteServerNetworkDiscoveryService.new,
    );
  }
  if (!sl.isRegistered<RemoteServerModelSyncService>()) {
    sl.registerLazySingleton<RemoteServerModelSyncService>(
      () => RemoteServerModelSyncService(sl<GenaDatabase>()),
    );
  }
  if (!sl.isRegistered<RemoteServersCubit>()) {
    sl.registerLazySingleton<RemoteServersCubit>(
      () => RemoteServersCubit(
        remoteServerStore: sl<RemoteServerStore>(),
        remoteServerCatalogService: sl<RemoteServerCatalogService>(),
        remoteServerNetworkDiscovery: sl<RemoteServerNetworkDiscoveryService>(),
        remoteServerModelSyncService: sl<RemoteServerModelSyncService>(),
      ),
    );
  }
}
