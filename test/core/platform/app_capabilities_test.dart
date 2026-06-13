import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/platform/app_capabilities.dart';

void main() {
  group('AppCapabilities.forPlatform', () {
    test('web supports remote models only', () {
      final capabilities = AppCapabilities.forPlatform(AppPlatform.web);

      expect(capabilities.supportsRemoteModels, isTrue);
      expect(capabilities.supportsLocalModels, isFalse);
      expect(capabilities.supportsWorkspaceRag, isFalse);
    });

    for (final platform in [
      AppPlatform.android,
      AppPlatform.iOS,
      AppPlatform.macOS,
    ]) {
      test('$platform supports remote models, local models, and RAG', () {
        final capabilities = AppCapabilities.forPlatform(platform);

        expect(capabilities.supportsRemoteModels, isTrue);
        expect(capabilities.supportsLocalModels, isTrue);
        expect(capabilities.supportsWorkspaceRag, isTrue);
      });
    }

    for (final platform in [AppPlatform.windows, AppPlatform.linux]) {
      test('$platform remains remote-only', () {
        final capabilities = AppCapabilities.forPlatform(platform);

        expect(capabilities.supportsRemoteModels, isTrue);
        expect(capabilities.supportsLocalModels, isFalse);
        expect(capabilities.supportsWorkspaceRag, isFalse);
      });
    }
  });

  group('capability guards', () {
    final web = AppCapabilities.forPlatform(AppPlatform.web);

    test('local model guard explains that remote models remain available', () {
      expect(
        web.localModelsUnavailableMessage,
        'Local models and workspace RAG are unavailable on web. '
        'Remote models remain available.',
      );
    });

    test('workspace RAG guard uses the actionable unavailable message', () {
      expect(
        web.workspaceRagUnavailableMessage,
        web.localModelsUnavailableMessage,
      );
    });
  });
}
