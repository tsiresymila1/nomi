import 'package:gena/features/chat/presentation/cubit/voice_input_cubit.dart';
// Selects the native `record`-backed recorder where dart:io is available, and
// an unsupported recorder on web.
import 'unsupported_audio_recorder.dart'
    if (dart.library.io) 'native_audio_recorder.dart'
    as impl;

/// Returns the microphone recorder for the current platform.
VoiceAudioRecorder createVoiceAudioRecorder() =>
    impl.createVoiceAudioRecorder();
