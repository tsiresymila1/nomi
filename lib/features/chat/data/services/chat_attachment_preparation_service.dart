import 'dart:io';

import 'package:gena/features/chat/data/models/chat_attachment.dart';
import 'package:gena/features/chat/data/services/speech_to_text.dart';
import 'package:gena/features/workspace/data/services/workspace_document_parser.dart';
import 'package:path_provider/path_provider.dart';

abstract interface class ChatAttachmentPreparer {
  Future<PreparedChatAttachment> prepare(String rawPath);

  Future<void> deletePrepared(PreparedChatAttachment attachment);
}

class ChatAttachmentPreparationService implements ChatAttachmentPreparer {
  ChatAttachmentPreparationService({
    required WorkspaceDocumentParser parser,
    required SpeechToText speechToText,
    Future<Directory> Function()? storageDirectoryProvider,
  }) : _parser = parser,
       _speechToText = speechToText,
       _storageDirectoryProvider =
           storageDirectoryProvider ?? getApplicationSupportDirectory;

  static const int maxInputBytes = 32 * 1024 * 1024;
  static const int maxTurnDocumentCharacters = 120000;
  static const Set<String> _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  };
  static const Set<String> audioExtensions = {
    'wav',
    'mp3',
    'm4a',
    'aac',
    'flac',
    'ogg',
    'opus',
  };

  final WorkspaceDocumentParser _parser;
  final SpeechToText _speechToText;
  final Future<Directory> Function() _storageDirectoryProvider;
  int _nextId = 0;

  @override
  Future<PreparedChatAttachment> prepare(String rawPath) async {
    final sourcePath = _normalizeFileUriToPath(rawPath.trim());
    final source = File(sourcePath);
    if (sourcePath.isEmpty || !await source.exists()) {
      throw const ChatAttachmentException(
        code: ChatAttachmentFailureCode.missingFile,
        userMessage: 'This file is no longer available.',
      );
    }

    final sizeBytes = await source.length();
    if (sizeBytes > maxInputBytes) {
      throw const ChatAttachmentException(
        code: ChatAttachmentFailureCode.tooLarge,
        userMessage: 'This file is too large. The limit is 32 MB.',
      );
    }

    final name = source.uri.pathSegments.isEmpty
        ? 'attachment'
        : source.uri.pathSegments.last;
    final extension = _extensionOf(name);
    final kind = _imageExtensions.contains(extension)
        ? ChatAttachmentKind.image
        : audioExtensions.contains(extension)
        ? ChatAttachmentKind.audio
        : ChatAttachmentKind.document;

    late final String sourceType;
    if (kind == ChatAttachmentKind.image || kind == ChatAttachmentKind.audio) {
      sourceType = extension;
    } else {
      try {
        sourceType = _parser.detectSourceType(sourcePath);
      } on FormatException {
        throw const ChatAttachmentException(
          code: ChatAttachmentFailureCode.unsupportedType,
          userMessage: 'This file type is not supported.',
        );
      }
    }

    final id = _newId();
    final copied = await _copyToAppStorage(source: source, id: id, name: name);

    String? extractedText;
    if (kind == ChatAttachmentKind.document) {
      try {
        final parsed = await _parser.parseStoredSource(
          sourcePath: copied.path,
          sourceType: sourceType,
        );
        extractedText = _capTurnText(parsed.content);
      } catch (_) {
        await _deleteIfPresent(copied);
        throw const ChatAttachmentException(
          code: ChatAttachmentFailureCode.extractionFailed,
          userMessage: 'The document text could not be extracted.',
        );
      }
    }
    if (kind == ChatAttachmentKind.audio) {
      try {
        final transcription = await _speechToText.transcribe(copied.path);
        final text = transcription.text.trim();
        if (text.isEmpty) {
          throw const SpeechToTextException(
            'No speech was detected in this audio file.',
          );
        }
        extractedText = _capTurnText(text);
      } catch (_) {
        await _deleteIfPresent(copied);
        throw const ChatAttachmentException(
          code: ChatAttachmentFailureCode.transcriptionFailed,
          userMessage: 'The audio file could not be transcribed.',
        );
      }
    }

    return PreparedChatAttachment(
      id: id,
      name: name,
      kind: kind,
      sourceType: sourceType,
      appPath: copied.path,
      sizeBytes: sizeBytes,
      extractedText: extractedText,
    );
  }

  @override
  Future<void> deletePrepared(PreparedChatAttachment attachment) {
    return _deleteIfPresent(File(attachment.appPath));
  }

  Future<File> _copyToAppStorage({
    required File source,
    required String id,
    required String name,
  }) async {
    final supportDirectory = await _storageDirectoryProvider();
    final targetDirectory = Directory(
      '${supportDirectory.path}/chat_attachments',
    );
    if (!await targetDirectory.exists()) {
      await targetDirectory.create(recursive: true);
    }
    final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return source.copy('${targetDirectory.path}/${id}_$safeName');
  }

  Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }

  String _newId() {
    _nextId += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_nextId';
  }

  String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  String _normalizeFileUriToPath(String source) {
    if (!source.startsWith('file://')) return source;
    final uri = Uri.tryParse(source);
    if (uri == null || uri.scheme != 'file') return source;
    return uri.toFilePath();
  }

  String _capTurnText(String text) {
    if (text.length <= maxTurnDocumentCharacters) return text;
    return text.substring(0, maxTurnDocumentCharacters);
  }
}

String buildTurnDocumentContext(
  Iterable<PreparedChatAttachment> attachments, {
  int maxCharacters =
      ChatAttachmentPreparationService.maxTurnDocumentCharacters,
}) {
  if (maxCharacters <= 0) return '';
  final buffer = StringBuffer();

  for (final attachment in attachments) {
    if (attachment.kind == ChatAttachmentKind.image) continue;
    final text = attachment.extractedText?.trim() ?? '';
    if (text.isEmpty) continue;

    final label = attachment.kind == ChatAttachmentKind.audio
        ? 'AUDIO TRANSCRIPT'
        : 'ATTACHMENT';
    final opening = '--- BEGIN $label: ${attachment.name} ---\n';
    final closing = '\n--- END $label: ${attachment.name} ---';
    final separator = buffer.isEmpty ? '' : '\n\n';
    final remaining = maxCharacters - buffer.length - separator.length;
    if (remaining <= opening.length + closing.length) break;
    final availableText = remaining - opening.length - closing.length;
    final boundedText = text.length <= availableText
        ? text
        : text.substring(0, availableText);
    buffer.write(separator);
    buffer
      ..write(opening)
      ..write(boundedText)
      ..write(closing);
  }

  return buffer.toString();
}
