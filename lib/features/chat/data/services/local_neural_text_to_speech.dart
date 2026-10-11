import 'package:gena/features/chat/data/services/text_to_speech.dart';

abstract interface class LocalNeuralTextToSpeech implements TextToSpeech {
  Future<void> prepare();

  Future<void> unload();
}
