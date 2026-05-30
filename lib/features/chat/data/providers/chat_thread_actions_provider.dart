import 'dart:async';

import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/logger.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/cubits/chat_ui_cubits.dart';
import 'package:gena/features/chat/data/cubits/selected_chat_cubit.dart';
import 'package:gena/features/chat/data/providers/active_model_info_provider.dart';
import 'package:gena/features/chat/data/providers/chat_session_provider.dart';
import 'package:gena/features/chat/data/services/genkit_chat_service.dart';
import 'package:gena/features/chat/data/services/chat_runtime_dependencies.dart';
import 'package:gena/features/chat/data/services/chat_thread_execution_service.dart';
import 'package:gena/features/chat/data/services/chat_title_service.dart';

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

      final localRuntime = await _sessionController.getRuntime();
      if (activeModel.provider == 'local' && localRuntime == null) {
        await AppToast.show(
          'Model is not ready yet. Please wait a moment and try again.',
          type: AppToastType.info,
        );
        return;
      }

      await generateAssistantResponseWithGenkit(
        deps: _runtimeDependencies,
        database: _database,
        chatId: parsedChatId,
        activeModel: activeModel,
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
    } catch (error, stackTrace) {
      if (_cancelGenerationSerial == currentGeneration) {
        return;
      }
      final rawError = error.toString();
      final isMissingLiteRtSymbol =
          rawError.contains('litert_lm_conversation_optional_args_create') &&
          rawError.contains('undefined symbol');
      logger.e(
        'Failed to send/generate chat response',
        error: error,
        stackTrace: stackTrace,
      );
      if (isMissingLiteRtSymbol) {
        await AppToast.show(
          'Local runtime mismatch detected. Run flutter clean and reinstall app.',
          type: AppToastType.error,
        );
      } else {
        await AppToast.show('Message failed: $error', type: AppToastType.error);
      }
    } finally {
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
    _cancelGenerationSerial = _generationSerial;
    final activeModel = await _activeModelInfoResolver.getActiveModelInfo();

    if (triggerLocalModelCancel && activeModel?.provider == 'local') {
      final cancelFuture = _cancelActiveLocalGeneration();
      if (waitForLocalModelCancel) {
        await cancelFuture;
      } else {
        unawaited(cancelFuture);
      }
    }

    _chatGeneratingCubit.setGenerating(false);
    _chatDraftThinkingCubit.clear();
    _chatToolWaitingCubit.clear();
  }

  Future<void> _cancelActiveLocalGeneration() async {
    try {
      final activeSession = _sessionController.currentChatSession;
      if (activeSession != null) {
        await activeSession.chat.stopGeneration();
      }
    } catch (error, stackTrace) {
      logger.w(
        'Failed to cancel active local chat session generation: $error',
        stackTrace: stackTrace,
      );
    }

    try {
      final runtime = await _sessionController.getRuntime();
      final model = runtime?.model;
      if (model == null) return;

      final activeChat = model.chat;
      if (activeChat != null) {
        await activeChat.stopGeneration();
      }

      final sessions = model.sessions;
      for (final session in sessions) {
        await session.stopGeneration();
      }
    } catch (error, stackTrace) {
      logger.w(
        'Failed to cancel active local model generation sessions: $error',
        stackTrace: stackTrace,
      );
    }
  }
}
