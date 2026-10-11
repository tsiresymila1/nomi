import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/workspace/data/services/document_processing_foreground_service.dart';

void main() {
  test('all Android documents use foreground processing', () {
    expect(
      requiresDocumentProcessingForeground(
        platform: 'android',
        sizeBytes: 8 * 1024 * 1024,
      ),
      isTrue,
    );
    expect(
      requiresDocumentProcessingForeground(platform: 'android', sizeBytes: 1),
      isTrue,
    );
  });

  test('non-Android documents stay in-process', () {
    expect(
      requiresDocumentProcessingForeground(
        platform: 'ios',
        sizeBytes: 100 * 1024 * 1024,
      ),
      isFalse,
    );
  });
}
