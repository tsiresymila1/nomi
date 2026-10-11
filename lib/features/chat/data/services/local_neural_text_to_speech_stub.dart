import 'dart:async';

import 'package:gena/core/local_ai/local_ai_runtime_coordinator.dart';
import 'package:gena/features/chat/data/models/llamadart_tts_model_profile.dart';
import 'package:gena/features/chat/data/services/llamadart_tts_model_store.dart';
import 'package:gena/features/chat/data/services/local_neural_text_to_speech.dart';
import 'package:gena/features/chat/data/services/text_to_speech.dart';

LocalNeuralTextToSpeech createPlatformLocalNeuralTextToSpeech({
  required LlamaDartTtsModelStore modelStore,
  required LocalAiRuntimeCoordinator coordinator,
  required String? Function() languageCode,
  required LlamaDartTtsModelProfile Function() selectedProfile,
}) => const UnsupportedLocalNeuralTextToSpeech();

class UnsupportedLocalNeuralTextToSpeech implements LocalNeuralTextToSpeech {
  const UnsupportedLocalNeuralTextToSpeech();

  @override
  bool get isAvailable => false;

  @override
  Stream<bool> get speakingChanges => const Stream<bool>.empty();

  Never _unsupported() => throw const TextToSpeechException(
    'LlamaDart text-to-speech is unavailable on this platform.',
  );

  @override
  Future<void> clear() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> enqueue(String text) async => _unsupported();

  @override
  Future<void> prepare() async => _unsupported();

  @override
  Future<void> speak(String text) async => _unsupported();

  @override
  Future<void> stop() async {}

  @override
  Future<void> unload() async {}
}
