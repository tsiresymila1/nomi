import 'package:drift_flutter/drift_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:gena/core/database/gena_database.dart';
import 'package:gena/core/theme/theme_cubit.dart';
import 'package:gena/features/chat/data/cubits/selected_chat_cubit.dart';
import 'package:gena/features/workspace/data/cubits/selected_workspace_cubit.dart';
import 'package:gena/features/workspace/data/cubits/workspace_drawer_cubit.dart';
import 'package:gena/features/workspace/data/cubits/workspace_embedder_install_cubit.dart';
import 'package:gena/features/workspace/data/services/workspace_actions.dart';
import 'package:gena/features/workspace/data/services/workspace_config_actions.dart';
import 'package:gena/features/workspace/data/services/workspace_documents_service.dart';
import 'package:gena/features/workspace/data/services/workspace_embedder_installer.dart';
import 'package:gena/features/workspace/data/services/workspace_queries_service.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_actions.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_ingestion_bootstrap.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_ingestion_queue.dart';
import 'package:gena/features/workspace/data/services/workspace_document_parser.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_vector_store.dart';

final GetIt sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  if (!sl.isRegistered<GenaDatabase>()) {
    sl.registerLazySingleton<GenaDatabase>(
      () => GenaDatabase(driftDatabase(name: 'gena')),
    );
  }
  if (!sl.isRegistered<ThemeCubit>()) {
    sl.registerLazySingleton<ThemeCubit>(ThemeCubit.new);
  }
  if (!sl.isRegistered<WorkspaceDocumentParser>()) {
    sl.registerLazySingleton<WorkspaceDocumentParser>(WorkspaceDocumentParser.new);
  }
  if (!sl.isRegistered<WorkspaceRagVectorStore>()) {
    sl.registerLazySingleton<WorkspaceRagVectorStore>(
      WorkspaceRagVectorStore.new,
    );
  }
  if (!sl.isRegistered<WorkspaceRagIngestionQueue>()) {
    sl.registerLazySingleton<WorkspaceRagIngestionQueue>(
      () => WorkspaceRagIngestionQueue(
        database: sl<GenaDatabase>(),
        parser: sl<WorkspaceDocumentParser>(),
        vectorStore: sl<WorkspaceRagVectorStore>(),
      ),
    );
  }
  if (!sl.isRegistered<WorkspaceRagIngestionBootstrap>()) {
    sl.registerLazySingleton<WorkspaceRagIngestionBootstrap>(
      () => WorkspaceRagIngestionBootstrap(sl<WorkspaceRagIngestionQueue>()),
    );
  }
  if (!sl.isRegistered<WorkspaceRagActions>()) {
    sl.registerLazySingleton<WorkspaceRagActions>(
      () => WorkspaceRagActions(
        database: sl<GenaDatabase>(),
        parser: sl<WorkspaceDocumentParser>(),
        vectorStore: sl<WorkspaceRagVectorStore>(),
        ingestionQueue: sl<WorkspaceRagIngestionQueue>(),
        ingestionBootstrap: sl<WorkspaceRagIngestionBootstrap>(),
      ),
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
  if (!sl.isRegistered<SelectedChatCubit>()) {
    sl.registerLazySingleton<SelectedChatCubit>(
      () => SelectedChatCubit(
        database: sl<GenaDatabase>(),
        selectedWorkspaceCubit: sl<SelectedWorkspaceCubit>(),
      ),
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
  if (!sl.isRegistered<WorkspaceQueriesService>()) {
    sl.registerLazySingleton<WorkspaceQueriesService>(
      () => WorkspaceQueriesService(
        database: sl<GenaDatabase>(),
        selectedWorkspaceCubit: sl<SelectedWorkspaceCubit>(),
      ),
    );
  }
  if (!sl.isRegistered<WorkspaceDocumentsService>()) {
    sl.registerLazySingleton<WorkspaceDocumentsService>(
      () => WorkspaceDocumentsService(
        database: sl<GenaDatabase>(),
        ingestionBootstrap: sl<WorkspaceRagIngestionBootstrap>(),
      ),
    );
  }
  if (!sl.isRegistered<WorkspaceActions>()) {
    sl.registerLazySingleton<WorkspaceActions>(
      () => WorkspaceActions(
        database: sl<GenaDatabase>(),
        selectedWorkspaceCubit: sl<SelectedWorkspaceCubit>(),
        selectedChatCubit: sl<SelectedChatCubit>(),
        workspaceDrawerCubit: sl<WorkspaceDrawerCubit>(),
        workspaceRagActions: sl<WorkspaceRagActions>(),
      ),
    );
  }
  if (!sl.isRegistered<WorkspaceConfigActions>()) {
    sl.registerLazySingleton<WorkspaceConfigActions>(
      () => WorkspaceConfigActions(
        workspaceActions: sl<WorkspaceActions>(),
        embedderInstallCubit: sl<WorkspaceEmbedderInstallCubit>(),
      ),
    );
  }
}

Future<void> disposeServiceLocator() async {
  if (sl.isRegistered<GenaDatabase>()) {
    await sl<GenaDatabase>().close();
  }
  await sl.reset(dispose: false);
}
