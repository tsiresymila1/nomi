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
import 'package:gena/features/chat/data/models/chat_attachment.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';

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

RemoteFallbackProposal? resolveRemoteFallbackProposal({
  required ModelInfo failedModel,
  required List<ModelInfo> models,
}) {
  if (failedModel.provider != ModelProviderType.local) return null;
  for (final model in models) {
    if (model.provider != ModelProviderType.remote) continue;
    final apiHost = Uri.tryParse(model.apiUrl ?? '')?.host.trim();
    final source = Uri.tryParse(model.source);
    final providerLabel = apiHost != null && apiHost.isNotEmpty
        ? apiHost
        : source?.scheme == 'remote-server' && source!.host.isNotEmpty
        ? 'Remote server ${source.host}'
        : 'Configured remote API';
    return RemoteFallbackProposal(
      modelId: model.id,
      modelName: model.name,
      providerLabel: providerLabel,
    );
  }
  return null;
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

({String message, bool canRetry}) _safeGenerationFailure(Object error) {
  final rawError = error.toString();
  final isMissingLiteRtSymbol =
      rawError.contains('litert_lm_conversation_optional_args_create') &&
      rawError.contains('undefined symbol');
  if (isMissingLiteRtSymbol) {
    return (
      message: 'Local runtime mismatch detected. Clean and reinstall the app.',
      canRetry: false,
    );
  }
  return (
    message: 'Could not complete the response. Please try again.',
    canRetry: true,
  );
}

/// Narrow boundary used by presentation cubits that only need to trigger a
/// send or stop on the active chat thread. Lets those cubits be unit-tested
/// without constructing the full [ChatThreadActions] dependency graph.
abstract interface class ChatThreadActionsApi {
  Future<void> sendMessage(
    String rawText, {
    String? imagePath,
    List<PreparedChatAttachment> attachments = const [],
  });

  Future<void> stopGeneration({
    bool triggerLocalModelCancel = true,
    bool waitForLocalModelCancel = true,
  });
}

typedef ChatAssistantGenerator =
    Future<void> Function({
      required db.GenaDatabase database,
      required int chatId,
      required ModelInfo activeModel,
      required bool Function() isCancelled,
    });

typedef RemoteFallbackResolver =
    Future<RemoteFallbackProposal?> Function(ModelInfo failedModel);

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
    required ChatGenerationFailureCubit chatGenerationFailureCubit,
    required ChatRuntimeDependencies runtimeDependencies,
    ChatAssistantGenerator? assistantGenerator,
    RemoteFallbackResolver? remoteFallbackResolver,
  }) : _database = database,
       _selectedChatCubit = selectedChatCubit,
       _activeModelInfoResolver = activeModelInfoResolver,
       _localModelRuntime = localModelRuntime,
       _chatGeneratingCubit = chatGeneratingCubit,
       _chatDraftResponseCubit = chatDraftResponseCubit,
       _chatDraftThinkingCubit = chatDraftThinkingCubit,
       _chatToolWaitingCubit = chatToolWaitingCubit,
       _chatGenerationFailureCubit = chatGenerationFailureCubit,
       _runtimeDependencies = runtimeDependencies,
       _assistantGenerator = assistantGenerator,
       _remoteFallbackResolver = remoteFallbackResolver;

  final db.GenaDatabase _database;
  final SelectedChatCubit _selectedChatCubit;
  final ActiveModelInfoResolver _activeModelInfoResolver;
  final LocalModelRuntime _localModelRuntime;
  final ChatGeneratingCubit _chatGeneratingCubit;
  final ChatDraftResponseCubit _chatDraftResponseCubit;
  final ChatDraftThinkingCubit _chatDraftThinkingCubit;
  final ChatToolWaitingCubit _chatToolWaitingCubit;
  final ChatGenerationFailureCubit _chatGenerationFailureCubit;
  final ChatRuntimeDependencies _runtimeDependencies;
  final ChatAssistantGenerator? _assistantGenerator;
  final RemoteFallbackResolver? _remoteFallbackResolver;

  int _generationSerial = 0;
  int? _cancelGenerationSerial;
  bool _retryInFlight = false;
  Future<void> _generationTail = Future<void>.value();

  @override
  Future<void> sendMessage(
    String rawText, {
    String? imagePath,
    List<PreparedChatAttachment> attachments = const [],
  }) async {
    final text = rawText.trim();
    final normalizedImagePath = imagePath?.trim();
    final hasImage =
        (normalizedImagePath != null && normalizedImagePath.isNotEmpty) ||
        attachments.any(
          (attachment) => attachment.kind == ChatAttachmentKind.image,
        );
    if (text.isEmpty && !hasImage && attachments.isEmpty) return;

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
        attachments: attachments,
      );
      if (!messageFits) {
        return;
      }
    }

    late final int userMessageId;
    try {
      userMessageId = await storeUserMessage(
        database: _database,
        chatId: parsedChatId,
        text: text,
        hasImage: hasImage,
        imagePath: normalizedImagePath,
        attachments: attachments,
      );
    } catch (error, stackTrace) {
      logger.e(
        'Failed to persist the user chat message',
        error: error,
        stackTrace: stackTrace,
      );
      await AppToast.show(
        'Could not save the message. Please try again.',
        type: AppToastType.error,
      );
      return;
    }

    await _generateStoredTurn(
      chatId: parsedChatId,
      activeModel: activeModel,
      userMessageId: userMessageId,
      messageText: text,
      hasImage: hasImage,
    );
  }

  /// Serializes context priming with visible generations so two native llama
  /// requests never overlap on the shared local runtime.
  Future<void> primeCurrentContext({ModelInfo? activeModel}) async {
    final chatId = int.tryParse(_selectedChatCubit.state ?? '');
    if (chatId == null) return;
    final model =
        activeModel ?? await _activeModelInfoResolver.getActiveModelInfo();
    if (model == null || model.provider != ModelProviderType.local) return;

    final result = _generationTail.then(
      (_) => primeLocalChatContextWithGenkit(
        deps: _runtimeDependencies,
        database: _database,
        chatId: chatId,
        activeModel: model,
      ),
    );
    _generationTail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  Future<void> retryLastFailedGeneration() async {
    final failure = _chatGenerationFailureCubit.state;
    if (failure == null ||
        !failure.canRetry ||
        _chatGeneratingCubit.state ||
        _retryInFlight) {
      return;
    }
    if (_selectedChatCubit.state != failure.chatId.toString()) return;
    _retryInFlight = true;

    try {
      await _retryFailedGeneration(failure);
    } finally {
      _retryInFlight = false;
    }
  }

  Future<void> _retryFailedGeneration(
    ChatGenerationFailureState failure,
  ) async {
    final userMessage =
        await (_database.select(_database.messages)
              ..where(
                (row) =>
                    row.id.equals(failure.userMessageId) &
                    row.chat.equals(failure.chatId) &
                    row.role.equals('user'),
              )
              ..limit(1))
            .getSingleOrNull();
    if (userMessage == null) {
      _chatGenerationFailureCubit.fail(
        chatId: failure.chatId,
        userMessageId: failure.userMessageId,
        displayMessage: 'The original message is no longer available.',
        canRetry: false,
      );
      return;
    }

    final activeModel = await _activeModelInfoResolver.getActiveModelInfo();
    if (activeModel == null) {
      _chatGenerationFailureCubit.fail(
        chatId: failure.chatId,
        userMessageId: failure.userMessageId,
        displayMessage: 'Select a model before retrying.',
        canRetry: true,
      );
      return;
    }

    final hasTypedImage =
        await (_database.select(_database.messageAttachments)..where(
              (row) =>
                  row.message.equals(userMessage.id) & row.kind.equals('image'),
            ))
            .get()
            .then((rows) => rows.isNotEmpty);
    final hasImage =
        (userMessage.mediaPath != null &&
            userMessage.mediaPath!.trim().isNotEmpty) ||
        hasTypedImage;
    if (isImageInputRejected(model: activeModel, hasImage: hasImage)) {
      _chatGenerationFailureCubit.fail(
        chatId: failure.chatId,
        userMessageId: failure.userMessageId,
        displayMessage: imageInputUnsupportedMessage,
        canRetry: true,
      );
      return;
    }

    if (activeModel.provider == 'local') {
      try {
        await _localModelRuntime.prepare(activeModel);
      } catch (error, stackTrace) {
        logger.w(
          'Local model is not ready for retry: $error',
          stackTrace: stackTrace,
        );
        _chatGenerationFailureCubit.fail(
          chatId: failure.chatId,
          userMessageId: failure.userMessageId,
          displayMessage: 'The model is not ready yet. Try again shortly.',
          canRetry: true,
        );
        return;
      }
    }

    final partialAssistantMessageId = failure.partialAssistantMessageId;
    if (partialAssistantMessageId != null) {
      await (_database.delete(_database.messages)..where(
            (row) =>
                row.id.equals(partialAssistantMessageId) &
                row.chat.equals(failure.chatId) &
                row.role.equals('assistant'),
          ))
          .go();
    }

    await (_database.update(_database.messages)..where(
          (row) =>
              row.id.equals(userMessage.id) &
              row.chat.equals(failure.chatId) &
              row.role.equals('user'),
        ))
        .write(db.MessagesCompanion(kind: Value(hasImage ? 'image' : 'text')));

    await _generateStoredTurn(
      chatId: failure.chatId,
      activeModel: activeModel,
      userMessageId: failure.userMessageId,
      messageText: userMessage.content,
      hasImage: hasImage,
    );
  }

  Future<void> _generateStoredTurn({
    required int chatId,
    required ModelInfo activeModel,
    required int userMessageId,
    required String messageText,
    required bool hasImage,
  }) {
    final result = _generationTail.then(
      (_) => _runStoredTurn(
        chatId: chatId,
        activeModel: activeModel,
        userMessageId: userMessageId,
        messageText: messageText,
        hasImage: hasImage,
      ),
    );
    _generationTail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  Future<void> _runStoredTurn({
    required int chatId,
    required ModelInfo activeModel,
    required int userMessageId,
    required String messageText,
    required bool hasImage,
  }) async {
    final currentGeneration = ++_generationSerial;
    _cancelGenerationSerial = null;
    _chatGenerationFailureCubit.clear();
    _chatGeneratingCubit.setGenerating(true);
    _chatDraftResponseCubit.setDraft('');
    _chatDraftThinkingCubit.clear();
    _chatToolWaitingCubit.clear();

    try {
      await _generateAssistantResponse(
        chatId: chatId,
        activeModel: activeModel,
        isCancelled: () => _cancelGenerationSerial == currentGeneration,
      );

      if (_cancelGenerationSerial == currentGeneration) {
        await _recordCancelledGeneration(
          chatId: chatId,
          userMessageId: userMessageId,
        );
        return;
      }

      scheduleThreadTitleUpdate(
        localModelRuntime: _localModelRuntime,
        database: _database,
        chatId: chatId,
        messageText: messageText,
        hasImage: hasImage,
        activeModel: activeModel,
      );
    } catch (error, stackTrace) {
      if (_cancelGenerationSerial == currentGeneration) {
        await _recordCancelledGeneration(
          chatId: chatId,
          userMessageId: userMessageId,
        );
        return;
      }

      final failure = _safeGenerationFailure(error);
      RemoteFallbackProposal? remoteFallback;
      final resolver = _remoteFallbackResolver;
      if (activeModel.provider == 'local' && resolver != null) {
        try {
          remoteFallback = await resolver(activeModel);
        } catch (fallbackError, fallbackStackTrace) {
          logger.w(
            'Could not resolve a remote fallback: $fallbackError',
            stackTrace: fallbackStackTrace,
          );
        }
      }
      _chatGenerationFailureCubit.fail(
        chatId: chatId,
        userMessageId: userMessageId,
        displayMessage: failure.message,
        canRetry: failure.canRetry,
        remoteFallback: remoteFallback,
      );
      logger.e(
        'Failed to generate chat response',
        error: error,
        stackTrace: stackTrace,
      );
      await AppToast.show(failure.message, type: AppToastType.error);
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

  Future<void> _generateAssistantResponse({
    required int chatId,
    required ModelInfo activeModel,
    required bool Function() isCancelled,
  }) {
    final override = _assistantGenerator;
    if (override != null) {
      return override(
        database: _database,
        chatId: chatId,
        activeModel: activeModel,
        isCancelled: isCancelled,
      );
    }
    return generateAssistantResponseWithGenkit(
      deps: _runtimeDependencies,
      database: _database,
      chatId: chatId,
      activeModel: activeModel,
      isCancelled: isCancelled,
    );
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

  Future<void> _recordCancelledGeneration({
    required int chatId,
    required int userMessageId,
  }) async {
    int? partialAssistantMessageId;
    try {
      await (_database.update(_database.messages)..where(
            (row) =>
                row.id.equals(userMessageId) &
                row.chat.equals(chatId) &
                row.role.equals('user'),
          ))
          .write(const db.MessagesCompanion(kind: Value('cancelled')));
      partialAssistantMessageId = await _persistCancelledDraftIfAny(chatId);
    } catch (error, stackTrace) {
      logger.w(
        'Could not persist the partial cancelled response: $error',
        stackTrace: stackTrace,
      );
    }
    _chatGenerationFailureCubit.fail(
      chatId: chatId,
      userMessageId: userMessageId,
      displayMessage: 'Generation stopped. You can retry this response.',
      canRetry: true,
      partialAssistantMessageId: partialAssistantMessageId,
    );
  }

  Future<int?> _persistCancelledDraftIfAny(int chatId) async {
    final draft = (_chatDraftResponseCubit.state ?? '').trim();
    if (draft.isEmpty) return null;

    return _database
        .into(_database.messages)
        .insert(
          db.MessagesCompanion.insert(
            chat: chatId,
            role: 'assistant',
            kind: const Value('cancelled'),
            content: draft,
          ),
        );
  }

  Future<bool> _validateLocalMessageFitsContext({
    required String text,
    required String? imagePath,
    List<PreparedChatAttachment> attachments = const [],
  }) async {
    final budget = await estimateLocalMessageBudget(
      text: text,
      imagePath: imagePath,
      attachments: attachments,
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
    List<PreparedChatAttachment> attachments = const [],
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
    for (final attachment in attachments) {
      if (attachment.kind == ChatAttachmentKind.image) {
        messageTokens += 257;
        continue;
      }
      final documentText = attachment.extractedText?.trim() ?? '';
      if (documentText.isNotEmpty) {
        messageTokens += await countTokens(documentText);
      }
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
