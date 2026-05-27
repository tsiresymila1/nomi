import 'package:gena/core/database/gena_database.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/presentation/cubit/downloads_cubit.dart';

void registerDownloadsDependencies() {
  if (!sl.isRegistered<ModelRepository>()) {
    sl.registerLazySingleton<ModelRepository>(
      () => ModelRepository(sl<GenaDatabase>()),
    );
  }

  if (!sl.isRegistered<ModelInstallerService>()) {
    sl.registerLazySingleton<ModelInstallerService>(ModelInstallerService.new);
  }

  if (!sl.isRegistered<DefaultModelSeeder>()) {
    sl.registerLazySingleton<DefaultModelSeeder>(
      () => DefaultModelSeeder(sl<GenaDatabase>()),
    );
  }

  if (!sl.isRegistered<ModelRepositoryActions>()) {
    sl.registerLazySingleton<ModelRepositoryActions>(
      () => ModelRepositoryActions(
        database: sl<GenaDatabase>(),
        defaultModelSeeder: sl<DefaultModelSeeder>(),
      ),
    );
  }

  if (!sl.isRegistered<DownloadsCubit>()) {
    sl.registerLazySingleton<DownloadsCubit>(
      () => DownloadsCubit(
        modelRepository: sl<ModelRepository>(),
        modelInstallerService: sl<ModelInstallerService>(),
        modelRepositoryActions: sl<ModelRepositoryActions>(),
        defaultModelSeeder: sl<DefaultModelSeeder>(),
      ),
    );
  }
}
