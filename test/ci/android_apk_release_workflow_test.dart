import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String workflow;

  setUpAll(() {
    workflow = File(
      '.github/workflows/android-apk-release.yml',
    ).readAsStringSync();
  });

  test('builds an APK after every push or merge to main', () {
    expect(workflow, contains('push:\n    branches:\n      - main'));
    expect(workflow, isNot(contains('cancel-in-progress: true')));
  });

  test(
    'uses the project Flutter version and an Android arm64 release build',
    () {
      expect(workflow, contains('flutter-version: "3.41.9"'));
      expect(
        workflow,
        contains('flutter build apk --release --target-platform android-arm64'),
      );
    },
  );

  test('uploads the APK without embedding the CI Hugging Face secret', () {
    expect(workflow, contains('uses: actions/upload-artifact@v4'));
    expect(workflow, isNot(contains(r'secrets.HUGGING_FACE_TOKEN')));
  });
}
