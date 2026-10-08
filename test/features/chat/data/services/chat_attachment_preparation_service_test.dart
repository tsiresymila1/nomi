import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/models/chat_attachment.dart';
import 'package:gena/features/chat/data/services/chat_attachment_preparation_service.dart';
import 'package:gena/features/workspace/data/services/workspace_document_parser.dart';

void main() {
  late Directory tempDirectory;
  late ChatAttachmentPreparationService service;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'gena_attachment_test_',
    );
    service = ChatAttachmentPreparationService(
      parser: WorkspaceDocumentParser(),
      storageDirectoryProvider: () async => tempDirectory,
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('prepares a text document with bounded turn context', () async {
    final source = File('${tempDirectory.path}/notes.txt');
    await source.writeAsString('Alpha\nBeta');

    final attachment = await service.prepare(source.path);

    expect(attachment.kind, ChatAttachmentKind.document);
    expect(attachment.name, 'notes.txt');
    expect(attachment.sourceType, 'text');
    expect(attachment.extractedText, 'Alpha\nBeta');
    expect(attachment.appPath, isNot(source.path));
    expect(await File(attachment.appPath).exists(), isTrue);

    final context = buildTurnDocumentContext([attachment]);
    expect(context, contains('BEGIN ATTACHMENT: notes.txt'));
    expect(context, contains('Alpha\nBeta'));
    expect(context, contains('END ATTACHMENT: notes.txt'));
  });

  test('prepares an image without attempting text extraction', () async {
    final source = File('${tempDirectory.path}/photo.png');
    await source.writeAsBytes([137, 80, 78, 71]);

    final attachment = await service.prepare(source.path);

    expect(attachment.kind, ChatAttachmentKind.image);
    expect(attachment.sourceType, 'png');
    expect(attachment.extractedText, isNull);
    expect(buildTurnDocumentContext([attachment]), isEmpty);
  });

  test('rejects unsupported types with a stable failure code', () async {
    final source = File('${tempDirectory.path}/archive.zip');
    await source.writeAsBytes([1, 2, 3]);

    await expectLater(
      service.prepare(source.path),
      throwsA(
        isA<ChatAttachmentException>().having(
          (error) => error.code,
          'code',
          ChatAttachmentFailureCode.unsupportedType,
        ),
      ),
    );
  });

  test('rejects a missing file with a stable failure code', () async {
    await expectLater(
      service.prepare('${tempDirectory.path}/missing.pdf'),
      throwsA(
        isA<ChatAttachmentException>().having(
          (error) => error.code,
          'code',
          ChatAttachmentFailureCode.missingFile,
        ),
      ),
    );
  });
}
