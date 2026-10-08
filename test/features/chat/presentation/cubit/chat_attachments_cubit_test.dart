import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/models/chat_attachment.dart';
import 'package:gena/features/chat/data/services/chat_attachment_preparation_service.dart';
import 'package:gena/features/chat/presentation/cubit/chat_attachments_cubit.dart';

void main() {
  test('tracks preparation success and removes app-owned files', () async {
    final preparer = _FakeAttachmentPreparer();
    final cubit = ChatAttachmentsCubit(preparer: preparer);
    addTearDown(cubit.close);

    await cubit.addPath('/picked/notes.txt');

    expect(cubit.state, hasLength(1));
    expect(cubit.state.single.status, ChatAttachmentDraftStatus.ready);
    expect(cubit.state.single.attachment?.name, 'notes.txt');

    await cubit.remove(cubit.state.single.id);
    expect(cubit.state, isEmpty);
    expect(preparer.deletedPaths, ['/app/notes.txt']);
  });

  test('keeps a failed draft with an actionable message', () async {
    final preparer = _FakeAttachmentPreparer()..shouldFail = true;
    final cubit = ChatAttachmentsCubit(preparer: preparer);
    addTearDown(cubit.close);

    await cubit.addPath('/picked/archive.zip');

    expect(cubit.state, hasLength(1));
    expect(cubit.state.single.status, ChatAttachmentDraftStatus.failed);
    expect(cubit.state.single.errorMessage, contains('not supported'));
    expect(cubit.readyAttachments, isEmpty);
  });
}

class _FakeAttachmentPreparer implements ChatAttachmentPreparer {
  bool shouldFail = false;
  final List<String> deletedPaths = [];

  @override
  Future<PreparedChatAttachment> prepare(String rawPath) async {
    if (shouldFail) {
      throw const ChatAttachmentException(
        code: ChatAttachmentFailureCode.unsupportedType,
        userMessage: 'This file type is not supported.',
      );
    }
    return const PreparedChatAttachment(
      id: 'prepared-1',
      name: 'notes.txt',
      kind: ChatAttachmentKind.document,
      sourceType: 'text',
      appPath: '/app/notes.txt',
      sizeBytes: 12,
      extractedText: 'hello',
    );
  }

  @override
  Future<void> deletePrepared(PreparedChatAttachment attachment) async {
    deletedPaths.add(attachment.appPath);
  }
}
