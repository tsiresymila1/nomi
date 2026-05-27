import 'package:gena/core/database/gena_database.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/home/presentation/cubit/home_cubit.dart';
import 'package:gena/features/workspace/data/services/workspace_embedder_installer.dart';

void registerHomeDependencies() {
  if (!sl.isRegistered<WorkspaceEmbedderInstaller>()) {
    sl.registerLazySingleton<WorkspaceEmbedderInstaller>(
      WorkspaceEmbedderInstaller.new,
    );
  }

  if (!sl.isRegistered<HomeCubit>()) {
    sl.registerLazySingleton<HomeCubit>(
      () => HomeCubit(
        database: sl<GenaDatabase>(),
        modelRepository: sl<ModelRepository>(),
        modelInstallerService: sl<ModelInstallerService>(),
        modelRepositoryActions: sl<ModelRepositoryActions>(),
        defaultModelSeeder: sl<DefaultModelSeeder>(),
        workspaceEmbedderInstaller: sl<WorkspaceEmbedderInstaller>(),
      ),
    );
  }
}
