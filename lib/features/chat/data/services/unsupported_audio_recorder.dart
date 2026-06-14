import 'package:gena/features/chat/presentation/cubit/voice_input_cubit.dart';
import 'speech_to_text.dart';

/// Builds the unsupported-platform recorder (e.g. web). Imports neither
/// `record` nor `dart:io`.
VoiceAudioRecorder createVoiceAudioRecorder() =>
    const _UnsupportedAudioRecorder();

class _UnsupportedAudioRecorder implements VoiceAudioRecorder {
  const _UnsupportedAudioRecorder();

  static const _message = 'Voice input is unavailable on this platform.';

  @override
  Future<void> start() => throw const SpeechToTextException(_message);

  @override
  Future<String?> stop() => throw const SpeechToTextException(_message);

  @override
  Future<void> cancel() async {}
}
