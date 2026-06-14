import 'dart:convert';
import 'dart:typed_data';

/// Pure, testable text extraction for workspace RAG ingestion.
///
/// Given the raw bytes of a file plus its extension/source type, this returns
/// plain text suitable for chunking and embedding. PDF/DOC(X)/Markdown rely on
/// an external extractor and are handled outside this module; everything that
/// can be derived purely from bytes (CSV/TSV and code/plaintext) lives here so
/// it can be unit-tested without `dart:io` or platform plugins.
class DocumentTextExtraction {
  const DocumentTextExtraction._();

  /// Hard cap on the number of characters kept from any single document.
  ///
  /// Larger inputs are trimmed (not rejected) so a huge file never blows up
  /// memory; the resulting text is still chunked downstream by the RAG engine.
  static const int maxCharacters = 2 * 1024 * 1024; // ~2M chars

  /// Source types whose text can be extracted purely from bytes here.
  static const Set<String> pureSourceTypes = {'csv', 'tsv', 'code', 'text'};

  /// Plain-text / code extensions (without leading dot) read verbatim as UTF-8.
  ///
  /// `txt`/`text` map to the `text` source type; everything else here is
  /// treated as `code` (and gets a filename prefix for context).
  static const Map<String, String> _extensionSourceTypes = {
    'txt': 'text',
    'text': 'text',
    'csv': 'csv',
    'tsv': 'tsv',
    // Code / structured plaintext -> 'code'
    'json': 'code',
    'yaml': 'code',
    'yml': 'code',
    'dart': 'code',
    'js': 'code',
    'mjs': 'code',
    'cjs': 'code',
    'ts': 'code',
    'tsx': 'code',
    'jsx': 'code',
    'py': 'code',
    'java': 'code',
    'kt': 'code',
    'kts': 'code',
    'swift': 'code',
    'c': 'code',
    'cc': 'code',
    'cpp': 'code',
    'cxx': 'code',
    'h': 'code',
    'hpp': 'code',
    'go': 'code',
    'rs': 'code',
    'rb': 'code',
    'php': 'code',
    'sh': 'code',
    'bash': 'code',
    'zsh': 'code',
    'sql': 'code',
    'html': 'code',
    'htm': 'code',
    'css': 'code',
    'scss': 'code',
    'xml': 'code',
    'toml': 'code',
    'ini': 'code',
  };

  /// All extensions (without leading dot) handled purely by this module.
  static List<String> get supportedPureExtensions =>
      _extensionSourceTypes.keys.toList(growable: false);

  /// Maps a lowercase extension (without dot) to the source type used by the
  /// parser, or `null` when the extension is not one this module handles.
  ///
  /// PDF/DOC(X)/Markdown are intentionally excluded here; the parser routes
  /// those to the external extractor.
  static String? sourceTypeForExtension(String extension) {
    return _extensionSourceTypes[extension.toLowerCase()];
  }

  /// Returns the lowercase extension (without dot) for [path], or empty string.
  static String extensionOf(String path) {
    final lastSlash = path.lastIndexOf(RegExp(r'[\\/]'));
    final name = lastSlash >= 0 ? path.substring(lastSlash + 1) : path;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  /// Returns the final path segment (file name) of [path].
  static String fileNameOf(String path) {
    final lastSlash = path.lastIndexOf(RegExp(r'[\\/]'));
    return lastSlash >= 0 ? path.substring(lastSlash + 1) : path;
  }

  /// Extracts plain text from [bytes] for a [sourceType] handled by this module
  /// (one of [pureSourceTypes]). [fileName] is used to prefix `code` content for
  /// retrieval context.
  ///
  /// Throws [FormatException] when [sourceType] is not a pure type, or when the
  /// bytes appear to be binary (non-UTF-8 / contains NUL bytes).
  static String extractFromBytes({
    required Uint8List bytes,
    required String sourceType,
    required String fileName,
  }) {
    switch (sourceType) {
      case 'csv':
        return _extractCsv(_decodeText(bytes), delimiter: ',');
      case 'tsv':
        return _extractCsv(_decodeText(bytes), delimiter: '\t');
      case 'code':
        final text = _decodeText(bytes);
        final trimmedName = fileName.trim();
        if (trimmedName.isEmpty) return text;
        return '# $trimmedName\n$text';
      case 'text':
        return _decodeText(bytes);
      default:
        throw FormatException(
          'Unsupported source type for byte extraction: $sourceType',
        );
    }
  }

  /// Decodes [bytes] as UTF-8, rejecting content that looks binary.
  static String _decodeText(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    // Reject obvious binary content: a NUL byte almost never appears in text.
    if (bytes.contains(0)) {
      throw const FormatException(
        'File appears to be binary and cannot be read as text',
      );
    }
    // Strip a UTF-8 BOM if present.
    var data = bytes;
    if (data.length >= 3 &&
        data[0] == 0xEF &&
        data[1] == 0xBB &&
        data[2] == 0xBF) {
      data = Uint8List.sublistView(data, 3);
    }
    return utf8.decode(data, allowMalformed: true);
  }

  /// Parses delimited text into one readable line per row, joining cells with
  /// the delimiter. Handles RFC-4180 style quoting: quoted fields may contain
  /// the delimiter, newlines, and escaped quotes (`""`). The header row is kept
  /// as-is (it is just the first row).
  static String _extractCsv(String raw, {required String delimiter}) {
    final rows = parseDelimited(raw, delimiter: delimiter);
    final lines = <String>[];
    for (final row in rows) {
      // Skip fully empty rows.
      if (row.every((cell) => cell.trim().isEmpty)) continue;
      lines.add(row.map((cell) => cell.trim()).join(delimiter));
    }
    return lines.join('\n');
  }

  /// Splits delimited text into a list of rows, each a list of cell strings.
  ///
  /// Quoted fields (`"..."`) may span the [delimiter], `\n`, `\r`, and contain
  /// escaped quotes written as `""`.
  static List<List<String>> parseDelimited(
    String input, {
    required String delimiter,
  }) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    final delimChar = delimiter.codeUnitAt(0);
    var inQuotes = false;
    var sawAnyChar = false;

    void endField() {
      row.add(field.toString());
      field.clear();
    }

    void endRow() {
      endField();
      rows.add(row);
      row = <String>[];
    }

    final units = input.codeUnits;
    for (var i = 0; i < units.length; i++) {
      final c = units[i];
      sawAnyChar = true;
      if (inQuotes) {
        if (c == 0x22) {
          // double quote
          if (i + 1 < units.length && units[i + 1] == 0x22) {
            field.writeCharCode(0x22);
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.writeCharCode(c);
        }
        continue;
      }

      if (c == 0x22) {
        inQuotes = true;
      } else if (c == delimChar) {
        endField();
      } else if (c == 0x0A) {
        // \n
        endRow();
      } else if (c == 0x0D) {
        // \r — handle \r and \r\n as a single row break
        endRow();
        if (i + 1 < units.length && units[i + 1] == 0x0A) {
          i++;
        }
      } else {
        field.writeCharCode(c);
      }
    }

    // Flush the trailing field/row if any content was seen since the last break.
    if (field.isNotEmpty || row.isNotEmpty) {
      endRow();
    } else if (sawAnyChar && rows.isEmpty) {
      endRow();
    }

    return rows;
  }

  /// Trims [text] to [maxCharacters] (on a code-unit boundary) when oversized.
  static String capLength(String text) {
    if (text.length <= maxCharacters) return text;
    return text.substring(0, maxCharacters);
  }
}
