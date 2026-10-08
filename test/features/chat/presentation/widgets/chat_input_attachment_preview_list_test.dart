import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/models/chat_attachment.dart';
import 'package:gena/features/chat/presentation/widgets/chat_input_attachment_preview_list.dart';

void main() {
  testWidgets('shows preparation, failure, remove, and workspace actions', (
    tester,
  ) async {
    String? removedId;
    String? indexedId;
    const document = PreparedChatAttachment(
      id: 'document-1',
      name: 'notes.txt',
      kind: ChatAttachmentKind.document,
      sourceType: 'text',
      appPath: '/app/notes.txt',
      sizeBytes: 12,
      extractedText: 'hello',
    );
    const audio = PreparedChatAttachment(
      id: 'audio-1',
      name: 'meeting.m4a',
      kind: ChatAttachmentKind.audio,
      sourceType: 'm4a',
      appPath: '/app/meeting.m4a',
      sizeBytes: 42,
      extractedText: 'hello from audio',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputAttachmentPreviewList(
            attachments: const [
              ChatAttachmentDraft(
                id: 'ready',
                originalPath: '/picked/notes.txt',
                displayName: 'notes.txt',
                status: ChatAttachmentDraftStatus.ready,
                attachment: document,
              ),
              ChatAttachmentDraft(
                id: 'loading',
                originalPath: '/picked/report.pdf',
                displayName: 'report.pdf',
                status: ChatAttachmentDraftStatus.preparing,
              ),
              ChatAttachmentDraft(
                id: 'failed',
                originalPath: '/picked/archive.zip',
                displayName: 'archive.zip',
                status: ChatAttachmentDraftStatus.failed,
                errorMessage: 'This file type is not supported.',
              ),
              ChatAttachmentDraft(
                id: 'audio-ready',
                originalPath: '/picked/meeting.m4a',
                displayName: 'meeting.m4a',
                status: ChatAttachmentDraftStatus.ready,
                attachment: audio,
              ),
            ],
            onRemove: (id) => removedId = id,
            onAddToWorkspace: (attachment) => indexedId = attachment.id,
          ),
        ),
      ),
    );

    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.text('meeting.m4a'), findsOneWidget);
    expect(find.byIcon(Icons.audio_file_outlined), findsOneWidget);
    expect(
      find.byKey(const ValueKey('index-attachment-audio-ready')),
      findsNothing,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('This file type is not supported.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('index-attachment-ready')));
    expect(indexedId, 'document-1');
    await tester.tap(find.byKey(const ValueKey('remove-attachment-failed')));
    expect(removedId, 'failed');
  });
}
