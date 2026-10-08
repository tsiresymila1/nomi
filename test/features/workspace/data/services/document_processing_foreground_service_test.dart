import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/workspace/data/services/document_processing_foreground_service.dart';

void main() {
  test('large documents require Android foreground processing', () {
    expect(
      requiresDocumentProcessingForeground(
        platform: 'android',
        sizeBytes: 8 * 1024 * 1024,
      ),
      isTrue,
    );
  });

  test('small Android and non-Android documents stay in-process', () {
    expect(
      requiresDocumentProcessingForeground(
        platform: 'android',
        sizeBytes: 8 * 1024 * 1024 - 1,
      ),
      isFalse,
    );
    expect(
      requiresDocumentProcessingForeground(
        platform: 'ios',
        sizeBytes: 100 * 1024 * 1024,
      ),
      isFalse,
    );
  });
}
