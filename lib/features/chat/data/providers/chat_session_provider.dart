import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/features/chat/data/models/gemma_chat_session.dart';
import 'package:gena/features/chat/data/providers/active_model_info_provider.dart';
import 'package:gena/features/chat/data/providers/selected_chat_provider.dart';
import 'package:gena/features/chat/data/services/chat_session_history_service.dart';
import 'package:gena/features/chat/data/services/chat_session_runtime_service.dart';
import 'package:gena/features/chat/data/tools/chat_tools.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/workspace/data/providers/workspace_queries_provider.dart';

class ActiveGemmaModelRuntime {
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
}

final activeGemmaModelRuntimeProvider = FutureProvider<ActiveGemmaModelRuntime?>((
  ref,
) async {
  final activeModel = ref.watch(activeModelInfoProvider);
  if (activeModel == null || activeModel.provider != ModelProviderType.local) {
    logger.e('Runtime provider: no local active model, returning null.');
    return null;
  }
  logger.i(
    'Runtime provider: building for model id=${activeModel.id}, name=${activeModel.name}, thinking=${activeModel.isThinking}, temp=${activeModel.temperature}, topK=${activeModel.topK}, topP=${activeModel.topP}, maxTokens=${activeModel.maxTokens}, tokenBuffer=${activeModel.tokenBuffer}, backend=${activeModel.preferredBackend}',
  );
  logger.i("-----------------Installing model---------------------");
  await _ensureLocalModelActive(activeModel);
  logger.i("-----------------Installation done---------------------");
  final preferredBackend = _parsePreferredBackend(activeModel.preferredBackend);
  final model =  await getActiveModelWithBackendFallbacks(
    maxTokens: activeModel.maxTokens,
    preferredBackend: preferredBackend,
    supportImage: activeModel.supportImage,
    supportAudio: activeModel.supportAudio,
  );
  logger.i(
    'Runtime provider: ready for model id=${activeModel.id}, name=${activeModel.name}.',
  );
  ref.onDispose(() {
    logger.i(
      'Runtime provider: disposing runtime for model id=${activeModel.id}, name=${activeModel.name}.',
    );
    unawaited(model.close());
  });
  return ActiveGemmaModelRuntime(
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
});

final activeGemmaChatProvider = FutureProvider.autoDispose<GemmaChatSession?>((
  ref,
) async {
  final selectedChatId = ref.watch(selectedChatIdProvider);
  final activeWorkspaceSnapshot = ref.watch(activeWorkspaceProvider);
  final database = ref.watch(genaDatabaseProvider);

  if (selectedChatId == null) {
    logger.i('Chat session provider: no selected chat, returning null.');
    return null;
  }
  final parsedChatId = int.tryParse(selectedChatId);
  if (parsedChatId == null) {
    logger.w('Chat session provider: invalid chat id: $selectedChatId');
    return null;
  }
  final modelRuntime = await ref.watch(activeGemmaModelRuntimeProvider.future);

  if (modelRuntime == null) {
    logger.i(
      'Chat session provider: runtime unavailable for chat=$parsedChatId, returning null.',
    );
    return null;
  }
  try {
    final activeWorkspace =
        activeWorkspaceSnapshot ??
        await resolveActiveWorkspace(ref, database: database);
    logger.i(
      'Chat session provider: creating chat session for chat=$parsedChatId, modelType=${modelRuntime.modelType.name}, thinking=${modelRuntime.defaultIsThinking}, functions=${modelRuntime.supportsFunctionCalls}',
    );
    final systemPrompt = activeWorkspace?.generalInstruction.trim() ?? '';
    logger.i("Workspace prompts:: $activeWorkspace");
    logger.i("Workspace:: $systemPrompt");
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
    logger.i('Chat session provider: ready for chat=$parsedChatId.');
    logger.i("System instruction: $systemInstruction");
    await replayStoredMessages(
      database: database,
      chatId: parsedChatId,
      chat: chat,
    );
    return GemmaChatSession(model: modelRuntime.model, chat: chat);
  } catch (e) {
    logger.e(e);
    if (_isClosedModelError(e)) {
      logger.w(
        'Chat session provider: model instance was closed while creating chat=$parsedChatId. Refreshing runtime and retrying once.',
      );
      ref.invalidate(activeGemmaModelRuntimeProvider);
      await ref.read(activeGemmaModelRuntimeProvider.future);
    }
  }
  return null;
});

bool _isClosedModelError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('model is closed') ||
      message.contains('bad state: model is closed');
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
    logger.i(
      'Runtime provider: active local model differs from selected, activating "${model.name}".',
    );
    await _activateCatalogModel(model);
    return;
  }

  if (gemma.FlutterGemma.hasActiveModel()) {
    logger.i("Already has active model ");
    return;
  }
  logger.i(
    'Runtime provider: no active model in engine, activating "${model.name}".',
  );
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
  logger.i(
    'Activating runtime :  id=${model.id}, name=${model.name}, sourceType=${model.sourceType}.',
  );
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
  logger.i(
    'Runtime activated : activation complete for model id=${model.id}, name=${model.name}.',
  );
}
