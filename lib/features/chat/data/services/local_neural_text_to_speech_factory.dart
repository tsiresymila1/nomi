import 'package:gena/core/local_ai/local_ai_runtime_coordinator.dart';
import 'package:gena/features/chat/data/services/llamadart_tts_model_store.dart';
import 'package:gena/features/chat/data/services/local_neural_text_to_speech.dart';
import 'package:gena/features/chat/data/services/local_neural_text_to_speech_stub.dart'
    if (dart.library.io) 'package:gena/features/chat/data/services/local_neural_text_to_speech_io.dart'
    as impl;

LocalNeuralTextToSpeech createLocalNeuralTextToSpeech({
  required LlamaDartTtsModelStore modelStore,
  required LocalAiRuntimeCoordinator coordinator,
  required String? Function() languageCode,
}) => impl.createPlatformLocalNeuralTextToSpeech(
  modelStore: modelStore,
  coordinator: coordinator,
  languageCode: languageCode,
);
