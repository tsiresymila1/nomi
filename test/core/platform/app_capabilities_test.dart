import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/platform/app_capabilities.dart';

void main() {
  group('AppCapabilities.forPlatform', () {
    test('web supports remote models and text-to-speech only', () {
      final capabilities = AppCapabilities.forPlatform(AppPlatform.web);

      expect(capabilities.supportsRemoteModels, isTrue);
      expect(capabilities.supportsLocalModels, isFalse);
      expect(capabilities.supportsWorkspaceRag, isFalse);
      expect(capabilities.supportsSpeechToText, isFalse);
      expect(capabilities.supportsTextToSpeech, isTrue);
    });

    test('supportsMcp is true on every platform', () {
      for (final platform in AppPlatform.values) {
        expect(
          AppCapabilities.forPlatform(platform).supportsMcp,
          isTrue,
          reason: 'MCP should be available on $platform',
        );
      }
    });

    for (final platform in [
      AppPlatform.android,
      AppPlatform.iOS,
      AppPlatform.macOS,
    ]) {
      test('$platform supports remote, local, RAG, STT, and TTS', () {
        final capabilities = AppCapabilities.forPlatform(platform);

        expect(capabilities.supportsRemoteModels, isTrue);
        expect(capabilities.supportsLocalModels, isTrue);
        expect(capabilities.supportsWorkspaceRag, isTrue);
        expect(capabilities.supportsSpeechToText, isTrue);
        expect(capabilities.supportsTextToSpeech, isTrue);
      });
    }

    for (final platform in [
      AppPlatform.windows,
      AppPlatform.linux,
      AppPlatform.fuchsia,
    ]) {
      test('$platform remains remote-only without text-to-speech', () {
        final capabilities = AppCapabilities.forPlatform(platform);

        expect(capabilities.supportsRemoteModels, isTrue);
        expect(capabilities.supportsLocalModels, isFalse);
        expect(capabilities.supportsWorkspaceRag, isFalse);
        expect(capabilities.supportsSpeechToText, isFalse);
        expect(capabilities.supportsTextToSpeech, isFalse);
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

    test('persisted RAG is ineffective on unsupported platforms', () {
      expect(web.isWorkspaceRagEnabled(workspaceRagEnabled: true), isFalse);
    });

    test('persisted RAG remains effective on supported platforms', () {
      final android = AppCapabilities.forPlatform(AppPlatform.android);

      expect(android.isWorkspaceRagEnabled(workspaceRagEnabled: true), isTrue);
      expect(
        android.isWorkspaceRagEnabled(workspaceRagEnabled: false),
        isFalse,
      );
    });

    for (final entry in {
      AppPlatform.windows: 'Windows',
      AppPlatform.linux: 'Linux',
    }.entries) {
      test('${entry.key} message names the current platform', () {
        final platform = entry.key;
        final capabilities = AppCapabilities.forPlatform(platform);

        expect(
          capabilities.localModelsUnavailableMessage,
          'Local models and workspace RAG are unavailable on ${entry.value}. '
          'Remote models remain available.',
        );
      });
    }
  });
}
