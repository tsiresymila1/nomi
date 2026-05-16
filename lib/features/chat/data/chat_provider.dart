import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/features/chat/domain/entities/chat_entity.dart';
import 'package:gena/features/chat/domain/entities/message_entity.dart';
import 'package:gena/features/setting/data/chat_model_settings.dart';
import 'package:gena/features/setting/data/chat_model_settings_provider.dart';

class GemmaChatSession {
  final gemma.InferenceModel model;
  final gemma.InferenceChat chat;

  const GemmaChatSession({required this.model, required this.chat});
}

final chatListProvider = StreamProvider<List<ChatEntity>>((ref) {
  final database = ref.watch(genaDatabaseProvider);
  final query = database.select(database.chats)
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

  return query.watch().map(
    (rows) => rows
        .map(
          (row) => ChatEntity(
            id: row.id.toString(),
            title: row.title,
            createdAt: row.createdAt,
            updatedAt: row.createdAt,
          ),
        )
        .toList(),
  );
});

final chatMessagesProvider = StreamProvider.family<List<MessageEntity>, String>(
  (ref, chatId) {
    final database = ref.watch(genaDatabaseProvider);
    final parsedChatId = int.tryParse(chatId);
    if (parsedChatId == null) {
      return Stream.value(const <MessageEntity>[]);
    }

    final query = database.select(database.messages)
      ..where((t) => t.chat.equals(parsedChatId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => MessageEntity(
              id: row.id.toString(),
              chatId: row.chat.toString(),
              role: row.role,
              content: row.content,
              createdAt: row.createdAt,
            ),
          )
          .toList(),
    );
  },
);

final selectedChatIdProvider =
    NotifierProvider<SelectedChatIdNotifier, String?>(
      SelectedChatIdNotifier.new,
    );

class SelectedChatIdNotifier extends Notifier<String?> {
  bool _initialized = false;

  @override
  String? build() {
    _hydrateInitialSelection();
    return null;
  }

  Future<void> _hydrateInitialSelection() async {
    if (_initialized) return;
    _initialized = true;

    final database = ref.read(genaDatabaseProvider);
    final firstChat =
        await (database.select(database.chats)
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (firstChat != null) {
      state = firstChat.id.toString();
    }
  }

  Future<String> createNewThread() async {
    final database = ref.read(genaDatabaseProvider);
    final createdId = await database
        .into(database.chats)
        .insert(db.ChatsCompanion.insert(title: 'New chat'));

    final selectedId = createdId.toString();
    state = selectedId;
    return selectedId;
  }

  void selectChat(String? chatId) {
    if (chatId == state) return;
    state = chatId;
  }
}

final activeGemmaChatProvider = StreamProvider.autoDispose<GemmaChatSession?>((
  ref,
) async* {
  final installedModels = await gemma.FlutterGemma.listInstalledModels();
  if (installedModels.isEmpty) {
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
    final catalogModels = await (database.select(
      database.models,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

    if (!gemma.FlutterGemma.hasActiveModel()) {
      await _recoverActiveModelFromCatalog(
        installedModels: installedModels,
        catalogModels: catalogModels,
      );
    }

    final model = await _loadActiveModelWithRecovery(
      installedModels: installedModels,
      catalogModels: catalogModels,
      settings: chatSettings,
    );
    final systemPrompt = chatSettings.systemPrompt.trim();
    final chat = await model.createChat(
      temperature: chatSettings.temperature,
      randomSeed: chatSettings.randomSeed,
      topK: chatSettings.topK,
      topP: chatSettings.topP,
      tokenBuffer: chatSettings.tokenBuffer,
      isThinking: chatSettings.isThinking,
      systemInstruction: systemPrompt.isEmpty ? null : systemPrompt,
    );

    final storedMessages =
        await (database.select(database.messages)
              ..where((t) => t.chat.equals(parsedChatId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    for (final message in storedMessages) {
      await chat.addQueryChunk(
        gemma.Message.text(
          text: message.content,
          isUser: message.role == 'user',
        ),
      );
    }

    ref.onDispose(() {
      unawaited(chat.close());
      unawaited(model.close());
    });
    yield GemmaChatSession(model: model, chat: chat);
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
}) async {
  try {
    return await gemma.FlutterGemma.getActiveModel(
      maxTokens: settings.maxTokens,
      preferredBackend: settings.backend,
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

final chatDraftResponseProvider =
    NotifierProvider<ChatDraftResponseNotifier, String?>(
      ChatDraftResponseNotifier.new,
    );

class ChatDraftResponseNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setDraft(String value) {
    state = value;
  }

  void clear() {
    state = null;
  }
}

final chatGeneratingProvider = NotifierProvider<ChatGeneratingNotifier, bool>(
  ChatGeneratingNotifier.new,
);

class ChatGeneratingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setGenerating(bool value) {
    state = value;
  }
}

final chatThreadActionsProvider = Provider<ChatThreadActions>(
  (ref) => ChatThreadActions(ref),
);

class ChatThreadActions {
  final Ref ref;
  ChatThreadActions(this.ref);

  Future<void> sendMessage(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return;

    var chatId = ref.read(selectedChatIdProvider);
    chatId ??= await ref
        .read(selectedChatIdProvider.notifier)
        .createNewThread();

    final parsedChatId = int.tryParse(chatId);
    if (parsedChatId == null) return;

    final session = await ref.read(activeGemmaChatProvider.future);
    if (session == null) return;

    final database = ref.read(genaDatabaseProvider);

    await database
        .into(database.messages)
        .insert(
          db.MessagesCompanion.insert(
            chat: parsedChatId,
            role: 'user',
            content: text,
          ),
        );

    await session.chat.addQueryChunk(
      gemma.Message.text(text: text, isUser: true),
    );

    ref.read(chatGeneratingProvider.notifier).setGenerating(true);
    ref.read(chatDraftResponseProvider.notifier).setDraft('');

    final responseBuffer = StringBuffer();
    try {
      await for (final response in session.chat.generateChatResponseAsync()) {
        if (response is gemma.TextResponse) {
          responseBuffer.write(response.token);
          ref
              .read(chatDraftResponseProvider.notifier)
              .setDraft(responseBuffer.toString());
        }
      }
    } finally {
      ref.read(chatGeneratingProvider.notifier).setGenerating(false);
    }

    final responseText = responseBuffer.toString().trim();
    if (responseText.isNotEmpty) {
      await database
          .into(database.messages)
          .insert(
            db.MessagesCompanion.insert(
              chat: parsedChatId,
              role: 'assistant',
              content: responseText,
            ),
          );
    }

    ref.read(chatDraftResponseProvider.notifier).clear();
  }
}
