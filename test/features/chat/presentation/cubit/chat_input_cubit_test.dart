import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/services/chat_thread_actions_service.dart';
import 'package:gena/features/chat/presentation/cubit/chat_input_cubit.dart';

class _FakeThreadActions implements ChatThreadActionsApi {
  final List<({String text, String? imagePath})> sent = [];
  int stopCalls = 0;

  @override
  Future<void> sendMessage(String rawText, {String? imagePath}) async {
    sent.add((text: rawText, imagePath: imagePath));
  }

  @override
  Future<void> stopGeneration({
    bool triggerLocalModelCancel = true,
    bool waitForLocalModelCancel = true,
  }) async {
    stopCalls += 1;
  }
}

void main() {
  late _FakeThreadActions actions;
  late ChatInputCubit cubit;

  setUp(() {
    actions = _FakeThreadActions();
    cubit = ChatInputCubit(chatThreadActions: actions);
  });

  tearDown(() => cubit.close());

  group('setDraftText', () {
    test('updates the draft and ignores no-op updates', () async {
      expect(cubit.state.draftText, '');

      final emitted = <ChatInputState>[];
      final sub = cubit.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      cubit.setDraftText('hello');
      expect(cubit.state.draftText, 'hello');

      cubit.setDraftText('hello'); // identical -> no emit
      await Future<void>.delayed(Duration.zero);
      expect(emitted, hasLength(1));
    });
  });

  group('appendText', () {
    test('sets the draft when empty', () {
      cubit.appendText('  voice line  ');
      expect(cubit.state.draftText, 'voice line');
    });

    test('inserts a space when the existing draft lacks trailing whitespace',
        () {
      cubit.setDraftText('typed');
      cubit.appendText('spoken');
      expect(cubit.state.draftText, 'typed spoken');
    });

    test('does not double-space when the draft already ends in whitespace', () {
      cubit.setDraftText('typed ');
      cubit.appendText('spoken');
      expect(cubit.state.draftText, 'typed spoken');
    });

    test('ignores blank additions', () {
      cubit.setDraftText('typed');
      cubit.appendText('   ');
      expect(cubit.state.draftText, 'typed');
    });
  });

  group('clearSelectedImage', () {
    test('drops the selected image path', () {
      // No setter for the image without the picker; verify clear is a no-op
      // safe path that leaves the image null.
      cubit.clearSelectedImage();
      expect(cubit.state.selectedImagePath, isNull);
    });
  });

  group('sendMessage', () {
    test('does nothing when text is empty and no image is attached', () async {
      await cubit.sendMessage('   ');
      expect(actions.sent, isEmpty);
    });

    test('delegates trimmed text to the thread actions and resets the draft',
        () async {
      cubit.setDraftText('draft in progress');
      await cubit.sendMessage('  hi there  ');

      expect(actions.sent, hasLength(1));
      expect(actions.sent.single.text, 'hi there');
      expect(actions.sent.single.imagePath, isNull);
      // Draft is cleared and sending flag settles back to false.
      expect(cubit.state.draftText, '');
      expect(cubit.state.isSending, isFalse);
      expect(cubit.state.selectedImagePath, isNull);
    });

    test('ignores re-entrant sends while one is in flight', () async {
      // Drive a long-running send to observe the in-flight guard.
      final gate = _GatedThreadActions();
      final gatedCubit = ChatInputCubit(chatThreadActions: gate);
      addTearDown(gatedCubit.close);

      final first = gatedCubit.sendMessage('one');
      // While the first send awaits, isSending is true and a second send is
      // dropped.
      expect(gatedCubit.state.isSending, isTrue);
      await gatedCubit.sendMessage('two');
      expect(gate.sent, hasLength(0));

      gate.release();
      await first;
      expect(gate.sent.single, 'one');
      expect(gatedCubit.state.isSending, isFalse);
    });
  });

  group('stopGeneration', () {
    test('delegates to the thread actions', () async {
      await cubit.stopGeneration();
      expect(actions.stopCalls, 1);
    });
  });
}

/// Thread actions whose [sendMessage] blocks until [release] is called, used to
/// observe the in-flight send guard deterministically.
class _GatedThreadActions implements ChatThreadActionsApi {
  final List<String> sent = [];
  final _completer = Completer<void>();

  void release() => _completer.complete();

  @override
  Future<void> sendMessage(String rawText, {String? imagePath}) async {
    await _completer.future;
    sent.add(rawText);
  }

  @override
  Future<void> stopGeneration({
    bool triggerLocalModelCancel = true,
    bool waitForLocalModelCancel = true,
  }) async {}
}
