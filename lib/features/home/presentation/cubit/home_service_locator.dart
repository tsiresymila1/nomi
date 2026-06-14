import 'package:gena/core/database/gena_database.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/chat/presentation/cubit/selected_chat_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/selected_model_cubit.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/home/presentation/cubit/home_cubit.dart';
import 'package:gena/features/workspace/presentation/cubit/selected_workspace_cubit.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_vector_store.dart';

void registerHomeDependencies() {
  if (!sl.isRegistered<WorkspaceRagVectorStore>()) {
    sl.registerLazySingleton<WorkspaceRagVectorStore>(
      WorkspaceRagVectorStore.new,
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
        workspaceRagVectorStore: sl<WorkspaceRagVectorStore>(),
        selectedModelCubit: sl<SelectedModelCubit>(),
        selectedWorkspaceCubit: sl<SelectedWorkspaceCubit>(),
        selectedChatCubit: sl<SelectedChatCubit>(),
      ),
    );
  }
}
