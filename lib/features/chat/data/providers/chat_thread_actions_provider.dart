import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/providers/chat_session_provider.dart';
import 'package:gena/features/chat/data/services/chat_thread_context_service.dart';
import 'package:gena/features/chat/data/services/chat_thread_execution_service.dart';
import 'package:gena/features/chat/data/providers/chat_ui_state_provider.dart';
import 'package:gena/features/chat/data/providers/selected_chat_provider.dart';

final chatThreadActionsProvider = Provider<ChatThreadActions>(
  (ref) => ChatThreadActions(ref),
);

class ChatThreadActions {
  final Ref ref;
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

    ref.read(chatGeneratingProvider.notifier).setGenerating(true);
    ref.read(chatDraftResponseProvider.notifier).setDraft('');
    ref.read(chatDraftThinkingProvider.notifier).clear();
    ref.read(chatToolWaitingProvider.notifier).clear();

    try {
      final session = await ref.read(activeGemmaChatProvider.future);
      if (session == null) {
        await AppToast.show(
          'Model is not ready yet. Please wait a moment and try again.',
          type: AppToastType.info,
        );
        return;
      }

      final modelRuntime = await ref.read(
        activeGemmaModelRuntimeProvider.future,
      );
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

      final database = ref.read(genaDatabaseProvider);
      await storeUserMessage(
        database: database,
        chatId: parsedChatId,
        text: text,
        hasImage: hasImage,
        imagePath: normalizedImagePath,
      );

      await prepareContext(
        ref: ref,
        database: database,
        chatId: parsedChatId,
        chat: session.chat,
        maxTokens: modelRuntime.maxTokens,
        tokenBuffer: modelRuntime.tokenBuffer,
      );

      await generateAssistantResponse(
        ref: ref,
        session: session,
        modelType: modelRuntime.modelType,
        shouldHandleThinking: shouldHandleThinking,
        database: database,
        chatId: parsedChatId,
      );
    } catch (e, stackTrace) {
      logger.e(
        'Failed to send/generate chat response',
        error: e,
        stackTrace: stackTrace,
      );
      await AppToast.show('Message failed: $e', type: AppToastType.error);
    } finally {
      ref.read(chatGeneratingProvider.notifier).setGenerating(false);
      ref.read(chatDraftResponseProvider.notifier).clear();
      ref.read(chatDraftThinkingProvider.notifier).clear();
      ref.read(chatToolWaitingProvider.notifier).clear();
    }
  }

  Future<void> stopGeneration() async {
    if (!ref.read(chatGeneratingProvider)) return;

    final session = await ref.read(activeGemmaChatProvider.future);
    if (session == null) return;

    try {
      await session.chat.stopGeneration();
    } finally {
      ref.read(chatGeneratingProvider.notifier).setGenerating(false);
      ref.read(chatDraftThinkingProvider.notifier).clear();
      ref.read(chatToolWaitingProvider.notifier).clear();
    }
  }
}
