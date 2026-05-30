import 'package:gena/core/database/gena_database.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/chat/data/providers/chat_page_actions_provider.dart';
import 'package:gena/features/workspace/data/cubits/selected_workspace_cubit.dart';
import 'package:gena/features/workspace/data/cubits/workspace_drawer_cubit.dart';
import 'package:gena/features/workspace/data/cubits/workspace_embedder_install_cubit.dart';
import 'package:gena/features/workspace/data/services/workspace_document_parser.dart';
import 'package:gena/features/workspace/data/services/workspace_embedder_installer.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_vector_store.dart';
import 'package:gena/features/workspace/presentation/services/workspace_local_chat_actions.dart';
import 'package:gena/features/workspace/presentation/services/workspace_rag_ingestion_controller.dart';

void registerWorkspacePresentationDependencies() {
  if (!sl.isRegistered<WorkspaceDocumentParser>()) {
    sl.registerLazySingleton<WorkspaceDocumentParser>(
      WorkspaceDocumentParser.new,
    );
  }

  if (!sl.isRegistered<WorkspaceRagVectorStore>()) {
    sl.registerLazySingleton<WorkspaceRagVectorStore>(
      WorkspaceRagVectorStore.new,
    );
  }

  if (!sl.isRegistered<WorkspaceEmbedderInstaller>()) {
    sl.registerLazySingleton<WorkspaceEmbedderInstaller>(
      WorkspaceEmbedderInstaller.new,
    );
  }

  if (!sl.isRegistered<WorkspaceEmbedderInstallCubit>()) {
    sl.registerLazySingleton<WorkspaceEmbedderInstallCubit>(
      () => WorkspaceEmbedderInstallCubit(sl<WorkspaceEmbedderInstaller>()),
    );
  }

  if (!sl.isRegistered<SelectedWorkspaceCubit>()) {
    sl.registerLazySingleton<SelectedWorkspaceCubit>(
      () => SelectedWorkspaceCubit(sl<GenaDatabase>()),
    );
  }

  if (!sl.isRegistered<WorkspaceDrawerCubit>()) {
    sl.registerLazySingleton<WorkspaceDrawerCubit>(WorkspaceDrawerCubit.new);
  }

  if (!sl.isRegistered<WorkspaceRagIngestionController>()) {
    sl.registerLazySingleton<WorkspaceRagIngestionController>(
      () => WorkspaceRagIngestionController(
        database: sl<GenaDatabase>(),
        parser: sl<WorkspaceDocumentParser>(),
        vectorStore: sl<WorkspaceRagVectorStore>(),
      ),
    );
  }

  if (!sl.isRegistered<WorkspaceLocalChatActions>()) {
    sl.registerLazySingleton<WorkspaceLocalChatActions>(
      () => WorkspaceLocalChatActions(
        database: sl<GenaDatabase>(),
        selectedWorkspaceCubit: sl<SelectedWorkspaceCubit>(),
        chatPageActions: sl<ChatPageActions>(),
        drawerCubit: sl<WorkspaceDrawerCubit>(),
        ingestionController: sl<WorkspaceRagIngestionController>(),
      ),
    );
  }
}
