import 'dart:async';

import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/logger.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/cubits/chat_ui_cubits.dart';
import 'package:gena/features/chat/data/cubits/selected_chat_cubit.dart';
import 'package:gena/features/chat/data/models/gemma_chat_session.dart';
import 'package:gena/features/chat/data/providers/active_model_info_provider.dart';
import 'package:gena/features/chat/data/providers/chat_session_provider.dart';
import 'package:gena/features/chat/data/services/chat_runtime_dependencies.dart';
import 'package:gena/features/chat/data/services/chat_thread_context_service.dart';
import 'package:gena/features/chat/data/services/chat_thread_execution_service.dart';
import 'package:gena/features/chat/data/services/chat_title_service.dart';
import 'package:gena/features/chat/data/services/remote_llm_service.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';

class ChatThreadActions {
  ChatThreadActions({
    required db.GenaDatabase database,
    required SelectedChatCubit selectedChatCubit,
    required ActiveModelInfoResolver activeModelInfoResolver,
    required ChatSessionController sessionController,
    required ChatGeneratingCubit chatGeneratingCubit,
    required ChatDraftResponseCubit chatDraftResponseCubit,
    required ChatDraftThinkingCubit chatDraftThinkingCubit,
    required ChatToolWaitingCubit chatToolWaitingCubit,
    required ChatRuntimeDependencies runtimeDependencies,
  }) : _database = database,
       _selectedChatCubit = selectedChatCubit,
       _activeModelInfoResolver = activeModelInfoResolver,
       _sessionController = sessionController,
       _chatGeneratingCubit = chatGeneratingCubit,
       _chatDraftResponseCubit = chatDraftResponseCubit,
       _chatDraftThinkingCubit = chatDraftThinkingCubit,
       _chatToolWaitingCubit = chatToolWaitingCubit,
       _runtimeDependencies = runtimeDependencies;

  final db.GenaDatabase _database;
  final SelectedChatCubit _selectedChatCubit;
  final ActiveModelInfoResolver _activeModelInfoResolver;
  final ChatSessionController _sessionController;
  final ChatGeneratingCubit _chatGeneratingCubit;
  final ChatDraftResponseCubit _chatDraftResponseCubit;
  final ChatDraftThinkingCubit _chatDraftThinkingCubit;
  final ChatToolWaitingCubit _chatToolWaitingCubit;
  final ChatRuntimeDependencies _runtimeDependencies;

  int _generationSerial = 0;
  int? _cancelGenerationSerial;
  Completer<void>? _remoteAbortCompleter;
  GemmaChatSession? _activeLocalGenerationSession;

  Future<void> sendMessage(String rawText, {String? imagePath}) async {
    final text = rawText.trim();
    final normalizedImagePath = imagePath?.trim();
    final hasImage =
        normalizedImagePath != null && normalizedImagePath.isNotEmpty;
    if (text.isEmpty && !hasImage) return;

    var chatId = _selectedChatCubit.state;
    chatId ??= await _selectedChatCubit.createNewThread();

    final parsedChatId = int.tryParse(chatId);
    if (parsedChatId == null) return;

    final activeModel = await _activeModelInfoResolver.getActiveModelInfo();
    if (activeModel == null) {
      await AppToast.show(
        'No model selected. Please add/select a model first.',
        type: AppToastType.info,
      );
      return;
    }

    final currentGeneration = ++_generationSerial;
    _cancelGenerationSerial = null;
    _remoteAbortCompleter = null;

    try {
      await storeUserMessage(
        database: _database,
        chatId: parsedChatId,
        text: text,
        hasImage: hasImage,
        imagePath: normalizedImagePath,
      );
      _chatGeneratingCubit.setGenerating(true);
      _chatDraftResponseCubit.setDraft('');
      _chatDraftThinkingCubit.clear();
      _chatToolWaitingCubit.clear();

      if (activeModel.provider == ModelProviderType.remote) {
        final remoteAbortCompleter = Completer<void>();
        _remoteAbortCompleter = remoteAbortCompleter;

        await generateRemoteAssistantResponse(
          deps: _runtimeDependencies,
          database: _database,
          chatId: parsedChatId,
          activeModel: activeModel,
          abortTrigger: remoteAbortCompleter.future,
          isCancelled: () => _cancelGenerationSerial == currentGeneration,
        );

        if (_cancelGenerationSerial == currentGeneration) return;

        scheduleThreadTitleUpdate(
          sessionController: _sessionController,
          database: _database,
          chatId: parsedChatId,
          messageText: text,
          hasImage: hasImage,
          activeModel: activeModel,
        );
      } else {
        GemmaChatSession? session;
        try {
          session = await _sessionController.getActiveChatSession();
        } catch (error, stackTrace) {
          logger.e(error, error: error);
          if (_cancelGenerationSerial == currentGeneration) {
            return;
          }
          logger.w(
            'Chat session became unavailable while preparing local generation: $error',
            stackTrace: stackTrace,
          );
          return;
        }
        if (session == null) {
          await AppToast.show(
            'Model is not ready yet. Please wait a moment and try again.',
            type: AppToastType.info,
          );
          return;
        }
        _activeLocalGenerationSession = session;

        final modelRuntime = await _sessionController.getRuntime();
        if (modelRuntime == null) {
          await AppToast.show(
            'No active model available. Please select or install a model.',
            type: AppToastType.info,
          );
          return;
        }

        final shouldHandleThinking =
            modelRuntime.defaultIsThinking &&
            supportsThinkingModel(modelRuntime.modelType);

        await prepareContext(
          deps: _runtimeDependencies,
          database: _database,
          chatId: parsedChatId,
          chat: session.chat,
          maxTokens: modelRuntime.maxTokens,
          tokenBuffer: modelRuntime.tokenBuffer,
        );

        if (_cancelGenerationSerial == currentGeneration) return;

        await generateAssistantResponse(
          deps: _runtimeDependencies,
          session: session,
          modelType: modelRuntime.modelType,
          shouldHandleThinking: shouldHandleThinking,
          database: _database,
          chatId: parsedChatId,
          isCancelled: () => _cancelGenerationSerial == currentGeneration,
        );

        if (_cancelGenerationSerial == currentGeneration) return;

        scheduleThreadTitleUpdate(
          sessionController: _sessionController,
          database: _database,
          chatId: parsedChatId,
          messageText: text,
          hasImage: hasImage,
          activeModel: activeModel,
        );
      }
    } catch (error, stackTrace) {
      if (_cancelGenerationSerial == currentGeneration ||
          error is RemoteGenerationCancelled) {
        return;
      }
      logger.e(
        'Failed to send/generate chat response',
        error: error,
        stackTrace: stackTrace,
      );
      await AppToast.show('Message failed: $error', type: AppToastType.error);
    } finally {
      _activeLocalGenerationSession = null;
      _remoteAbortCompleter = null;
      if (_cancelGenerationSerial == currentGeneration) {
        _cancelGenerationSerial = null;
      }
      _chatGeneratingCubit.setGenerating(false);
      _chatDraftResponseCubit.clear();
      _chatDraftThinkingCubit.clear();
      _chatToolWaitingCubit.clear();
    }
  }

  Future<void> stopGeneration({
    bool triggerLocalModelCancel = true,
    bool waitForLocalModelCancel = true,
  }) async {
    if (!_chatGeneratingCubit.state) return;

    _cancelGenerationSerial = _generationSerial;
    if (_remoteAbortCompleter != null && !_remoteAbortCompleter!.isCompleted) {
      _remoteAbortCompleter!.complete();
    }

    final selectedModel = await _activeModelInfoResolver.getActiveModelInfo();
    final localSession = _activeLocalGenerationSession;
    if (triggerLocalModelCancel &&
        selectedModel?.provider == ModelProviderType.local &&
        localSession != null) {
      final stopFuture = localSession.chat.stopGeneration().timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
      if (waitForLocalModelCancel) {
        await stopFuture;
      } else {
        unawaited(
          stopFuture.catchError(
            (error, stackTrace) => logger.w(
              'Local stopGeneration finished with warning: $error',
              stackTrace: stackTrace,
            ),
          ),
        );
      }
    }

    _chatGeneratingCubit.setGenerating(false);
    _chatDraftThinkingCubit.clear();
    _chatToolWaitingCubit.clear();
  }
}
