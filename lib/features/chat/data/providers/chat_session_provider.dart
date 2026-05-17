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
    final effectiveThinking =
        chatSettings.isThinkingOverride ?? modelRuntime.defaultIsThinking;
    final chat = await modelRuntime.model.createChat(
      temperature: chatSettings.temperature,
      randomSeed: chatSettings.randomSeed,
      topK: chatSettings.topK,
      topP: chatSettings.topP,
      tokenBuffer: chatSettings.tokenBuffer,
      supportImage: modelRuntime.supportImage,
      supportAudio: modelRuntime.supportAudio,
      supportsFunctionCalls: modelRuntime.supportsFunctionCalls,
      isThinking: effectiveThinking,
      modelType: modelRuntime.modelType,
      systemInstruction: systemPrompt.isEmpty ? null : systemPrompt,
    );

    final storedMessages =
        await (database.select(database.messages)
              ..where((t) => t.chat.equals(parsedChatId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    for (var i = 0; i < storedMessages.length; i++) {
      final message = storedMessages[i];
      final isLastMessage = i == storedMessages.length - 1;

      if (isLastMessage &&
          message.kind == 'image' &&
          message.mediaPath != null) {
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

Future<gemma.InferenceModel> _loadActiveModelWithRecovery({
  required List<String> installedModels,
  required List<db.Model> catalogModels,
  required ChatModelSettings settings,
  required bool supportImage,
  required bool supportAudio,
}) async {
  try {
    return await gemma.FlutterGemma.getActiveModel(
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

    if (!isRecoverable || installedModels.isEmpty) rethrow;

    final recovered = await _recoverActiveModelFromCatalog(
      installedModels: installedModels,
      catalogModels: catalogModels,
    );
    if (!recovered) rethrow;

    return await gemma.FlutterGemma.getActiveModel(
      maxTokens: settings.maxTokens,
      preferredBackend: settings.backend,
      supportImage: supportImage,
      supportAudio: supportAudio,
    );
  }
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
