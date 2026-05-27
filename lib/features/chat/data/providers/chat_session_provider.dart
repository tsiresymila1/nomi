import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/logger.dart';
import 'package:gena/features/chat/data/cubits/selected_chat_cubit.dart';
import 'package:gena/features/chat/data/models/gemma_chat_session.dart';
import 'package:gena/features/chat/data/providers/active_model_info_provider.dart';
import 'package:gena/features/chat/data/services/chat_session_history_service.dart';
import 'package:gena/features/chat/data/services/chat_session_runtime_service.dart';
import 'package:gena/features/chat/data/tools/chat_tools.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/workspace/data/providers/workspace_queries_provider.dart';

class ActiveGemmaModelRuntime {
  const ActiveGemmaModelRuntime({
    required this.model,
    required this.supportImage,
    required this.supportAudio,
    required this.supportsFunctionCalls,
    required this.defaultIsThinking,
    required this.modelType,
    required this.temperature,
    required this.topK,
    required this.topP,
    required this.maxTokens,
    required this.tokenBuffer,
    required this.randomSeed,
    required this.preferredBackend,
  });

  final gemma.InferenceModel model;
  final bool supportImage;
  final bool supportAudio;
  final bool supportsFunctionCalls;
  final bool defaultIsThinking;
  final gemma.ModelType modelType;
  final double temperature;
  final int topK;
  final double topP;
  final int maxTokens;
  final int tokenBuffer;
  final int randomSeed;
  final gemma.PreferredBackend? preferredBackend;
}

class ChatSessionController {
  ChatSessionController({
    required db.GenaDatabase database,
    required ActiveModelInfoResolver activeModelInfoResolver,
    required WorkspaceQueries workspaceQueries,
    required SelectedChatCubit selectedChatCubit,
  }) : _database = database,
       _activeModelInfoResolver = activeModelInfoResolver,
       _workspaceQueries = workspaceQueries,
       _selectedChatCubit = selectedChatCubit;

  final db.GenaDatabase _database;
  final ActiveModelInfoResolver _activeModelInfoResolver;
  final WorkspaceQueries _workspaceQueries;
  final SelectedChatCubit _selectedChatCubit;

  ActiveGemmaModelRuntime? _runtime;
  int? _runtimeModelId;
  GemmaChatSession? _chatSession;
  String? _sessionChatId;
  int? _sessionModelId;

  Future<ActiveGemmaModelRuntime?> getRuntime() async {
    final activeModel = await _activeModelInfoResolver.getActiveModelInfo();
    if (activeModel == null || activeModel.provider != ModelProviderType.local) {
      return null;
    }

    if (_runtime != null && _runtimeModelId == activeModel.id) {
      return _runtime;
    }

    await _closeRuntime();

    logger.i(
      'Runtime provider: building for model id=${activeModel.id}, name=${activeModel.name}',
    );

    await _ensureLocalModelActive(activeModel);

    final preferredBackend = _parsePreferredBackend(activeModel.preferredBackend);
    final model = await getActiveModelWithBackendFallbacks(
      maxTokens: activeModel.maxTokens,
      preferredBackend: preferredBackend,
      supportImage: activeModel.supportImage,
      supportAudio: activeModel.supportAudio,
    );

    _runtime = ActiveGemmaModelRuntime(
      model: model,
      supportImage: activeModel.supportImage,
      supportAudio: activeModel.supportAudio,
      supportsFunctionCalls: activeModel.supportsFunctionCalls,
      defaultIsThinking: activeModel.isThinking,
      modelType: parseModelType(activeModel.modelType),
      temperature: activeModel.temperature,
      topK: activeModel.topK,
      topP: activeModel.topP,
      maxTokens: activeModel.maxTokens,
      tokenBuffer: activeModel.tokenBuffer,
      randomSeed: activeModel.randomSeed,
      preferredBackend: preferredBackend,
    );
    _runtimeModelId = activeModel.id;
    return _runtime;
  }

  Future<GemmaChatSession?> getActiveChatSession() async {
    final selectedChatId = _selectedChatCubit.state;
    if (selectedChatId == null) return null;

    final parsedChatId = int.tryParse(selectedChatId);
    if (parsedChatId == null) return null;

    final activeModel = await _activeModelInfoResolver.getActiveModelInfo();
    final modelId = activeModel?.id;
    if (_chatSession != null &&
        _sessionChatId == selectedChatId &&
        _sessionModelId == modelId) {
      return _chatSession;
    }

    final modelRuntime = await getRuntime();
    if (modelRuntime == null) {
      logger.i('Chat session provider: runtime unavailable for chat=$parsedChatId.');
      return null;
    }

    final activeWorkspace = await _workspaceQueries.resolveActiveWorkspace();
    final systemPrompt = activeWorkspace?.generalInstruction.trim() ?? '';
    final systemInstruction = buildSystemInstruction(systemPrompt);
    final effectiveThinking = modelRuntime.defaultIsThinking;
    final tools = buildChatTools(
      supportsFunctionCalls: modelRuntime.supportsFunctionCalls,
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

    final chat = await modelRuntime.model.createChat(
      temperature: modelRuntime.temperature,
      randomSeed: modelRuntime.randomSeed,
      topK: modelRuntime.topK,
      topP: modelRuntime.topP,
      tokenBuffer: modelRuntime.tokenBuffer,
      supportImage: modelRuntime.supportImage,
      supportAudio: modelRuntime.supportAudio,
      supportsFunctionCalls: modelRuntime.supportsFunctionCalls,
      tools: tools,
      isThinking: effectiveThinking,
      modelType: modelRuntime.modelType,
      systemInstruction: systemInstruction.isEmpty ? null : systemInstruction,
    );

    await replayStoredMessages(
      database: _database,
      chatId: parsedChatId,
      chat: chat,
    );

    _chatSession = GemmaChatSession(model: modelRuntime.model, chat: chat);
    _sessionChatId = selectedChatId;
    _sessionModelId = modelId;
    return _chatSession;
  }

  void resetRuntime() {
    unawaited(_closeRuntime());
    _runtime = null;
    _runtimeModelId = null;
  }

  void resetActiveChatSession() {
    _chatSession = null;
    _sessionChatId = null;
    _sessionModelId = null;
  }

  Future<void> _closeRuntime() async {
    final current = _runtime;
    if (current == null) return;
    await current.model.close();
    _runtime = null;
  }

  gemma.PreferredBackend? _parsePreferredBackend(String? value) {
    return switch (value) {
      'cpu' => gemma.PreferredBackend.cpu,
      'gpu' => gemma.PreferredBackend.gpu,
      'npu' => gemma.PreferredBackend.npu,
      _ => null,
    };
  }

  Future<void> _ensureLocalModelActive(ModelInfo model) async {
    if (!_isSelectedModelActive(model)) {
      await _activateCatalogModel(model);
      return;
    }

    if (gemma.FlutterGemma.hasActiveModel()) {
      return;
    }
    await _activateCatalogModel(model);
  }

  bool _isSelectedModelActive(ModelInfo model) {
    final activeSpec =
        gemma.FlutterGemmaPlugin.instance.modelManager.activeInferenceModel;
    if (activeSpec is! gemma.InferenceModelSpec) return false;

    final activeId = activeSpec.name.toLowerCase();
    final savedModelId = (model.modelId ?? '').trim().toLowerCase();
    if (savedModelId.isNotEmpty && savedModelId == activeId) {
      return true;
    }

    final fallbackId = modelSpecNameFromSource(model.source).toLowerCase();
    return fallbackId == activeId;
  }

  Future<void> _activateCatalogModel(ModelInfo model) async {
    final sourcePath = await resolveModelSourceForInstall(
      modelName: model.name,
      sourceType: model.sourceType,
      source: model.source,
    );
    final installer = gemma.FlutterGemma.installModel(
      modelType: parseModelType(model.modelType),
      fileType: inferFileTypeFromSource(sourcePath),
    );

    final builder = installer.fromFile(sourcePath);
    await builder.install();
  }
}
