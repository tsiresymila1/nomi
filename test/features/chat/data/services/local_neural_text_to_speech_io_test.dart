import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/local_ai/local_ai_runtime_coordinator.dart';
import 'package:gena/features/chat/data/models/llamadart_tts_model_profile.dart';
import 'package:gena/features/chat/data/services/llamadart_tts_model_store.dart';
import 'package:gena/features/chat/data/services/local_neural_text_to_speech_io.dart';

void main() {
  test('does not initialize native audio before playback', () async {
    var factoryCalls = 0;
    final coordinator = LocalAiRuntimeCoordinator(
      requiresExclusiveAccess: () async => true,
    );
    final textToSpeech = LlamaDartTextToSpeech(
      modelStore: _ModelStoreFake(),
      coordinator: coordinator,
      languageCode: () => 'fr',
      selectedProfile: () => qwen3Tts17bQ4,
      audioPlayerFactory: () {
        factoryCalls++;
        throw StateError('Audio player should stay lazy.');
      },
    );

    await textToSpeech.clear();
    await textToSpeech.dispose();
    await coordinator.close();

    expect(factoryCalls, isZero);
  });
}

class _ModelStoreFake implements LlamaDartTtsModelStore {
  @override
  bool get isSupported => true;

  @override
  Future<void> cancelInstall(LlamaDartTtsModelProfile profile) async {}

  @override
  Future<void> delete(LlamaDartTtsModelProfile profile) async {}

  @override
  Future<InstalledLlamaDartTtsModel> install(
    LlamaDartTtsModelProfile profile, {
    required void Function(double progress, String message) onProgress,
    required void Function(String message) onVerifying,
  }) => throw UnimplementedError();

  @override
  Future<InstalledLlamaDartTtsModel?> resolve(
    LlamaDartTtsModelProfile profile,
  ) async => null;
}
