import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/models/message_entity.dart';
import 'package:gena/features/chat/presentation/widgets/chat_bubble.dart';

void main() {
  testWidgets('renders persisted image, document, and audio attachments', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: 'Review these',
            isUser: true,
            attachments: [
              MessageAttachmentEntity(
                id: '1',
                kind: 'image',
                name: 'photo.png',
                sourceType: 'png',
                path: '/missing/photo.png',
                sizeBytes: 4,
              ),
              MessageAttachmentEntity(
                id: '2',
                kind: 'document',
                name: 'notes.txt',
                sourceType: 'text',
                path: '/missing/notes.txt',
                sizeBytes: 12,
              ),
              MessageAttachmentEntity(
                id: '3',
                kind: 'audio',
                name: 'meeting.m4a',
                sourceType: 'm4a',
                path: '/missing/meeting.m4a',
                sizeBytes: 42,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review these'), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as FileImage).file.path, '/missing/photo.png');
    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.text('meeting.m4a'), findsOneWidget);
    expect(find.byIcon(Icons.audio_file_outlined), findsOneWidget);
  });
}
