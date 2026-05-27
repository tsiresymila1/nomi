import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/models/gemma_chat_session.dart';
import 'package:gena/features/chat/data/providers/active_model_info_provider.dart';
import 'package:gena/features/chat/data/providers/chat_session_provider.dart';
import 'package:gena/features/chat/data/providers/chat_ui_state_provider.dart';
import 'package:gena/features/chat/data/providers/selected_chat_provider.dart';
import 'package:gena/features/chat/data/services/chat_thread_context_service.dart';
import 'package:gena/features/chat/data/services/chat_thread_execution_service.dart';
import 'package:gena/features/chat/data/services/chat_title_service.dart';
import 'package:gena/features/chat/data/services/remote_llm_service.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';

final chatThreadActionsProvider = Provider<ChatThreadActions>(
  (ref) => ChatThreadActions(ref),
);

class ChatThreadActions {
  final Ref ref;
  int _generationSerial = 0;
  int? _cancelGenerationSerial;
  Completer<void>? _remoteAbortCompleter;
  GemmaChatSession? _activeLocalGenerationSession;

  ChatThreadActions(this.ref);

  Future<void> sendMessage(String rawText, {String? imagePath}) async {
    final text = rawText.trim();
    final normalizedImagePath = imagePath?.trim();
    final hasImage =
        normalizedImagePath != null && normalizedImagePath.isNotEmpty;
    if (text.isEmpty && !hasImage) return;

    var chatId = ref.read(selectedChatIdProvider);
    chatId ??= await ref
        .read(selectedChatIdProvider.notifier)
        .createNewThread();

    final parsedChatId = int.tryParse(chatId);
    if (parsedChatId == null) return;

    final activeModel = ref.read(activeModelInfoProvider);
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

    ref.read(chatGeneratingProvider.notifier).setGenerating(true);
    ref.read(chatDraftResponseProvider.notifier).setDraft('');
    ref.read(chatDraftThinkingProvider.notifier).clear();
    ref.read(chatToolWaitingProvider.notifier).clear();

    try {
      final database = ref.read(genaDatabaseProvider);
      await storeUserMessage(
        database: database,
        chatId: parsedChatId,
        text: text,
        hasImage: hasImage,
        imagePath: normalizedImagePath,
      );

      if (activeModel.provider == ModelProviderType.remote) {
        final remoteAbortCompleter = Completer<void>();
        _remoteAbortCompleter = remoteAbortCompleter;

        await generateRemoteAssistantResponse(
          ref: ref,
          database: database,
          chatId: parsedChatId,
          activeModel: activeModel,
          abortTrigger: remoteAbortCompleter.future,
          isCancelled: () => _cancelGenerationSerial == currentGeneration,
        );

        if (_cancelGenerationSerial == currentGeneration) return;

        scheduleThreadTitleUpdate(
          ref: ref,
          database: database,
          chatId: parsedChatId,
          messageText: text,
          hasImage: hasImage,
          activeModel: activeModel,
        );
      } else {
        GemmaChatSession? session;
        try {
          session = await ref.read(activeGemmaChatProvider.future);
        } catch (e, stackTrace) {
          logger.e(e, error: e);
          if (_cancelGenerationSerial == currentGeneration) {
            return;
          }
          logger.w(
            'Chat session became unavailable while preparing local generation: $e',
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

        final modelRuntime = await ref.read(activeGemmaModelRuntimeProvider.future);
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
          ref: ref,
          database: database,
          chatId: parsedChatId,
          chat: session.chat,
          maxTokens: modelRuntime.maxTokens,
          tokenBuffer: modelRuntime.tokenBuffer,
        );

        if (_cancelGenerationSerial == currentGeneration) return;

        await generateAssistantResponse(
          ref: ref,
          session: session,
          modelType: modelRuntime.modelType,
          shouldHandleThinking: shouldHandleThinking,
          database: database,
          chatId: parsedChatId,
          isCancelled: () => _cancelGenerationSerial == currentGeneration,
        );

        if (_cancelGenerationSerial == currentGeneration) return;

        scheduleThreadTitleUpdate(
          ref: ref,
          database: database,
          chatId: parsedChatId,
          messageText: text,
          hasImage: hasImage,
          activeModel: activeModel,
        );
      }
    } catch (e, stackTrace) {
      if (_cancelGenerationSerial == currentGeneration ||
          e is RemoteGenerationCancelled) {
        return;
      }
      logger.e(
        'Failed to send/generate chat response',
        error: e,
        stackTrace: stackTrace,
      );
      await AppToast.show('Message failed: $e', type: AppToastType.error);
    } finally {
      _activeLocalGenerationSession = null;
      _remoteAbortCompleter = null;
      if (_cancelGenerationSerial == currentGeneration) {
        _cancelGenerationSerial = null;
      }
      ref.read(chatGeneratingProvider.notifier).setGenerating(false);
      ref.read(chatDraftResponseProvider.notifier).clear();
      ref.read(chatDraftThinkingProvider.notifier).clear();
      ref.read(chatToolWaitingProvider.notifier).clear();
    }
  }

  Future<void> stopGeneration({
    bool triggerLocalModelCancel = true,
    bool waitForLocalModelCancel = true,
  }) async {
    if (!ref.read(chatGeneratingProvider)) return;

    _cancelGenerationSerial = _generationSerial;
    if (_remoteAbortCompleter != null && !_remoteAbortCompleter!.isCompleted) {
      _remoteAbortCompleter!.complete();
    }

    final selectedModel = ref.read(activeModelInfoProvider);
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

    ref.read(chatGeneratingProvider.notifier).setGenerating(false);
    ref.read(chatDraftThinkingProvider.notifier).clear();
    ref.read(chatToolWaitingProvider.notifier).clear();
  }
}
