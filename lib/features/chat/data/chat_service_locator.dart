import 'package:gena/core/database/gena_database.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/core/local_ai/local_ai_runtime_coordinator.dart';
import 'package:gena/features/chat/presentation/cubit/chat_input_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/chat_attachments_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/chat_ui_cubits.dart';
import 'package:gena/features/chat/presentation/cubit/native_tool_execution_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/selected_chat_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/selected_model_cubit.dart';
import 'package:gena/features/chat/data/services/active_model_info_service.dart';
import 'package:gena/features/chat/data/services/chat_attachment_preparation_service.dart';
import 'package:gena/features/chat/data/services/chat_history_actions_service.dart';
import 'package:gena/features/chat/data/services/chat_page_actions_service.dart';
import 'package:gena/features/chat/data/services/chat_thread_actions_service.dart';
import 'package:gena/features/chat/data/tools/native_tool_actions_service.dart';
import 'package:gena/features/chat/data/repositories/chat_queries_repository.dart';
import 'package:gena/features/chat/data/services/chat_runtime_dependencies.dart';
import 'package:gena/features/chat/data/services/local_model_runtime.dart';
import 'package:gena/features/chat/data/services/local_model_runtime_factory.dart';
import 'package:gena/features/chat/data/services/coordinated_local_model_runtime.dart';
import 'package:gena/features/chat/data/services/coordinated_speech_to_text.dart';
import 'package:gena/features/chat/data/services/audio_recorder_factory.dart';
import 'package:gena/features/chat/data/services/chat_generation_signal_service.dart';
import 'package:gena/features/chat/data/services/speech_segmenter_factory.dart';
import 'package:gena/features/chat/data/services/speech_to_text.dart';
import 'package:gena/features/chat/data/services/speech_to_text_factory.dart';
import 'package:gena/features/chat/data/services/text_to_speech.dart';
import 'package:gena/features/chat/presentation/cubit/voice_conversation_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/voice_input_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/voice_output_cubit.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/tools/native_tool_bridge_service.dart';
import 'package:gena/features/mcp/data/mcp_repository.dart';
import 'package:gena/features/mcp/data/services/mcp_client_manager.dart';
import 'package:gena/features/mcp/data/services/mcp_tool_actions_service.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/presentation/cubit/downloads_cubit.dart';
import 'package:gena/features/workspace/presentation/cubit/selected_workspace_cubit.dart';
import 'package:gena/features/workspace/data/services/workspace_memory_actions.dart';
import 'package:gena/features/workspace/data/services/workspace_queries_entity_service.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_actions.dart';
import 'package:gena/features/workspace/data/services/workspace_document_parser.dart';

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
  if (!sl.isRegistered<ChatGenerationFailureCubit>()) {
    sl.registerLazySingleton<ChatGenerationFailureCubit>(
      ChatGenerationFailureCubit.new,
    );
  }
  if (!sl.isRegistered<ChatContextWindowCubit>()) {
    sl.registerLazySingleton<ChatContextWindowCubit>(
      ChatContextWindowCubit.new,
    );
  }
  if (!sl.isRegistered<ChatAttachmentPreparationService>()) {
    sl.registerLazySingleton<ChatAttachmentPreparationService>(
      () => ChatAttachmentPreparationService(
        parser: sl<WorkspaceDocumentParser>(),
      ),
    );
  }
  if (!sl.isRegistered<ChatAttachmentsCubit>()) {
    sl.registerLazySingleton<ChatAttachmentsCubit>(
      () => ChatAttachmentsCubit(
        preparer: sl<ChatAttachmentPreparationService>(),
      ),
    );
  }
  if (!sl.isRegistered<SelectedModelCubit>()) {
    sl.registerLazySingleton<SelectedModelCubit>(SelectedModelCubit.new);
  }

  // Local model runtime (native llamadart, or unsupported on web)
  if (!sl.isRegistered<LocalModelRuntime>()) {
    sl.registerLazySingleton<LocalModelRuntime>(
      () => CoordinatedLocalModelRuntime(
        delegate: createLocalModelRuntime(),
        coordinator: sl<LocalAiRuntimeCoordinator>(),
      ),
    );
  }

  // On-device speech-to-text (native whisper, or unsupported on web)
  if (!sl.isRegistered<SpeechToText>()) {
    sl.registerLazySingleton<SpeechToText>(
      () => CoordinatedSpeechToText(
        delegate: createSpeechToText(),
        coordinator: sl<LocalAiRuntimeCoordinator>(),
      ),
    );
  }
  if (!sl.isRegistered<VoiceAudioRecorder>()) {
    sl.registerLazySingleton<VoiceAudioRecorder>(createVoiceAudioRecorder);
  }

  // Platform-native text-to-speech (flutter_tts; web + native).
  if (!sl.isRegistered<TextToSpeech>()) {
    sl.registerLazySingleton<TextToSpeech>(FlutterTextToSpeech.new);
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
        localModelRuntime: sl<LocalModelRuntime>(),
        nativeToolActions: sl<NativeToolActions>(),
        workspaceQueries: sl<WorkspaceQueries>(),
        workspaceRagActions: sl<WorkspaceRagActions>(),
        workspaceMemoryActions: sl<WorkspaceMemoryActions>(),
        mcpRepository: sl<McpRepository>(),
        mcpClientManager: sl<McpClientManager>(),
        mcpToolActions: sl<McpToolActions>(),
      ),
    );
  }

  if (!sl.isRegistered<ChatThreadActions>()) {
    sl.registerLazySingleton<ChatThreadActions>(
      () => ChatThreadActions(
        database: sl<GenaDatabase>(),
        selectedChatCubit: sl<SelectedChatCubit>(),
        activeModelInfoResolver: sl<ActiveModelInfoResolver>(),
        localModelRuntime: sl<LocalModelRuntime>(),
        chatGeneratingCubit: sl<ChatGeneratingCubit>(),
        chatDraftResponseCubit: sl<ChatDraftResponseCubit>(),
        chatDraftThinkingCubit: sl<ChatDraftThinkingCubit>(),
        chatToolWaitingCubit: sl<ChatToolWaitingCubit>(),
        chatGenerationFailureCubit: sl<ChatGenerationFailureCubit>(),
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
      () => ChatInputCubit(
        chatThreadActions: sl<ChatThreadActions>(),
        attachmentsCubit: sl<ChatAttachmentsCubit>(),
      ),
    );
  }

  if (!sl.isRegistered<VoiceInputCubit>()) {
    sl.registerLazySingleton<VoiceInputCubit>(
      () => VoiceInputCubit(
        recorder: sl<VoiceAudioRecorder>(),
        speechToText: sl<SpeechToText>(),
        chatInputCubit: sl<ChatInputCubit>(),
        onError: (message) => AppToast.show(message, type: AppToastType.error),
      ),
    );
  }

  if (!sl.isRegistered<VoiceOutputCubit>()) {
    sl.registerLazySingleton<VoiceOutputCubit>(
      () => VoiceOutputCubit(
        textToSpeech: sl<TextToSpeech>(),
        onError: (message) => AppToast.show(message, type: AppToastType.error),
      ),
    );
  }

  if (!sl.isRegistered<GenerationSignal>()) {
    sl.registerLazySingleton<GenerationSignal>(
      () => ChatGenerationSignal(
        generatingCubit: sl<ChatGeneratingCubit>(),
        draftResponseCubit: sl<ChatDraftResponseCubit>(),
      ),
    );
  }

  // Fresh per page push: the cubit owns a live VAD/mic + TTS session and tears
  // it down on close, so it must not be shared as a singleton. A fresh
  // segmenter is created per cubit for the same reason.
  if (!sl.isRegistered<VoiceConversationCubit>()) {
    sl.registerFactory<VoiceConversationCubit>(
      () => VoiceConversationCubit(
        segmenter: createSpeechSegmenter(),
        speechToText: sl<SpeechToText>(),
        textToSpeech: sl<TextToSpeech>(),
        sendMessage: (text) => sl<ChatThreadActions>().sendMessage(text),
        cancelGeneration: () => sl<ChatThreadActions>().stopGeneration(),
        generationSignal: sl<GenerationSignal>(),
        onError: (message) => AppToast.show(message, type: AppToastType.error),
      ),
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
        modelRepository: sl<ModelRepository>(),
        modelInstallerService: sl<ModelInstallerService>(),
        localModelRuntime: sl<LocalModelRuntime>(),
      ),
    );
  }
}
