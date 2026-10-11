import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/models/llamadart_tts_model_profile.dart';
import 'package:gena/features/chat/data/services/llamadart_tts_model_store.dart';
import 'package:gena/features/chat/data/services/local_neural_text_to_speech.dart';
import 'package:gena/features/chat/presentation/cubit/llamadart_tts_model_cubit.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../../support/in_memory_hydrated_storage.dart';

void main() {
  setUp(() {
    HydratedBloc.storage = InMemoryHydratedStorage();
  });

  test('installs and preloads the neural voice runtime', () async {
    final store = _FakeStore();
    final tts = _FakeLocalTextToSpeech();
    final cubit = LlamaDartTtsModelCubit(store: store, textToSpeech: tts);
    addTearDown(cubit.close);

    await cubit.initialize();
    expect(cubit.state.phase, LlamaDartTtsModelPhase.idle);

    await cubit.install();
    expect(store.installed, isTrue);
    expect(tts.prepareCount, 1);
    expect(cubit.state.phase, LlamaDartTtsModelPhase.ready);
  });

  test('persists and preloads a custom Qwen3-TTS pair', () async {
    final store = _FakeStore();
    final tts = _FakeLocalTextToSpeech();
    final cubit = LlamaDartTtsModelCubit(store: store, textToSpeech: tts);
    addTearDown(cubit.close);

    final profile = await cubit.registerExternal(
      name: 'Custom Qwen3-TTS',
      modelPath: '/custom/model.gguf',
      modelSizeBytes: 10,
      projectorPath: '/custom/mmproj.gguf',
      projectorSizeBytes: 5,
    );

    expect(cubit.state.profile, profile);
    expect(cubit.state.customProfiles, <LlamaDartTtsModelProfile>[profile]);
    expect(cubit.state.phase, LlamaDartTtsModelPhase.ready);
    expect(tts.prepareCount, 1);
    final restored = cubit.fromJson(cubit.toJson(cubit.state)!)!;
    expect(restored.profile, profile);
  });
}

class _FakeStore implements LlamaDartTtsModelStore {
  bool installed = false;

  @override
  bool get isSupported => true;

  InstalledLlamaDartTtsModel _model(LlamaDartTtsModelProfile profile) =>
      InstalledLlamaDartTtsModel(
        profile: profile,
        modelPath: '/model.gguf',
        projectorPath: '/mmproj.gguf',
      );

  @override
  Future<void> cancelInstall(LlamaDartTtsModelProfile profile) async {}

  @override
  Future<void> delete(LlamaDartTtsModelProfile profile) async {
    installed = false;
  }

  @override
  Future<InstalledLlamaDartTtsModel> install(
    LlamaDartTtsModelProfile profile, {
    required void Function(double progress, String message) onProgress,
    required void Function(String message) onVerifying,
  }) async {
    onProgress(0.5, 'Downloading');
    onVerifying('Verifying');
    installed = true;
    return _model(profile);
  }

  @override
  Future<InstalledLlamaDartTtsModel?> resolve(
    LlamaDartTtsModelProfile profile,
  ) async => installed || profile.isExternal ? _model(profile) : null;
}

class _FakeLocalTextToSpeech implements LocalNeuralTextToSpeech {
  int prepareCount = 0;

  @override
  bool get isAvailable => true;

  @override
  Stream<bool> get speakingChanges => const Stream<bool>.empty();

  @override
  Future<void> clear() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> enqueue(String text) async {}

  @override
  Future<void> prepare() async => prepareCount++;

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> unload() async {}
}
