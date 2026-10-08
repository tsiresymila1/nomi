import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/models/chat_attachment.dart';
import 'package:gena/features/chat/data/services/chat_attachment_preparation_service.dart';
import 'package:gena/features/chat/data/services/speech_to_text.dart';
import 'package:gena/features/workspace/data/services/workspace_document_parser.dart';

class _FakeSpeechToText implements SpeechToText {
  String transcript = 'Recorded project update';
  String? transcribedPath;

  @override
  bool get isAvailable => true;

  @override
  Future<void> ensureModelReady() async {}

  @override
  Future<SttResult> transcribe(String wavPath, {String lang = 'auto'}) async {
    transcribedPath = wavPath;
    expect(await File(wavPath).exists(), isTrue);
    return SttResult(text: transcript);
  }
}

void main() {
  late Directory tempDirectory;
  late ChatAttachmentPreparationService service;
  late _FakeSpeechToText speechToText;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'gena_attachment_test_',
    );
    speechToText = _FakeSpeechToText();
    service = ChatAttachmentPreparationService(
      parser: WorkspaceDocumentParser(),
      speechToText: speechToText,
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

  test('transcribes supported audio formats from the app-owned copy', () async {
    for (final extension in <String>[
      'wav',
      'mp3',
      'm4a',
      'aac',
      'flac',
      'ogg',
      'opus',
    ]) {
      final source = File('${tempDirectory.path}/voice.$extension');
      await source.writeAsBytes(<int>[1, 2, 3, 4]);

      final attachment = await service.prepare(source.path);

      expect(attachment.kind, ChatAttachmentKind.audio);
      expect(attachment.sourceType, extension);
      expect(attachment.extractedText, 'Recorded project update');
      expect(attachment.appPath, isNot(source.path));
      expect(speechToText.transcribedPath, attachment.appPath);
    }
  });

  test('rejects an audio attachment with a blank transcription', () async {
    speechToText.transcript = '   ';
    final source = File('${tempDirectory.path}/silence.mp3');
    await source.writeAsBytes(<int>[1, 2, 3]);

    await expectLater(
      service.prepare(source.path),
      throwsA(
        isA<ChatAttachmentException>().having(
          (error) => error.code,
          'code',
          ChatAttachmentFailureCode.transcriptionFailed,
        ),
      ),
    );
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
