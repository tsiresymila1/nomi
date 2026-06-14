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

  group('ChatModelSwitchingCubit', () {
    test('emits true on first start and false only when balanced stops occur',
        () async {
      final cubit = ChatModelSwitchingCubit();
      addTearDown(cubit.close);
      final emitted = <bool>[];
      final sub = cubit.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      expect(cubit.state, isFalse);

      cubit.start();
      expect(cubit.state, isTrue);

      // Nested start must not re-emit true.
      cubit.start();
      expect(cubit.state, isTrue);

      // First stop only decrements; still switching.
      cubit.stop();
      expect(cubit.state, isTrue);

      // Second stop balances the two starts -> false.
      cubit.stop();
      expect(cubit.state, isFalse);

      // Stream delivery is asynchronous; let it flush.
      await Future<void>.delayed(Duration.zero);
      expect(emitted, [true, false]);
    });

    test('extra stop calls do not underflow or re-emit', () {
      final cubit = ChatModelSwitchingCubit();
      addTearDown(cubit.close);

      cubit.stop();
      expect(cubit.state, isFalse);

      cubit.start();
      cubit.stop();
      cubit.stop(); // extra stop, no pending operations
      expect(cubit.state, isFalse);
    });
  });
}
