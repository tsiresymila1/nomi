import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/services/chat_thread_actions_service.dart';
import 'package:gena/features/chat/data/models/chat_attachment.dart';
import 'package:gena/features/chat/data/services/chat_attachment_preparation_service.dart';
import 'package:gena/features/chat/presentation/cubit/chat_attachments_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/chat_input_cubit.dart';

class _FakeThreadActions implements ChatThreadActionsApi {
  final List<
    ({String text, String? imagePath, List<PreparedChatAttachment> attachments})
  >
  sent = [];
  int stopCalls = 0;

  @override
  Future<void> sendMessage(
    String rawText, {
    String? imagePath,
    List<PreparedChatAttachment> attachments = const [],
  }) async {
    sent.add((text: rawText, imagePath: imagePath, attachments: attachments));
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
  late ChatAttachmentsCubit attachmentsCubit;

  setUp(() {
    actions = _FakeThreadActions();
    attachmentsCubit = ChatAttachmentsCubit(
      preparer: _FakeAttachmentPreparer(),
    );
    cubit = ChatInputCubit(
      chatThreadActions: actions,
      attachmentsCubit: attachmentsCubit,
    );
  });

  tearDown(() async {
    await cubit.close();
    await attachmentsCubit.close();
  });

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

    test(
      'inserts a space when the existing draft lacks trailing whitespace',
      () {
        cubit.setDraftText('typed');
        cubit.appendText('spoken');
        expect(cubit.state.draftText, 'typed spoken');
      },
    );

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

    test(
      'delegates trimmed text to the thread actions and resets the draft',
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
      },
    );

    test('sends all ready typed attachments and consumes the draft', () async {
      await attachmentsCubit.addPath('/picked/notes.txt');

      await cubit.sendMessage('  summarize  ');

      expect(actions.sent.single.attachments, hasLength(1));
      expect(actions.sent.single.attachments.single.name, 'notes.txt');
      expect(attachmentsCubit.readyAttachments, isEmpty);
    });

    test('ignores re-entrant sends while one is in flight', () async {
      // Drive a long-running send to observe the in-flight guard.
      final gate = _GatedThreadActions();
      final gatedAttachments = ChatAttachmentsCubit(
        preparer: _FakeAttachmentPreparer(),
      );
      final gatedCubit = ChatInputCubit(
        chatThreadActions: gate,
        attachmentsCubit: gatedAttachments,
      );
      addTearDown(gatedCubit.close);
      addTearDown(gatedAttachments.close);

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

    test('allows a new send after stopping an in-flight send', () async {
      final gate = _StopAwareThreadActions();
      final gatedAttachments = ChatAttachmentsCubit(
        preparer: _FakeAttachmentPreparer(),
      );
      final gatedCubit = ChatInputCubit(
        chatThreadActions: gate,
        attachmentsCubit: gatedAttachments,
      );
      addTearDown(gatedCubit.close);
      addTearDown(gatedAttachments.close);

      final first = gatedCubit.sendMessage('one');
      expect(gatedCubit.state.isSending, isTrue);

      await gatedCubit.stopGeneration();
      expect(gatedCubit.state.isSending, isFalse);

      final second = gatedCubit.sendMessage('two');
      expect(gate.started, ['one', 'two']);
      expect(gatedCubit.state.isSending, isTrue);

      gate.releaseFirst();
      await first;
      expect(
        gatedCubit.state.isSending,
        isTrue,
        reason: 'the stopped send must not clear the newer send state',
      );

      gate.releaseSecond();
      await second;
      expect(gatedCubit.state.isSending, isFalse);
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
  Future<void> sendMessage(
    String rawText, {
    String? imagePath,
    List<PreparedChatAttachment> attachments = const [],
  }) async {
    await _completer.future;
    sent.add(rawText);
  }

  @override
  Future<void> stopGeneration({
    bool triggerLocalModelCancel = true,
    bool waitForLocalModelCancel = true,
  }) async {}
}

class _StopAwareThreadActions implements ChatThreadActionsApi {
  final List<String> started = [];
  final _first = Completer<void>();
  final _second = Completer<void>();

  void releaseFirst() => _first.complete();

  void releaseSecond() => _second.complete();

  @override
  Future<void> sendMessage(
    String rawText, {
    String? imagePath,
    List<PreparedChatAttachment> attachments = const [],
  }) async {
    started.add(rawText);
    await (started.length == 1 ? _first.future : _second.future);
  }

  @override
  Future<void> stopGeneration({
    bool triggerLocalModelCancel = true,
    bool waitForLocalModelCancel = true,
  }) async {}
}

class _FakeAttachmentPreparer implements ChatAttachmentPreparer {
  @override
  Future<PreparedChatAttachment> prepare(String rawPath) async {
    return const PreparedChatAttachment(
      id: 'attachment-1',
      name: 'notes.txt',
      kind: ChatAttachmentKind.document,
      sourceType: 'text',
      appPath: '/app/notes.txt',
      sizeBytes: 12,
      extractedText: 'hello',
    );
  }

  @override
  Future<void> deletePrepared(PreparedChatAttachment attachment) async {}
}
