import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/models/gemma_chat_session.dart';
import 'package:gena/features/chat/data/providers/active_model_info_provider.dart';
import 'package:gena/features/chat/data/providers/native_tool_actions_provider.dart';
import 'package:gena/features/chat/data/providers/chat_session_provider.dart';
import 'package:gena/features/chat/data/services/chat_session_runtime_service.dart';
import 'package:gena/features/chat/data/services/chat_thread_context_service.dart';
import 'package:gena/features/chat/data/services/chat_thread_execution_service.dart';
import 'package:gena/features/chat/data/services/remote_llm_service.dart';
import 'package:gena/features/chat/data/tools/chat_tools.dart';
import 'package:gena/features/chat/data/providers/chat_ui_state_provider.dart';
import 'package:gena/features/chat/data/providers/selected_chat_provider.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/workspace/data/models/workspace_entity.dart';
import 'package:gena/features/workspace/data/providers/workspace_rag_actions_provider.dart';
import 'package:gena/features/workspace/data/providers/workspace_queries_provider.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

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
      if (activeModel.provider == ModelProviderType.remote) {
        final database = ref.read(genaDatabaseProvider);
        await storeUserMessage(
          database: database,
          chatId: parsedChatId,
          text: text,
          hasImage: hasImage,
          imagePath: normalizedImagePath,
        );
        await _generateRemoteResponse(
          currentGeneration: currentGeneration,
          chatId: parsedChatId,
        );
        _scheduleThreadTitleUpdate(
          database: database,
          chatId: parsedChatId,
          messageText: text,
          hasImage: hasImage,
          activeModel: activeModel,
        );
      } else {
        final database = ref.read(genaDatabaseProvider);
        await storeUserMessage(
          database: database,
          chatId: parsedChatId,
          text: text,
          hasImage: hasImage,
          imagePath: normalizedImagePath,
        );
        GemmaChatSession? session;
        try {
          session = await ref.read(activeGemmaChatProvider.future);
        } catch (e, stackTrace) {
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
        await _generateLocalResponse(
          currentGeneration: currentGeneration,
          chatId: parsedChatId,
          session: session,
        );
        _scheduleThreadTitleUpdate(
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

  Future<void> _generateLocalResponse({
    required int currentGeneration,
    required int chatId,
    required GemmaChatSession session,
  }) async {
    if (_cancelGenerationSerial == currentGeneration) return;

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

    final database = ref.read(genaDatabaseProvider);
    await prepareContext(
      ref: ref,
      database: database,
      chatId: chatId,
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
      chatId: chatId,
      isCancelled: () => _cancelGenerationSerial == currentGeneration,
    );
  }

  Future<void> _generateRemoteResponse({
    required int currentGeneration,
    required int chatId,
  }) async {
    final activeModel = ref.read(activeModelInfoProvider);
    if (activeModel == null) return;

    final database = ref.read(genaDatabaseProvider);
    final activeWorkspace = ref.read(activeWorkspaceProvider);
    final basePrompt = activeWorkspace?.generalInstruction.trim() ?? '';
    final systemInstruction = buildSystemInstruction(basePrompt);
    final remoteTools = buildRemoteChatTools(
      supportsFunctionCalls: activeModel.supportsFunctionCalls,
      enableRagTool: activeWorkspace?.ragEnabled ?? false,
      enableNativeOpenUrlTool:
          (activeWorkspace?.nativeToolsEnabled ?? false) &&
          (activeWorkspace?.nativeOpenUrlEnabled ?? false),
      enableNativeOpenAppTool:
          (activeWorkspace?.nativeToolsEnabled ?? false) &&
          (activeWorkspace?.nativeOpenAppEnabled ?? false),
      enableNativePhoneCallTool:
          (activeWorkspace?.nativeToolsEnabled ?? false) &&
          (activeWorkspace?.nativeOpenAppEnabled ?? false),
      enableNativeContactsTool:
          (activeWorkspace?.nativeToolsEnabled ?? false) &&
          (activeWorkspace?.nativeOpenAppEnabled ?? false),
      enableNativeSmsTool:
          (activeWorkspace?.nativeToolsEnabled ?? false) &&
          (activeWorkspace?.nativeOpenAppEnabled ?? false),
      enableNativeSendEmailTool:
          (activeWorkspace?.nativeToolsEnabled ?? false) &&
          (activeWorkspace?.nativeSendEmailEnabled ?? false),
      enableNativeFlashlightTool:
          (activeWorkspace?.nativeToolsEnabled ?? false) &&
          (activeWorkspace?.nativeFlashlightEnabled ?? false),
    );

    final storedMessages =
        await (database.select(database.messages)
              ..where((t) => t.chat.equals(chatId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();

    if (_cancelGenerationSerial == currentGeneration) return;

    final remoteAbortCompleter = Completer<void>();
    _remoteAbortCompleter = remoteAbortCompleter;
    final remoteMessages = buildRemoteMessagesFromStoredMessages(
      systemInstruction: systemInstruction,
      storedMessages: storedMessages,
    );

    final responseBuffer = StringBuffer();
    var toolTurns = 0;

    while (true) {
      if (_cancelGenerationSerial == currentGeneration) return;

      final turnResult = await runRemoteChatTurnStreamed(
        model: activeModel,
        messages: remoteMessages,
        tools: remoteTools,
        abortTrigger: remoteAbortCompleter.future,
        onTextDelta: (delta) {
          responseBuffer.write(delta);
          ref
              .read(chatDraftResponseProvider.notifier)
              .setDraft(responseBuffer.toString());
        },
      );

      if (!turnResult.hasToolCalls) {
        break;
      }

      if (toolTurns++ >= 4) {
        if (responseBuffer.isNotEmpty) responseBuffer.write('\n\n');
        responseBuffer.write(
          'I could not complete the request because too many consecutive tool calls were generated.',
        );
        ref
            .read(chatDraftResponseProvider.notifier)
            .setDraft(responseBuffer.toString());
        break;
      }

      remoteMessages.add(
        openai.ChatMessage.assistant(
          content: null,
          toolCalls: turnResult.toolCalls,
        ),
      );

      for (final call in turnResult.toolCalls) {
        if (_cancelGenerationSerial == currentGeneration) return;
        ref
            .read(chatToolWaitingProvider.notifier)
            .setWaitingTool(call.function.name);
        try {
          final parsedArgs = _decodeToolArguments(call.function.arguments);
          final toolResult = await executeChatToolByName(
            call.function.name,
            parsedArgs,
            ragToolHandler: activeWorkspace == null
                ? null
                : (query, {topK = 4, threshold = 0.15}) => ref
                      .read(workspaceRagActionsProvider)
                      .runRagTool(
                        workspaceId: activeWorkspace.id,
                        query: query,
                        topK: topK,
                        threshold: threshold,
                      ),
            nativeToolHandler:
                !_isNativeToolAllowed(
                  workspace: activeWorkspace,
                  toolName: call.function.name,
                )
                ? null
                : (toolName, args) => ref
                      .read(nativeToolActionsProvider)
                      .requestAndExecute(toolName: toolName, args: args),
          );

          await database
              .into(database.messages)
              .insert(
                db.MessagesCompanion.insert(
                  chat: chatId,
                  role: 'assistant',
                  kind: const Value('tool_trace'),
                  content: _formatRemoteToolTraceMessage(call, toolResult),
                ),
              );

          remoteMessages.add(
            openai.ChatMessage.tool(
              toolCallId: call.id,
              content: jsonEncode(toolResult),
            ),
          );
        } finally {
          ref.read(chatToolWaitingProvider.notifier).clear();
        }
      }
    }

    final responseText = responseBuffer.toString().trim();
    if (responseText.isEmpty) {
      throw StateError(
        'Remote API returned no final assistant text after tool execution.',
      );
    }

    if (_cancelGenerationSerial == currentGeneration) return;

    await database
        .into(database.messages)
        .insert(
          db.MessagesCompanion.insert(
            chat: chatId,
            role: 'assistant',
            kind: const Value('text'),
            content: responseText,
          ),
        );
  }

  Future<String?> _generateAiThreadTitle({
    required ModelInfo activeModel,
    required String messageText,
    required bool hasImage,
  }) async {
    final content = messageText.trim();
    if (content.isEmpty && !hasImage) return null;
    if (content.length > 1200) {
      return null;
    }

    try {
      if (activeModel.provider == ModelProviderType.remote) {
        return await _generateRemoteThreadTitle(
          model: activeModel,
          messageText: content,
          hasImage: hasImage,
        ).timeout(const Duration(seconds: 5));
      }

      return await _generateLocalThreadTitle(
        messageText: content,
        hasImage: hasImage,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  void _scheduleThreadTitleUpdate({
    required db.GenaDatabase database,
    required int chatId,
    required String messageText,
    required bool hasImage,
    required ModelInfo activeModel,
  }) {
    updateThreadTitleFromFirstMessage(
      database: database,
      chatId: chatId,
      messageText: messageText,
      hasImage: hasImage,
      titleGenerator: (text, {required hasImage}) => _generateAiThreadTitle(
        activeModel: activeModel,
        messageText: text,
        hasImage: hasImage,
      ),
    ).ignore();
  }

  Future<String?> _generateRemoteThreadTitle({
    required ModelInfo model,
    required String messageText,
    required bool hasImage,
  }) async {
    final userPrompt = _buildTitlePrompt(
      messageText: messageText,
      hasImage: hasImage,
    );
    final result = await runRemoteChatTurnStreamed(
      model: model,
      messages: [
        openai.ChatMessage.system(_threadTitleSystemInstruction),
        openai.ChatMessage.user(userPrompt),
      ],
      tools: const <openai.Tool>[],
    );
    return result.generatedText;
  }

  Future<String?> _generateLocalThreadTitle({
    required String messageText,
    required bool hasImage,
  }) async {
    final runtime = await ref.read(activeGemmaModelRuntimeProvider.future);
    if (runtime == null) return null;

    final session = await runtime.model.createSession(
      temperature: 0.2,
      randomSeed: runtime.randomSeed,
      topK: runtime.topK,
      topP: runtime.topP,
      systemInstruction: _threadTitleSystemInstruction,
    );

    try {
      await session.addQueryChunk(
        gemma.Message.text(
          text: _buildTitlePrompt(messageText: messageText, hasImage: hasImage),
          isUser: true,
        ),
      );
      final responseStream = session.getResponseAsync();
      final responseBuffer = StringBuffer();
      await for (final response in responseStream) {
        if (response is gemma.TextResponse) {
          responseBuffer.write(response);
        }
      }
      return responseBuffer.toString();
    } finally {
      await session.close();
    }
  }

  String _buildTitlePrompt({
    required String messageText,
    required bool hasImage,
  }) {
    final safeText = messageText.trim();
    final imageHint = hasImage ? 'yes' : 'no';
    return 'Create a short conversation title for this first user message.\n'
        'Return title only.\n'
        'Message has image: $imageHint\n'
        'User message: $safeText';
  }

  Map<String, dynamic> _decodeToolArguments(String rawArguments) {
    final decoded = jsonDecode(rawArguments);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  String _formatRemoteToolTraceMessage(
    openai.ToolCall call,
    Map<String, dynamic> result,
  ) {
    final payload = <String, dynamic>{
      'call': <String, dynamic>{
        'id': call.id,
        'name': call.function.name,
        'args': call.function.arguments,
      },
      'result': result,
    };
    const encoder = JsonEncoder.withIndent('  ');
    return 'Function trace\n${encoder.convert(payload)}';
  }

  bool _isNativeToolAllowed({
    required WorkspaceEntity? workspace,
    required String toolName,
  }) {
    if (workspace == null) return false;
    if (!workspace.nativeToolsEnabled) return false;
    return switch (toolName) {
      nativeOpenUrlToolName => workspace.nativeOpenUrlEnabled,
      nativeOpenAppToolName => workspace.nativeOpenAppEnabled,
      nativePhoneCallToolName => workspace.nativeOpenAppEnabled,
      nativeReadContactsToolName => workspace.nativeOpenAppEnabled,
      nativeSearchContactsToolName => workspace.nativeOpenAppEnabled,
      nativeCreateContactToolName => workspace.nativeOpenAppEnabled,
      nativeSendSmsToolName => workspace.nativeOpenAppEnabled,
      nativeSendEmailToolName => workspace.nativeSendEmailEnabled,
      nativeFlashlightToolName => workspace.nativeFlashlightEnabled,
      _ => true,
    };
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

const String _threadTitleSystemInstruction =
    'You generate concise chat titles. '
    'Use 3 to 7 words, maximum 32 characters. '
    'No quotes, no punctuation at start/end, no markdown. '
    'Return only the title text.';
