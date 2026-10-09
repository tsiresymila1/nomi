import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/chat/data/services/active_model_info_service.dart';
import 'package:gena/features/chat/data/services/chat_runtime_dependencies.dart';
import 'package:gena/features/chat/data/services/chat_thread_actions_service.dart';
import 'package:gena/features/chat/data/services/local_model_runtime.dart';
import 'package:gena/features/chat/presentation/cubit/chat_ui_cubits.dart';
import 'package:gena/features/chat/presentation/cubit/selected_chat_cubit.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, (_) async => true);
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, null);
  });

  test(
    'retry regenerates the failed turn without duplicating the user row',
    () async {
      final database = db.GenaDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await database
          .into(database.workspaces)
          .insert(db.WorkspacesCompanion.insert(name: 'Workspace'));
      final chatId = await database
          .into(database.chats)
          .insert(
            db.ChatsCompanion.insert(
              workspace: workspaceId,
              title: 'Existing title',
            ),
          );

      final generatingCubit = ChatGeneratingCubit();
      final responseCubit = ChatDraftResponseCubit();
      final thinkingCubit = ChatDraftThinkingCubit();
      final toolWaitingCubit = ChatToolWaitingCubit();
      final failureCubit = ChatGenerationFailureCubit();
      addTearDown(generatingCubit.close);
      addTearDown(responseCubit.close);
      addTearDown(thinkingCubit.close);
      addTearDown(toolWaitingCubit.close);
      addTearDown(failureCubit.close);

      var generationCalls = 0;
      final actions = ChatThreadActions(
        database: database,
        selectedChatCubit: _SelectedChatCubitFake(chatId.toString()),
        activeModelInfoResolver: _ActiveModelInfoResolverFake(_remoteModel),
        localModelRuntime: _LocalModelRuntimeFake(),
        chatGeneratingCubit: generatingCubit,
        chatDraftResponseCubit: responseCubit,
        chatDraftThinkingCubit: thinkingCubit,
        chatToolWaitingCubit: toolWaitingCubit,
        chatGenerationFailureCubit: failureCubit,
        runtimeDependencies: _ChatRuntimeDependenciesFake(),
        assistantGenerator:
            ({
              required database,
              required chatId,
              required activeModel,
              required isCancelled,
            }) async {
              generationCalls += 1;
              if (generationCalls == 1) {
                throw StateError('temporary backend failure');
              }
              await database
                  .into(database.messages)
                  .insert(
                    db.MessagesCompanion.insert(
                      chat: chatId,
                      role: 'assistant',
                      kind: const Value('text'),
                      content: 'Recovered response',
                    ),
                  );
            },
      );

      await actions.sendMessage('Hello once');

      final rowsAfterFailure = await database.select(database.messages).get();
      expect(rowsAfterFailure.where((row) => row.role == 'user'), hasLength(1));
      expect(rowsAfterFailure.where((row) => row.role == 'assistant'), isEmpty);
      expect(failureCubit.state?.chatId, chatId);
      expect(failureCubit.state?.userMessageId, rowsAfterFailure.single.id);
      expect(failureCubit.state?.canRetry, isTrue);
      expect(failureCubit.state?.displayMessage, isNot(contains('backend')));

      await actions.retryLastFailedGeneration();

      final rowsAfterRetry = await database.select(database.messages).get();
      expect(rowsAfterRetry.where((row) => row.role == 'user'), hasLength(1));
      expect(
        rowsAfterRetry.where((row) => row.role == 'assistant'),
        hasLength(1),
      );
      expect(rowsAfterRetry.last.content, 'Recovered response');
      expect(generationCalls, 2);
      expect(failureCubit.state, isNull);
      expect(generatingCubit.state, isFalse);
    },
  );

  test(
    'stopping generation keeps the turn retryable and replaces its partial response',
    () async {
      final database = db.GenaDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await database
          .into(database.workspaces)
          .insert(db.WorkspacesCompanion.insert(name: 'Workspace'));
      final chatId = await database
          .into(database.chats)
          .insert(
            db.ChatsCompanion.insert(
              workspace: workspaceId,
              title: 'Existing title',
            ),
          );

      final generatingCubit = ChatGeneratingCubit();
      final responseCubit = ChatDraftResponseCubit();
      final thinkingCubit = ChatDraftThinkingCubit();
      final toolWaitingCubit = ChatToolWaitingCubit();
      final failureCubit = ChatGenerationFailureCubit();
      addTearDown(generatingCubit.close);
      addTearDown(responseCubit.close);
      addTearDown(thinkingCubit.close);
      addTearDown(toolWaitingCubit.close);
      addTearDown(failureCubit.close);

      final generationStarted = Completer<void>();
      final releaseGeneration = Completer<void>();
      var generationCalls = 0;
      final actions = ChatThreadActions(
        database: database,
        selectedChatCubit: _SelectedChatCubitFake(chatId.toString()),
        activeModelInfoResolver: _ActiveModelInfoResolverFake(_remoteModel),
        localModelRuntime: _LocalModelRuntimeFake(),
        chatGeneratingCubit: generatingCubit,
        chatDraftResponseCubit: responseCubit,
        chatDraftThinkingCubit: thinkingCubit,
        chatToolWaitingCubit: toolWaitingCubit,
        chatGenerationFailureCubit: failureCubit,
        runtimeDependencies: _ChatRuntimeDependenciesFake(),
        assistantGenerator:
            ({
              required database,
              required chatId,
              required activeModel,
              required isCancelled,
            }) async {
              generationCalls += 1;
              if (generationCalls == 1) {
                responseCubit.setDraft('Partial response');
                generationStarted.complete();
                await releaseGeneration.future;
                if (isCancelled()) return;
              }
              await database
                  .into(database.messages)
                  .insert(
                    db.MessagesCompanion.insert(
                      chat: chatId,
                      role: 'assistant',
                      kind: const Value('text'),
                      content: 'Recovered response',
                    ),
                  );
            },
      );

      final send = actions.sendMessage('Please answer');
      await generationStarted.future;
      await actions.stopGeneration();
      releaseGeneration.complete();
      await send;

      final rowsAfterStop = await database.select(database.messages).get();
      expect(rowsAfterStop.where((row) => row.role == 'user'), hasLength(1));
      expect(
        rowsAfterStop.where((row) => row.role == 'assistant').single.content,
        'Partial response',
      );
      expect(failureCubit.state?.canRetry, isTrue);
      expect(failureCubit.state?.displayMessage, contains('stopped'));

      await actions.retryLastFailedGeneration();

      final rowsAfterRetry = await database.select(database.messages).get();
      expect(rowsAfterRetry.where((row) => row.role == 'user'), hasLength(1));
      expect(
        rowsAfterRetry.where((row) => row.role == 'assistant'),
        hasLength(1),
      );
      expect(rowsAfterRetry.last.content, 'Recovered response');
      expect(generationCalls, 2);
      expect(failureCubit.state, isNull);
    },
  );

  test(
    'a new message after stop waits for the cancelled generation to settle',
    () async {
      final database = db.GenaDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await database
          .into(database.workspaces)
          .insert(db.WorkspacesCompanion.insert(name: 'Workspace'));
      final chatId = await database
          .into(database.chats)
          .insert(
            db.ChatsCompanion.insert(
              workspace: workspaceId,
              title: 'Existing title',
            ),
          );

      final generatingCubit = ChatGeneratingCubit();
      final responseCubit = ChatDraftResponseCubit();
      final thinkingCubit = ChatDraftThinkingCubit();
      final toolWaitingCubit = ChatToolWaitingCubit();
      final failureCubit = ChatGenerationFailureCubit();
      addTearDown(generatingCubit.close);
      addTearDown(responseCubit.close);
      addTearDown(thinkingCubit.close);
      addTearDown(toolWaitingCubit.close);
      addTearDown(failureCubit.close);

      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final secondStarted = Completer<void>();
      var generationCalls = 0;
      final actions = ChatThreadActions(
        database: database,
        selectedChatCubit: _SelectedChatCubitFake(chatId.toString()),
        activeModelInfoResolver: _ActiveModelInfoResolverFake(_remoteModel),
        localModelRuntime: _LocalModelRuntimeFake(),
        chatGeneratingCubit: generatingCubit,
        chatDraftResponseCubit: responseCubit,
        chatDraftThinkingCubit: thinkingCubit,
        chatToolWaitingCubit: toolWaitingCubit,
        chatGenerationFailureCubit: failureCubit,
        runtimeDependencies: _ChatRuntimeDependenciesFake(),
        assistantGenerator:
            ({
              required database,
              required chatId,
              required activeModel,
              required isCancelled,
            }) async {
              generationCalls += 1;
              if (generationCalls == 1) {
                firstStarted.complete();
                await releaseFirst.future;
                if (isCancelled()) return;
              } else {
                secondStarted.complete();
                await database
                    .into(database.messages)
                    .insert(
                      db.MessagesCompanion.insert(
                        chat: chatId,
                        role: 'assistant',
                        kind: const Value('text'),
                        content: 'Second answer',
                      ),
                    );
              }
            },
      );

      final firstSend = actions.sendMessage('First message');
      await firstStarted.future;
      await actions.stopGeneration();

      final secondSend = actions.sendMessage('Second message');
      for (var attempt = 0; attempt < 20; attempt += 1) {
        final rows = await database.select(database.messages).get();
        if (rows.where((row) => row.role == 'user').length == 2) break;
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      expect(generationCalls, 1);
      releaseFirst.complete();
      await firstSend;
      await secondStarted.future;
      await secondSend;

      final rows = await database.select(database.messages).get();
      expect(rows.where((row) => row.role == 'user'), hasLength(2));
      expect(rows.where((row) => row.role == 'assistant'), hasLength(1));
      expect(rows.last.content, 'Second answer');
      expect(generationCalls, 2);
      expect(generatingCubit.state, isFalse);
      expect(failureCubit.state, isNull);
    },
  );
}

const _remoteModel = ModelInfo(
  id: 7,
  name: 'Remote test model',
  description: '',
  provider: ModelProviderType.remote,
  modelType: 'general',
  supportImage: false,
  supportAudio: false,
  supportsFunctionCalls: false,
  isThinking: false,
  temperature: 0.7,
  topK: 40,
  topP: 0.95,
  maxTokens: 2048,
  tokenBuffer: 256,
  randomSeed: 1,
  preferredBackend: 'cpu',
  sourceType: 'remote',
  source: 'remote-server://test/model',
);

class _SelectedChatCubitFake extends Fake implements SelectedChatCubit {
  _SelectedChatCubitFake(this._state);

  final String? _state;

  @override
  String? get state => _state;
}

class _ActiveModelInfoResolverFake extends Fake
    implements ActiveModelInfoResolver {
  _ActiveModelInfoResolverFake(this.model);

  final ModelInfo model;

  @override
  Future<ModelInfo?> getActiveModelInfo() async => model;
}

class _LocalModelRuntimeFake extends Fake implements LocalModelRuntime {
  @override
  void cancelActiveGeneration() {}
}

class _ChatRuntimeDependenciesFake extends Fake
    implements ChatRuntimeDependencies {}
