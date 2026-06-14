import 'package:gena/features/chat/presentation/cubit/voice_input_cubit.dart';
import 'audio_recorder_service.dart';

/// Builds the native `record`-backed recorder.
VoiceAudioRecorder createVoiceAudioRecorder() => AudioRecorderService();
