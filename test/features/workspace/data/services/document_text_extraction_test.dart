import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/workspace/data/services/document_text_extraction.dart';

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  group('DocumentTextExtraction.sourceTypeForExtension', () {
    test('maps csv/tsv/text/code extensions', () {
      expect(DocumentTextExtraction.sourceTypeForExtension('csv'), 'csv');
      expect(DocumentTextExtraction.sourceTypeForExtension('tsv'), 'tsv');
      expect(DocumentTextExtraction.sourceTypeForExtension('txt'), 'text');
      expect(DocumentTextExtraction.sourceTypeForExtension('text'), 'text');
      expect(DocumentTextExtraction.sourceTypeForExtension('dart'), 'code');
      expect(DocumentTextExtraction.sourceTypeForExtension('PY'), 'code');
      expect(DocumentTextExtraction.sourceTypeForExtension('json'), 'code');
      expect(DocumentTextExtraction.sourceTypeForExtension('yaml'), 'code');
    });

    test('returns null for unknown/unsupported extensions', () {
      expect(DocumentTextExtraction.sourceTypeForExtension('pdf'), isNull);
      expect(DocumentTextExtraction.sourceTypeForExtension('exe'), isNull);
      expect(DocumentTextExtraction.sourceTypeForExtension('png'), isNull);
      expect(DocumentTextExtraction.sourceTypeForExtension(''), isNull);
    });
  });

  group('DocumentTextExtraction.extensionOf / fileNameOf', () {
    test('extracts extension from a path', () {
      expect(DocumentTextExtraction.extensionOf('/a/b/data.CSV'), 'csv');
      expect(DocumentTextExtraction.extensionOf('main.dart'), 'dart');
      expect(DocumentTextExtraction.extensionOf('archive.tar.gz'), 'gz');
    });

    test('returns empty for dotfiles and extensionless names', () {
      expect(DocumentTextExtraction.extensionOf('/a/.gitignore'), '');
      expect(DocumentTextExtraction.extensionOf('Makefile'), '');
      expect(DocumentTextExtraction.extensionOf('/a/b/trailingdot.'), '');
    });

    test('extracts file name', () {
      expect(DocumentTextExtraction.fileNameOf('/a/b/main.dart'), 'main.dart');
      expect(DocumentTextExtraction.fileNameOf(r'C:\a\b\x.txt'), 'x.txt');
      expect(DocumentTextExtraction.fileNameOf('plain.txt'), 'plain.txt');
    });
  });

  group('CSV extraction', () {
    test('keeps header and joins cells per row', () {
      final csv = 'name,age,city\nAlice,30,NYC\nBob,25,LA';
      final text = DocumentTextExtraction.extractFromBytes(
        bytes: _bytes(csv),
        sourceType: 'csv',
        fileName: 'people.csv',
      );
      expect(text, 'name,age,city\nAlice,30,NYC\nBob,25,LA');
    });

    test('handles quoted fields with commas inside quotes', () {
      final csv = 'name,note\n"Smith, John","says ""hi"" there"\nDoe,plain';
      final text = DocumentTextExtraction.extractFromBytes(
        bytes: _bytes(csv),
        sourceType: 'csv',
        fileName: 'q.csv',
      );
      final lines = text.split('\n');
      expect(lines[0], 'name,note');
      expect(lines[1], 'Smith, John,says "hi" there');
      expect(lines[2], 'Doe,plain');
    });

    test('handles quoted field spanning a newline', () {
      final csv = 'a,b\n"line1\nline2",x';
      final rows = DocumentTextExtraction.parseDelimited(csv, delimiter: ',');
      expect(rows.length, 2);
      expect(rows[1][0], 'line1\nline2');
      expect(rows[1][1], 'x');
    });

    test('skips fully empty rows', () {
      final csv = 'a,b\n\n1,2\n,\n3,4';
      final text = DocumentTextExtraction.extractFromBytes(
        bytes: _bytes(csv),
        sourceType: 'csv',
        fileName: 'e.csv',
      );
      expect(text, 'a,b\n1,2\n3,4');
    });

    test('handles \\r\\n line endings', () {
      final csv = 'a,b\r\n1,2\r\n3,4';
      final text = DocumentTextExtraction.extractFromBytes(
        bytes: _bytes(csv),
        sourceType: 'csv',
        fileName: 'crlf.csv',
      );
      expect(text, 'a,b\n1,2\n3,4');
    });
  });

  group('TSV extraction', () {
    test('joins cells with tabs and keeps header', () {
      final tsv = 'name\tage\nAlice\t30\nBob\t25';
      final text = DocumentTextExtraction.extractFromBytes(
        bytes: _bytes(tsv),
        sourceType: 'tsv',
        fileName: 'people.tsv',
      );
      expect(text, 'name\tage\nAlice\t30\nBob\t25');
    });
  });

  group('code / text extraction', () {
    test('reads text verbatim without filename prefix', () {
      const content = 'hello world\nsecond line';
      final text = DocumentTextExtraction.extractFromBytes(
        bytes: _bytes(content),
        sourceType: 'text',
        fileName: 'notes.txt',
      );
      expect(text, content);
    });

    test('prefixes code content with the file name', () {
      const content = 'void main() {}\n';
      final text = DocumentTextExtraction.extractFromBytes(
        bytes: _bytes(content),
        sourceType: 'code',
        fileName: 'main.dart',
      );
      expect(text, '# main.dart\n$content');
    });

    test('reads json verbatim (as code) with prefix', () {
      const content = '{"a": 1}';
      final text = DocumentTextExtraction.extractFromBytes(
        bytes: _bytes(content),
        sourceType: 'code',
        fileName: 'config.json',
      );
      expect(text, '# config.json\n$content');
    });

    test('strips a UTF-8 BOM', () {
      final bytes = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode('abc'),
      ]);
      final text = DocumentTextExtraction.extractFromBytes(
        bytes: bytes,
        sourceType: 'text',
        fileName: 'bom.txt',
      );
      expect(text, 'abc');
    });
  });

  group('binary / unknown / empty handling', () {
    test('rejects binary content (NUL byte) as a FormatException', () {
      final bytes = Uint8List.fromList([0x68, 0x00, 0x69]);
      expect(
        () => DocumentTextExtraction.extractFromBytes(
          bytes: bytes,
          sourceType: 'text',
          fileName: 'bad.txt',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown source type', () {
      expect(
        () => DocumentTextExtraction.extractFromBytes(
          bytes: _bytes('x'),
          sourceType: 'pdf',
          fileName: 'x.pdf',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('handles empty file (returns empty string)', () {
      final text = DocumentTextExtraction.extractFromBytes(
        bytes: Uint8List(0),
        sourceType: 'csv',
        fileName: 'empty.csv',
      );
      expect(text, '');
    });
  });

  group('capLength', () {
    test('returns input unchanged when under the cap', () {
      expect(DocumentTextExtraction.capLength('short'), 'short');
    });

    test('trims input above the cap', () {
      final big = 'a' * (DocumentTextExtraction.maxCharacters + 10);
      final capped = DocumentTextExtraction.capLength(big);
      expect(capped.length, DocumentTextExtraction.maxCharacters);
    });
  });
}
