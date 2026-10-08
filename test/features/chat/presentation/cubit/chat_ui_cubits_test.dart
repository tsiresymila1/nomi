import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/presentation/cubit/chat_ui_cubits.dart';

void main() {
  group('ChatContextWindowCubit', () {
    test('starts null, updates, and clears', () {
      final cubit = ChatContextWindowCubit();
      addTearDown(cubit.close);

      expect(cubit.state, isNull);

      const window = ChatContextWindowState(
        maxTokens: 2048,
        reservedOutputTokens: 256,
        estimatedPromptTokens: 100,
        remainingTokens: 1692,
        compactedMessages: 2,
      );
      cubit.update(window);
      expect(cubit.state, same(window));
      expect(cubit.state!.maxTokens, 2048);
      expect(cubit.state!.remainingTokens, 1692);

      cubit.clear();
      expect(cubit.state, isNull);
    });
  });

  group('ChatDraftResponseCubit', () {
    test('sets and clears the draft response', () {
      final cubit = ChatDraftResponseCubit();
      addTearDown(cubit.close);

      expect(cubit.state, isNull);
      cubit.setDraft('partial answer');
      expect(cubit.state, 'partial answer');
      cubit.clear();
      expect(cubit.state, isNull);
    });
  });

  group('ChatDraftThinkingCubit', () {
    test('sets and clears the draft thinking text', () {
      final cubit = ChatDraftThinkingCubit();
      addTearDown(cubit.close);

      expect(cubit.state, isNull);
      cubit.setDraft('reasoning...');
      expect(cubit.state, 'reasoning...');
      cubit.clear();
      expect(cubit.state, isNull);
    });
  });

  group('ChatGeneratingCubit', () {
    test('toggles the generating flag', () {
      final cubit = ChatGeneratingCubit();
      addTearDown(cubit.close);

      expect(cubit.state, isFalse);
      cubit.setGenerating(true);
      expect(cubit.state, isTrue);
      cubit.setGenerating(false);
      expect(cubit.state, isFalse);
    });
  });

  group('ChatToolWaitingCubit', () {
    test('records the waiting tool name and clears it', () {
      final cubit = ChatToolWaitingCubit();
      addTearDown(cubit.close);

      expect(cubit.state, isNull);
      cubit.setWaitingTool('calculator');
      expect(cubit.state, 'calculator');
      cubit.clear();
      expect(cubit.state, isNull);
    });
  });

  group('ChatGenerationFailureCubit', () {
    test('tracks a retryable failed turn and clears it', () {
      final cubit = ChatGenerationFailureCubit();
      addTearDown(cubit.close);

      expect(cubit.state, isNull);

      cubit.fail(
        chatId: 12,
        userMessageId: 34,
        displayMessage: 'Could not complete the response.',
        canRetry: true,
      );

      expect(cubit.state?.chatId, 12);
      expect(cubit.state?.userMessageId, 34);
      expect(cubit.state?.displayMessage, 'Could not complete the response.');
      expect(cubit.state?.canRetry, isTrue);

      cubit.clear();
      expect(cubit.state, isNull);
    });
  });

  group('ChatModelSwitchingCubit', () {
    test('tracks a typed model loading lifecycle', () {
      final cubit = ChatModelSwitchingCubit();
      addTearDown(cubit.close);

      expect(cubit.state.phase, ChatModelSwitchPhase.idle);
      expect(cubit.state.isBusy, isFalse);

      final operationId = cubit.begin(
        modelId: 42,
        modelName: 'Tiny local model',
        origin: ChatModelSwitchOrigin.selection,
      );

      expect(cubit.state.phase, ChatModelSwitchPhase.stoppingGeneration);
      expect(cubit.state.operationId, operationId);
      expect(cubit.state.modelId, 42);
      expect(cubit.state.modelName, 'Tiny local model');
      expect(cubit.state.origin, ChatModelSwitchOrigin.selection);
      expect(cubit.state.isBusy, isTrue);

      cubit.advance(operationId, ChatModelSwitchPhase.unloading);
      expect(cubit.state.phase, ChatModelSwitchPhase.unloading);

      cubit.advance(operationId, ChatModelSwitchPhase.loading);
      expect(cubit.state.phase, ChatModelSwitchPhase.loading);

      cubit.complete(operationId);
      expect(cubit.state.phase, ChatModelSwitchPhase.ready);
      expect(cubit.state.isBusy, isFalse);
    });

    test(
      'stale operations cannot advance, fail, or complete a newer switch',
      () {
        final cubit = ChatModelSwitchingCubit();
        addTearDown(cubit.close);

        final staleId = cubit.begin(
          modelId: 1,
          modelName: 'Old',
          origin: ChatModelSwitchOrigin.backgroundWarmup,
          initialPhase: ChatModelSwitchPhase.loading,
        );
        final currentId = cubit.begin(
          modelId: 2,
          modelName: 'New',
          origin: ChatModelSwitchOrigin.selection,
        );

        cubit.advance(staleId, ChatModelSwitchPhase.unloading);
        cubit.fail(staleId, 'old failure');
        cubit.complete(staleId);

        expect(cubit.state.operationId, currentId);
        expect(cubit.state.modelId, 2);
        expect(cubit.state.phase, ChatModelSwitchPhase.stoppingGeneration);
        expect(cubit.state.errorMessage, isNull);
      },
    );

    test('failure is recoverable and a new operation clears it', () {
      final cubit = ChatModelSwitchingCubit();
      addTearDown(cubit.close);

      final failedId = cubit.begin(
        modelId: 7,
        modelName: 'Broken',
        origin: ChatModelSwitchOrigin.selection,
      );
      cubit.fail(failedId, 'Could not load model');

      expect(cubit.state.phase, ChatModelSwitchPhase.failed);
      expect(cubit.state.errorMessage, 'Could not load model');
      expect(cubit.state.isBusy, isFalse);

      cubit.begin(
        modelId: 8,
        modelName: 'Retry target',
        origin: ChatModelSwitchOrigin.selection,
      );
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.phase, ChatModelSwitchPhase.stoppingGeneration);
    });
  });
}
