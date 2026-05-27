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
  var disposed = false;
  ref.onDispose(() => disposed = true);

  final activeModel = ref.watch(activeModelInfoProvider);
  if (activeModel == null || activeModel.provider != ModelProviderType.local) {
    logger.i('Runtime provider: no local active model, returning null.');
    return null;
  }

  logger.i(
    'Runtime provider: building for model id=${activeModel.id}, name=${activeModel.name}, thinking=${activeModel.isThinking}, temp=${activeModel.temperature}, topK=${activeModel.topK}, topP=${activeModel.topP}, maxTokens=${activeModel.maxTokens}, tokenBuffer=${activeModel.tokenBuffer}, backend=${activeModel.preferredBackend}',
  );

  await _ensureLocalModelActive(activeModel);
  if (disposed) return null;

  final preferredBackend = _parsePreferredBackend(activeModel.preferredBackend);
  final model = await getActiveModelWithBackendFallbacks(
    maxTokens: activeModel.maxTokens,
    preferredBackend: preferredBackend,
    supportImage: activeModel.supportImage,
    supportAudio: activeModel.supportAudio,
  );
  if (disposed) {
    logger.i('Runtime provider: disposed while loading runtime, closing.');
    await model.close();
    return null;
  }

  ref.onDispose(() {
    logger.i(
      'Runtime provider: disposing runtime for model id=${activeModel.id}, name=${activeModel.name}.',
    );
    unawaited(model.close());
  });

  logger.i(
    'Runtime provider: ready for model id=${activeModel.id}, name=${activeModel.name}.',
  );
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

final activeGemmaChatProvider = StreamProvider.autoDispose<GemmaChatSession?>((
  ref,
) async* {
  var disposed = false;
  ref.onDispose(() => disposed = true);

  final selectedChatId = ref.watch(selectedChatIdProvider);
  final activeWorkspace = ref.watch(activeWorkspaceProvider);
  final database = ref.watch(genaDatabaseProvider);

  if (selectedChatId == null) {
    logger.i('Chat session provider: no selected chat, returning null.');
    yield null;
    return;
  }

  final parsedChatId = int.tryParse(selectedChatId);
  if (parsedChatId == null) {
    logger.w('Chat session provider: invalid chat id: $selectedChatId');
    yield null;
    return;
  }

  final modelRuntime = await ref.watch(activeGemmaModelRuntimeProvider.future);
  if (disposed) return;
  if (modelRuntime == null) {
    logger.i(
      'Chat session provider: runtime unavailable for chat=$parsedChatId, returning null.',
    );
    yield null;
    return;
  }

  try {
    logger.i(
      'Chat session provider: creating chat session for chat=$parsedChatId, modelType=${modelRuntime.modelType.name}, thinking=${modelRuntime.defaultIsThinking}, functions=${modelRuntime.supportsFunctionCalls}',
    );
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
    if (disposed) {
      logger.i(
        'Chat session provider: disposed while creating chat for chat=$parsedChatId, closing chat handle.',
      );
      await chat.close();
      return;
    }

    await replayStoredMessages(
      database: database,
      chatId: parsedChatId,
      chat: chat,
    );
    if (disposed) {
      logger.i(
        'Chat session provider: disposed after replay for chat=$parsedChatId, closing chat handle.',
      );
      await chat.close();
      return;
    }

    ref.onDispose(() {
      logger.i(
        'Chat session provider: disposing chat session for chat=$parsedChatId.',
      );
      unawaited(chat.close());
    });
    logger.i('Chat session provider: ready for chat=$parsedChatId.');
    yield GemmaChatSession(model: modelRuntime.model, chat: chat);
  } catch (e) {
    logger.e('Failed to initialize active Gemma chat session', error: e);
    yield null;
  }
});

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

  if (gemma.FlutterGemma.hasActiveModel()) return;
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
    'Runtime provider: activating catalog model id=${model.id}, name=${model.name}, sourceType=${model.sourceType}.',
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
    'Runtime provider: activation complete for model id=${model.id}, name=${model.name}.',
  );
}
