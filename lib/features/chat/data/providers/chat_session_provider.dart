import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/features/chat/data/models/gemma_chat_session.dart';
import 'package:gena/features/chat/data/providers/selected_chat_provider.dart';
import 'package:gena/features/chat/data/tools/chat_tools.dart';
import 'package:gena/features/setting/data/chat_model_settings.dart';
import 'package:gena/features/setting/data/providers/chat_model_settings_provider.dart';

class ActiveGemmaModelRuntime {
  final gemma.InferenceModel model;
  final bool supportImage;
  final bool supportAudio;
  final bool supportsFunctionCalls;
  final bool defaultIsThinking;
  final gemma.ModelType modelType;

  const ActiveGemmaModelRuntime({
    required this.model,
    required this.supportImage,
    required this.supportAudio,
    required this.supportsFunctionCalls,
    required this.defaultIsThinking,
    required this.modelType,
  });
}

final activeGemmaModelRuntimeProvider =
    FutureProvider<ActiveGemmaModelRuntime?>((ref) async {
      final installedModels = await gemma.FlutterGemma.listInstalledModels();
      if (installedModels.isEmpty) {
        return null;
      }

      final database = ref.watch(genaDatabaseProvider);
      final chatSettings = ref.read(chatModelSettingsProvider);

      final catalogModels = await (database.select(
        database.models,
      )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

      if (!gemma.FlutterGemma.hasActiveModel()) {
        await _recoverActiveModelFromCatalog(
          installedModels: installedModels,
          catalogModels: catalogModels,
        );
      }

      final activeCatalogModel = _resolveActiveCatalogModel(catalogModels);
      final supportImage = activeCatalogModel?.supportImage ?? false;
      final supportAudio = activeCatalogModel?.supportAudio ?? false;
      final supportsFunctionCalls =
          activeCatalogModel?.supportsFunctionCalls ?? false;
      final defaultIsThinking = activeCatalogModel?.isThinking ?? false;
      final modelTypeString = activeCatalogModel?.modelType ?? 'gemmaIt';

      final model = await _loadActiveModelWithRecovery(
        installedModels: installedModels,
        catalogModels: catalogModels,
        settings: chatSettings,
        supportImage: supportImage,
        supportAudio: supportAudio,
      );
      if (model == null) {
        logger.e(
          'Unable to load active model after recovery/fallback attempts. '
          'Returning null runtime to avoid crash.',
        );
        return null;
      }

      ref.onDispose(() {
        unawaited(model.close());
      });

      return ActiveGemmaModelRuntime(
        model: model,
        supportImage: supportImage,
        supportAudio: supportAudio,
        supportsFunctionCalls: supportsFunctionCalls,
        defaultIsThinking: defaultIsThinking,
        modelType: _parseModelType(modelTypeString),
      );
    });

final activeGemmaChatProvider = StreamProvider.autoDispose<GemmaChatSession?>((
  ref,
) async* {
  final modelRuntime = await ref.watch(activeGemmaModelRuntimeProvider.future);
  if (modelRuntime == null) {
    yield null;
    return;
  }

  final selectedChatId = ref.watch(selectedChatIdProvider);
  final chatSettings = ref.watch(chatModelSettingsProvider);
  if (selectedChatId == null) {
    yield null;
    return;
  }

  final database = ref.watch(genaDatabaseProvider);
  final parsedChatId = int.tryParse(selectedChatId);
  if (parsedChatId == null) {
    yield null;
    return;
  }

  try {
    final systemPrompt = chatSettings.systemPrompt.trim();
    final systemInstruction = _buildSystemInstruction(systemPrompt);
    final effectiveThinking =
        chatSettings.isThinkingOverride ?? modelRuntime.defaultIsThinking;
    final tools = buildChatTools(
      supportsFunctionCalls: modelRuntime.supportsFunctionCalls,
    );
    final chat = await modelRuntime.model.createChat(
      temperature: chatSettings.temperature,
      randomSeed: chatSettings.randomSeed,
      topK: chatSettings.topK,
      topP: chatSettings.topP,
      tokenBuffer: chatSettings.tokenBuffer,
      supportImage: modelRuntime.supportImage,
      supportAudio: modelRuntime.supportAudio,
      supportsFunctionCalls: modelRuntime.supportsFunctionCalls,
      tools: tools,
      isThinking: effectiveThinking,
      modelType: modelRuntime.modelType,
      systemInstruction: systemInstruction.isEmpty ? null : systemInstruction,
    );

    final storedMessages =
        await (database.select(database.messages)
              ..where((t) => t.chat.equals(parsedChatId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    for (var i = 0; i < storedMessages.length; i++) {
      final message = storedMessages[i];

      if (message.kind == 'image' && message.mediaPath != null) {
        final imageFile = File(message.mediaPath!);
        if (await imageFile.exists()) {
          final bytes = await imageFile.readAsBytes();
          final text = message.content.trim();
          await chat.addQueryChunk(
            text.isEmpty
                ? gemma.Message.imageOnly(
                    imageBytes: bytes,
                    isUser: message.role == 'user',
                  )
                : gemma.Message.withImage(
                    text: text,
                    imageBytes: bytes,
                    isUser: message.role == 'user',
                  ),
          );
          continue;
        }
      }

      await chat.addQueryChunk(
        gemma.Message.text(
          text: message.content,
          isUser: message.role == 'user',
        ),
      );
    }

    ref.onDispose(() {
      unawaited(chat.close());
    });
    yield GemmaChatSession(model: modelRuntime.model, chat: chat);
  } catch (e) {
    logger.e('Failed to initialize active Gemma chat session', error: e);
    yield null;
  }
});

gemma.ModelFileType _inferFileTypeFromSource(String source) {
  final lower = source.toLowerCase();
  if (lower.endsWith('.litertlm')) return gemma.ModelFileType.litertlm;
  if (lower.endsWith('.task')) return gemma.ModelFileType.task;
  return gemma.ModelFileType.binary;
}

Future<gemma.InferenceModel?> _loadActiveModelWithRecovery({
  required List<String> installedModels,
  required List<db.Model> catalogModels,
  required ChatModelSettings settings,
  required bool supportImage,
  required bool supportAudio,
}) async {
  try {
    return await _getActiveModelWithBackendFallbacks(
      maxTokens: settings.maxTokens,
      preferredBackend: settings.backend,
      supportImage: supportImage,
      supportAudio: supportAudio,
    );
  } catch (e) {
    final message = e.toString();
    final isRecoverable =
        message.contains('Active model is no longer installed') ||
        message.contains('No active inference model set');

    if (!isRecoverable || installedModels.isEmpty) {
      logger.e(
        'Failed to create model runtime. '
        'Likely model file is invalid/corrupted or backend is unsupported.',
        error: e,
      );
      return null;
    }

    final recovered = await _recoverActiveModelFromCatalog(
      installedModels: installedModels,
      catalogModels: catalogModels,
    );
    if (!recovered) {
      logger.e(
        'Active model recovery failed: no installed catalog entry matched.',
        error: e,
      );
      return null;
    }

    try {
      return await _getActiveModelWithBackendFallbacks(
        maxTokens: settings.maxTokens,
        preferredBackend: settings.backend,
        supportImage: supportImage,
        supportAudio: supportAudio,
      );
    } catch (retryError) {
      logger.e(
        'Model load still failing after active model recovery.',
        error: retryError,
      );
      return null;
    }
  }
}

Future<gemma.InferenceModel> _getActiveModelWithBackendFallbacks({
  required int maxTokens,
  required gemma.PreferredBackend? preferredBackend,
  required bool supportImage,
  required bool supportAudio,
}) async {
  final backends = <gemma.PreferredBackend?>[];

  void addBackend(gemma.PreferredBackend? backend) {
    if (backends.contains(backend)) return;
    backends.add(backend);
  }

  addBackend(preferredBackend);
  addBackend(null); // Let flutter_gemma auto-detect optimal backend
  addBackend(gemma.PreferredBackend.cpu);
  addBackend(gemma.PreferredBackend.gpu);
  addBackend(gemma.PreferredBackend.npu);

  Object? lastError;
  for (final backend in backends) {
    try {
      final model = await gemma.FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
        preferredBackend: backend,
        supportImage: supportImage,
        supportAudio: supportAudio,
      );
      if (backend != preferredBackend) {
        logger.w(
          'Model loaded with fallback backend: ${_backendName(backend)} '
          '(preferred: ${_backendName(preferredBackend)}).',
        );
      }
      return model;
    } catch (e) {
      lastError = e;
      logger.w(
        'Backend attempt failed: ${_backendName(backend)}. Trying next fallback.',
      );
    }
  }

  throw Exception(
    'Failed to create engine on all backend attempts. Last error: $lastError',
  );
}

String _backendName(gemma.PreferredBackend? backend) {
  if (backend == null) return 'auto';
  return backend.name;
}

Future<bool> _recoverActiveModelFromCatalog({
  required List<String> installedModels,
  required List<db.Model> catalogModels,
}) async {
  final installed = {for (final id in installedModels) id.toLowerCase(): id};

  for (final model in catalogModels) {
    final installedId = _installedModelIdFromSource(model.source);
    if (!installed.containsKey(installedId.toLowerCase())) continue;

    await _activateCatalogModel(model);
    logger.i('Recovered invalid active model with: $installedId');
    return true;
  }

  logger.w('Could not recover active model: no catalog model matched install.');
  return false;
}

Future<void> _activateCatalogModel(db.Model model) async {
  final installer = gemma.FlutterGemma.installModel(
    modelType: _parseModelType(model.modelType),
    fileType: _inferFileTypeFromSource(model.source),
  );

  final builder = model.sourceType == 'file'
      ? installer.fromFile(model.source)
      : installer.fromNetwork(model.source);
  await builder.install();
}

String _installedModelIdFromSource(String source) {
  final parts = source.split(RegExp(r'[/\\]'));
  return parts.isEmpty ? source : parts.last;
}

gemma.ModelType _parseModelType(String value) {
  return switch (value) {
    'general' => gemma.ModelType.general,
    'gemmaIt' => gemma.ModelType.gemmaIt,
    'gemma4' => gemma.ModelType.gemma4,
    'deepSeek' => gemma.ModelType.deepSeek,
    'qwen' => gemma.ModelType.qwen,
    'qwen3' => gemma.ModelType.qwen3,
    'llama' => gemma.ModelType.llama,
    'hammer' => gemma.ModelType.hammer,
    'functionGemma' => gemma.ModelType.functionGemma,
    'phi' => gemma.ModelType.phi,
    _ => gemma.ModelType.gemmaIt,
  };
}

db.Model? _resolveActiveCatalogModel(List<db.Model> catalogModels) {
  final activeSpec =
      gemma.FlutterGemmaPlugin.instance.modelManager.activeInferenceModel;
  if (activeSpec is! gemma.InferenceModelSpec) return null;
  final activeId = activeSpec.name.toLowerCase();

  for (final model in catalogModels) {
    final modelId = (model.modelId ?? '').trim().toLowerCase();
    if (modelId.isNotEmpty && modelId == activeId) {
      return model;
    }
  }

  for (final model in catalogModels) {
    final fallbackId = _modelSpecNameFromSource(model.source).toLowerCase();
    if (fallbackId == activeId) {
      return model;
    }
  }

  return null;
}

String _modelSpecNameFromSource(String source) {
  final parts = source.split(RegExp(r'[/\\]'));
  final filename = parts.isEmpty ? source : parts.last;
  final dotIndex = filename.lastIndexOf('.');
  if (dotIndex <= 0) return filename;
  return filename.substring(0, dotIndex);
}

String _buildSystemInstruction(String basePrompt) {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  const weekdayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final weekday = weekdayNames[now.weekday - 1];
  final dateContext = [
    'CURRENT LOCAL DATE CONTEXT',
    '- Today is $weekday, ${now.year}-$month-$day.',
    '- Local timezone: ${now.timeZoneName}.',
  ].join('\n');

  if (basePrompt.trim().isEmpty) {
    return dateContext;
  }
  return '${basePrompt.trim()}\n\n$dateContext';
}
