import 'dart:convert';
import 'dart:io';

import 'package:doc_text_extractor/doc_text_extractor.dart';
import 'package:path_provider/path_provider.dart';

class ParsedWorkspaceDocument {
  final String name;
  final String sourceType;
  final String sourcePath;
  final String content;
  final List<String> chunks;

  const ParsedWorkspaceDocument({
    required this.name,
    required this.sourceType,
    required this.sourcePath,
    required this.content,
    required this.chunks,
  });
}

class PreparedWorkspaceDocumentSource {
  final String name;
  final String sourceType;
  final String sourcePath;

  const PreparedWorkspaceDocumentSource({
    required this.name,
    required this.sourceType,
    required this.sourcePath,
  });
}

class WorkspaceDocumentParser {
  static const _chunkSize = 1200;
  static const _chunkOverlap = 180;

  final TextExtractor _textExtractor = TextExtractor();

  Future<PreparedWorkspaceDocumentSource> prepareSource({
    required String workspaceId,
    required String rawPath,
  }) async {
    final sourcePath = _normalizeFileUriToPath(rawPath.trim());
    if (sourcePath.isEmpty) {
      throw const FormatException('Document path is empty');
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw StateError('File does not exist: $sourcePath');
    }

    final sourceType = detectSourceType(sourcePath);
    final copiedPath = await copyToAppStorage(
      workspaceId: workspaceId,
      sourceFile: sourceFile,
    );

    return PreparedWorkspaceDocumentSource(
      name: copiedPath.uri.pathSegments.last,
      sourceType: sourceType,
      sourcePath: copiedPath.path,
    );
  }

  Future<ParsedWorkspaceDocument> parseStoredSource({
    required String sourcePath,
    required String sourceType,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw StateError('File does not exist: $sourcePath');
    }

    final content = await _extractText(file, sourceType);
    if (content.trim().isEmpty) {
      throw const FormatException('Document has no extractable text content');
    }

    final cleaned = _normalizeText(content);
    final chunks = splitText(cleaned);

    return ParsedWorkspaceDocument(
      name: file.uri.pathSegments.last,
      sourceType: sourceType,
      sourcePath: file.path,
      content: cleaned,
      chunks: chunks,
    );
  }

  Future<ParsedWorkspaceDocument> parseAndCopy({
    required String workspaceId,
    required String rawPath,
  }) async {
    final prepared = await prepareSource(
      workspaceId: workspaceId,
      rawPath: rawPath,
    );
    return parseStoredSource(
      sourcePath: prepared.sourcePath,
      sourceType: prepared.sourceType,
    );
  }

  List<String> splitText(String content) {
    return _splitIntoChunks(_normalizeText(content));
  }

  String detectSourceType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) return 'pdf';
    if (lower.endsWith('.doc')) return 'doc';
    if (lower.endsWith('.docx')) return 'docx';
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) return 'md';
    if (lower.endsWith('.txt') || lower.endsWith('.text')) return 'text';

    throw const FormatException(
      'Only PDF, DOC/DOCX, and text files are supported',
    );
  }

  Future<File> copyToAppStorage({
    required String workspaceId,
    required File sourceFile,
  }) async {
    final appSupportDir = await getApplicationSupportDirectory();
    final targetDir = Directory(
      '${appSupportDir.path}/workspace_docs/$workspaceId',
    );
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final sourceName = sourceFile.uri.pathSegments.isEmpty
        ? 'document'
        : sourceFile.uri.pathSegments.last;
    final safeName = sourceName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final targetPath =
        '${targetDir.path}/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    return sourceFile.copy(targetPath);
  }

  Future<String> _extractText(File file, String sourceType) async {
    if (sourceType == 'pdf' ||
        sourceType == 'doc' ||
        sourceType == 'docx' ||
        sourceType == 'md') {
      final extracted = await _textExtractor.extractText(
        file.path,
        isUrl: false,
      );
      return extracted.text;
    }

    if (sourceType == 'text') {
      final bytes = await file.readAsBytes();
      return utf8.decode(bytes, allowMalformed: true);
    }

    throw const FormatException('Unsupported document type');
  }

  String _normalizeText(String raw) {
    return raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  List<String> _splitIntoChunks(String text) {
    if (text.length <= _chunkSize) {
      return [text];
    }

    final chunks = <String>[];
    var start = 0;

    while (start < text.length) {
      var end = start + _chunkSize;
      if (end >= text.length) {
        chunks.add(text.substring(start).trim());
        break;
      }

      final softBreak = text.lastIndexOf('\n', end);
      if (softBreak > start + 300) {
        end = softBreak;
      }

      chunks.add(text.substring(start, end).trim());
      start = (end - _chunkOverlap).clamp(0, text.length);
    }

    return chunks.where((item) => item.isNotEmpty).toList(growable: false);
  }

  String _normalizeFileUriToPath(String source) {
    if (!source.startsWith('file://')) return source;
    final uri = Uri.tryParse(source);
    if (uri == null || uri.scheme != 'file') return source;
    return uri.toFilePath();
  }
}
