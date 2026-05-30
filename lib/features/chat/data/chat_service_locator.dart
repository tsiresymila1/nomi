import 'package:gena/core/database/gena_database.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/chat/data/cubits/chat_input_cubit.dart';
import 'package:gena/features/chat/data/cubits/chat_ui_cubits.dart';
import 'package:gena/features/chat/data/cubits/native_tool_execution_cubit.dart';
import 'package:gena/features/chat/data/cubits/selected_chat_cubit.dart';
import 'package:gena/features/chat/data/cubits/selected_model_cubit.dart';
import 'package:gena/features/chat/data/providers/active_model_info_provider.dart';
import 'package:gena/features/chat/data/providers/chat_history_actions_provider.dart';
import 'package:gena/features/chat/data/providers/chat_page_actions_provider.dart';
import 'package:gena/features/chat/data/providers/chat_session_provider.dart';
import 'package:gena/features/chat/data/providers/chat_thread_actions_provider.dart';
import 'package:gena/features/chat/data/providers/native_tool_actions_provider.dart';
import 'package:gena/features/chat/data/repositories/chat_queries_repository.dart';
import 'package:gena/features/chat/data/services/chat_runtime_dependencies.dart';
import 'package:gena/features/chat/data/services/native_tool_bridge_service.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/presentation/cubit/downloads_cubit.dart';
import 'package:gena/features/workspace/data/cubits/selected_workspace_cubit.dart';
import 'package:gena/features/workspace/data/providers/workspace_queries_provider.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_actions.dart';

void registerChatDependencies() {
  // Cubits (no deps)
  if (!sl.isRegistered<ChatModelSwitchingCubit>()) {
    sl.registerLazySingleton<ChatModelSwitchingCubit>(
      ChatModelSwitchingCubit.new,
    );
  }
  if (!sl.isRegistered<NativeToolExecutionCubit>()) {
    sl.registerLazySingleton<NativeToolExecutionCubit>(
      NativeToolExecutionCubit.new,
    );
  }
  if (!sl.isRegistered<ChatGeneratingCubit>()) {
    sl.registerLazySingleton<ChatGeneratingCubit>(ChatGeneratingCubit.new);
  }
  if (!sl.isRegistered<ChatDraftResponseCubit>()) {
    sl.registerLazySingleton<ChatDraftResponseCubit>(
      ChatDraftResponseCubit.new,
    );
  }
  if (!sl.isRegistered<ChatDraftThinkingCubit>()) {
    sl.registerLazySingleton<ChatDraftThinkingCubit>(
      ChatDraftThinkingCubit.new,
    );
  }
  if (!sl.isRegistered<ChatToolWaitingCubit>()) {
    sl.registerLazySingleton<ChatToolWaitingCubit>(ChatToolWaitingCubit.new);
  }
  if (!sl.isRegistered<ChatContextWindowCubit>()) {
    sl.registerLazySingleton<ChatContextWindowCubit>(
      ChatContextWindowCubit.new,
    );
  }
  if (!sl.isRegistered<SelectedModelCubit>()) {
    sl.registerLazySingleton<SelectedModelCubit>(SelectedModelCubit.new);
  }

  // Services (no deps or minimal deps)
  if (!sl.isRegistered<NativeToolBridgeService>()) {
    sl.registerLazySingleton<NativeToolBridgeService>(
      NativeToolBridgeService.new,
    );
  }

  // Actions with deps
  if (!sl.isRegistered<NativeToolActions>()) {
    sl.registerLazySingleton<NativeToolActions>(
      () => NativeToolActions(
        bridgeService: sl<NativeToolBridgeService>(),
        executionCubit: sl<NativeToolExecutionCubit>(),
      ),
    );
  }

  if (!sl.isRegistered<ActiveModelInfoResolver>()) {
    sl.registerLazySingleton<ActiveModelInfoResolver>(
      () => ActiveModelInfoResolver(
        modelRepository: sl<ModelRepository>(),
        selectedModelCubit: sl<SelectedModelCubit>(),
      ),
    );
  }

  if (!sl.isRegistered<WorkspaceQueries>()) {
    sl.registerLazySingleton<WorkspaceQueries>(
      () => WorkspaceQueries(
        database: sl<GenaDatabase>(),
        selectedWorkspaceCubit: sl<SelectedWorkspaceCubit>(),
      ),
    );
  }

  if (!sl.isRegistered<ChatSessionController>()) {
    sl.registerLazySingleton<ChatSessionController>(
      () => ChatSessionController(
        database: sl<GenaDatabase>(),
        activeModelInfoResolver: sl<ActiveModelInfoResolver>(),
        workspaceQueries: sl<WorkspaceQueries>(),
        selectedChatCubit: sl<SelectedChatCubit>(),
      ),
    );
  }

  if (!sl.isRegistered<ChatQueriesRepository>()) {
    sl.registerLazySingleton<ChatQueriesRepository>(
      () => ChatQueriesRepository(
        database: sl<GenaDatabase>(),
        selectedWorkspaceCubit: sl<SelectedWorkspaceCubit>(),
      ),
    );
  }

  if (!sl.isRegistered<ChatRuntimeDependencies>()) {
    sl.registerLazySingleton<ChatRuntimeDependencies>(
      () => ChatRuntimeDependencies(
        chatDraftResponseCubit: sl<ChatDraftResponseCubit>(),
        chatDraftThinkingCubit: sl<ChatDraftThinkingCubit>(),
        chatToolWaitingCubit: sl<ChatToolWaitingCubit>(),
        chatContextWindowCubit: sl<ChatContextWindowCubit>(),
        nativeToolActions: sl<NativeToolActions>(),
        workspaceQueries: sl<WorkspaceQueries>(),
        workspaceRagActions: sl<WorkspaceRagActions>(),
      ),
    );
  }

  if (!sl.isRegistered<ChatThreadActions>()) {
    sl.registerLazySingleton<ChatThreadActions>(
      () => ChatThreadActions(
        database: sl<GenaDatabase>(),
        selectedChatCubit: sl<SelectedChatCubit>(),
        activeModelInfoResolver: sl<ActiveModelInfoResolver>(),
        sessionController: sl<ChatSessionController>(),
        chatGeneratingCubit: sl<ChatGeneratingCubit>(),
        chatDraftResponseCubit: sl<ChatDraftResponseCubit>(),
        chatDraftThinkingCubit: sl<ChatDraftThinkingCubit>(),
        chatToolWaitingCubit: sl<ChatToolWaitingCubit>(),
        runtimeDependencies: sl<ChatRuntimeDependencies>(),
      ),
    );
  }

  if (!sl.isRegistered<ChatHistoryActions>()) {
    sl.registerLazySingleton<ChatHistoryActions>(
      () => ChatHistoryActions(
        database: sl<GenaDatabase>(),
        selectedChatCubit: sl<SelectedChatCubit>(),
        selectedWorkspaceCubit: sl<SelectedWorkspaceCubit>(),
        chatThreadActions: sl<ChatThreadActions>(),
      ),
    );
  }

  if (!sl.isRegistered<ChatInputCubit>()) {
    sl.registerLazySingleton<ChatInputCubit>(
      () => ChatInputCubit(chatThreadActions: sl<ChatThreadActions>()),
    );
  }

  if (!sl.isRegistered<ChatPageActions>()) {
    sl.registerLazySingleton<ChatPageActions>(
      () => ChatPageActions(
        selectedChatCubit: sl<SelectedChatCubit>(),
        selectedWorkspaceCubit: sl<SelectedWorkspaceCubit>(),
        chatThreadActions: sl<ChatThreadActions>(),
        downloadsCubit: sl<DownloadsCubit>(),
        chatModelSwitchingCubit: sl<ChatModelSwitchingCubit>(),
        selectedModelCubit: sl<SelectedModelCubit>(),
        activeModelInfoResolver: sl<ActiveModelInfoResolver>(),
        modelInstallerService: sl<ModelInstallerService>(),
        chatSessionController: sl<ChatSessionController>(),
      ),
    );
  }
}
