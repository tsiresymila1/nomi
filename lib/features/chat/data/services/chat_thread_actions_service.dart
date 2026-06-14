import 'dart:async';

import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/logger.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/presentation/cubit/chat_ui_cubits.dart';
import 'package:gena/features/chat/presentation/cubit/selected_chat_cubit.dart';
import 'package:gena/features/chat/data/services/active_model_info_service.dart';
import 'package:gena/features/chat/data/services/genkit_chat_service.dart';
import 'package:gena/features/chat/data/services/chat_runtime_dependencies.dart';
import 'package:gena/features/chat/data/services/chat_runtime_helpers.dart';
import 'package:gena/features/chat/data/services/chat_thread_context_service.dart';
import 'package:gena/features/chat/data/services/chat_title_service.dart';
import 'package:gena/features/chat/data/services/local_model_runtime.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';

/// Message shown when an image is attached to a model that cannot read images.
const imageInputUnsupportedMessage =
    "This model can't read images. Pick a vision model.";

/// Whether an image attachment must be rejected for [model]. Returns true only
/// when an image is attached and the model does not declare `supportImage`.
bool isImageInputRejected({required ModelInfo? model, required bool hasImage}) {
  if (!hasImage) return false;
  if (model == null) return false;
  return !model.supportImage;
}

class LocalMessageBudgetPlan {
  const LocalMessageBudgetPlan({
    required this.maxTokens,
    required this.reservedOutputTokens,
    required this.promptTokens,
    required this.messageTokens,
    required this.remainingInputTokens,
    required this.remainingTokensAfterMessage,
    required this.compactedMessages,
  });

  final int maxTokens;
  final int reservedOutputTokens;
  final int promptTokens;
  final int messageTokens;
  final int remainingInputTokens;
  final int remainingTokensAfterMessage;
  final int compactedMessages;

  bool get fits => remainingTokensAfterMessage >= 0;

  int get overflowTokens =>
      remainingTokensAfterMessage < 0 ? -remainingTokensAfterMessage : 0;
}

/// Narrow boundary used by presentation cubits that only need to trigger a
/// send or stop on the active chat thread. Lets those cubits be unit-tested
/// without constructing the full [ChatThreadActions] dependency graph.
abstract interface class ChatThreadActionsApi {
  Future<void> sendMessage(String rawText, {String? imagePath});

  Future<void> stopGeneration({
    bool triggerLocalModelCancel = true,
    bool waitForLocalModelCancel = true,
  });
}

class ChatThreadActions implements ChatThreadActionsApi {
  ChatThreadActions({
    required db.GenaDatabase database,
    required SelectedChatCubit selectedChatCubit,
    required ActiveModelInfoResolver activeModelInfoResolver,
    required LocalModelRuntime localModelRuntime,
    required ChatGeneratingCubit chatGeneratingCubit,
    required ChatDraftResponseCubit chatDraftResponseCubit,
    required ChatDraftThinkingCubit chatDraftThinkingCubit,
    required ChatToolWaitingCubit chatToolWaitingCubit,
    required ChatRuntimeDependencies runtimeDependencies,
  }) : _database = database,
       _selectedChatCubit = selectedChatCubit,
       _activeModelInfoResolver = activeModelInfoResolver,
       _localModelRuntime = localModelRuntime,
       _chatGeneratingCubit = chatGeneratingCubit,
       _chatDraftResponseCubit = chatDraftResponseCubit,
       _chatDraftThinkingCubit = chatDraftThinkingCubit,
       _chatToolWaitingCubit = chatToolWaitingCubit,
       _runtimeDependencies = runtimeDependencies;

  final db.GenaDatabase _database;
  final SelectedChatCubit _selectedChatCubit;
  final ActiveModelInfoResolver _activeModelInfoResolver;
  final LocalModelRuntime _localModelRuntime;
  final ChatGeneratingCubit _chatGeneratingCubit;
  final ChatDraftResponseCubit _chatDraftResponseCubit;
  final ChatDraftThinkingCubit _chatDraftThinkingCubit;
  final ChatToolWaitingCubit _chatToolWaitingCubit;
  final ChatRuntimeDependencies _runtimeDependencies;

  int _generationSerial = 0;
  int? _cancelGenerationSerial;

  @override
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

    if (isImageInputRejected(model: activeModel, hasImage: hasImage)) {
      await AppToast.show(
        imageInputUnsupportedMessage,
        type: AppToastType.info,
      );
      return;
    }

    if (activeModel.provider == 'local') {
      try {
        await _localModelRuntime.prepare(activeModel);
      } catch (error) {
        logger.w('Local model is not ready yet: $error');
        await AppToast.show(
          'Model is not ready yet. Please wait a moment and try again.',
          type: AppToastType.info,
        );
        return;
      }
    }

    if (activeModel.provider == 'local') {
      final messageFits = await _validateLocalMessageFitsContext(
        text: text,
        imagePath: normalizedImagePath,
      );
      if (!messageFits) {
        return;
      }
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

      await generateAssistantResponseWithGenkit(
        deps: _runtimeDependencies,
        database: _database,
        chatId: parsedChatId,
        activeModel: activeModel,
        isCancelled: () => _cancelGenerationSerial == currentGeneration,
      );

      if (_cancelGenerationSerial == currentGeneration) {
        await _persistCancelledDraftIfAny(parsedChatId);
        return;
      }

      scheduleThreadTitleUpdate(
        localModelRuntime: _localModelRuntime,
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

  @override
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
      _localModelRuntime.cancelActiveGeneration();
    } catch (error, stackTrace) {
      logger.w(
        'Failed to cancel active local model generation: $error',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _persistCancelledDraftIfAny(int chatId) async {
    final draft = (_chatDraftResponseCubit.state ?? '').trim();
    if (draft.isEmpty) return;

    await _database
        .into(_database.messages)
        .insert(
          db.MessagesCompanion.insert(
            chat: chatId,
            role: 'assistant',
            kind: const Value('text'),
            content: draft,
          ),
        );
  }

  Future<bool> _validateLocalMessageFitsContext({
    required String text,
    required String? imagePath,
  }) async {
    final budget = await estimateLocalMessageBudget(
      text: text,
      imagePath: imagePath,
    );
    if (budget == null) return true;

    _runtimeDependencies.chatContextWindowCubit.update(
      ChatContextWindowState(
        maxTokens: budget.maxTokens,
        reservedOutputTokens: budget.reservedOutputTokens,
        estimatedPromptTokens: budget.promptTokens,
        remainingTokens: budget.remainingInputTokens.clamp(0, budget.maxTokens),
        compactedMessages: budget.compactedMessages,
      ),
    );

    if (!budget.fits) {
      await AppToast.show(
        'Message is too large for this model context. Shorten it or remove attachments.',
        type: AppToastType.info,
      );
      return false;
    }

    return true;
  }

  Future<LocalMessageBudgetPlan?> estimateLocalMessageBudget({
    required String text,
    required String? imagePath,
  }) async {
    final chatId = _selectedChatCubit.state;
    final parsedChatId = int.tryParse(chatId ?? '');
    if (parsedChatId == null) return null;

    final activeModel = await _activeModelInfoResolver.getActiveModelInfo();
    if (activeModel == null || activeModel.provider != 'local') {
      return null;
    }

    final countTokens = _localModelRuntime.countTokens;

    var messageTokens = await countTokens(text);
    final hasImage = imagePath != null && imagePath.trim().isNotEmpty;
    if (hasImage) {
      messageTokens += 257;
    }

    final activeWorkspace = await _runtimeDependencies.workspaceQueries
        .resolveActiveWorkspace();
    final systemInstruction = buildSystemInstruction(
      activeWorkspace?.generalInstruction.trim() ?? '',
    );
    final systemTokens = await _estimateSystemInstructionTokens(
      countTokens,
      systemInstruction,
    );

    final storedMessages =
        await (_database.select(_database.messages)
              ..where((t) => t.chat.equals(parsedChatId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();

    final contextPlan = await planStoredMessagesWindow(
      countTokens: countTokens,
      storedMessages: storedMessages,
      settingsMaxTokens: activeModel.maxTokens,
      requestedOutputReserve: activeModel.tokenBuffer,
      extraPromptTokens: systemTokens,
    );
    final remainingInputTokens =
        activeModel.maxTokens -
        contextPlan.reservedOutputTokens -
        contextPlan.promptTokens;

    return LocalMessageBudgetPlan(
      maxTokens: activeModel.maxTokens,
      reservedOutputTokens: contextPlan.reservedOutputTokens,
      promptTokens: contextPlan.promptTokens,
      messageTokens: messageTokens,
      remainingInputTokens: remainingInputTokens.clamp(
        0,
        activeModel.maxTokens,
      ),
      remainingTokensAfterMessage: remainingInputTokens - messageTokens,
      compactedMessages: contextPlan.compactedMessages,
    );
  }

  Future<int> _estimateSystemInstructionTokens(
    Future<int> Function(String text) countTokens,
    String systemInstruction,
  ) async {
    final trimmed = systemInstruction.trim();
    if (trimmed.isEmpty) return 0;
    return countTokens(trimmed);
  }
}
