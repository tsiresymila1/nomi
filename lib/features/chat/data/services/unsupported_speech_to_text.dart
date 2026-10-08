import 'package:gena/features/chat/data/models/whisper_model_profile.dart';

import 'speech_to_text.dart';
import 'whisper_model_provisioner.dart';

/// Builds the unsupported-platform speech-to-text driver (e.g. web).
SpeechToText createSpeechToText({
  required WhisperProvisioner provisioner,
  required WhisperModelProfile Function() selectedProfile,
}) => UnsupportedSpeechToText();

/// Rejects all speech-to-text requests. Used on platforms without native
/// whisper support, such as web. Imports neither whisper_ggml_plus nor record
/// so those plugins never reach a web build.
class UnsupportedSpeechToText implements SpeechToText {
  static const _message = 'Voice input is unavailable on this platform.';

  @override
  bool get isAvailable => false;

  @override
  Future<void> ensureModelReady() {
    throw const SpeechToTextException(_message);
  }

  @override
  Future<SttResult> transcribe(String wavPath, {String lang = 'auto'}) {
    throw const SpeechToTextException(_message);
  }
}
