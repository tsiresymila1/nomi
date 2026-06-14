import 'package:gena/features/chat/data/services/vad_controller.dart';
import 'package:gena/features/chat/presentation/cubit/voice_input_cubit.dart';

/// Returns the recorder cast to a [VoiceLevelSource] when it supports mic-level
/// streaming (the native `record`-backed recorder does), or `null` otherwise
/// (e.g. the web/unsupported recorder). Voice conversation mode is itself gated
/// on `supportsSpeechToText`, so this is null only on platforms where the page
/// is never reachable; the cubit also tolerates a null source.
VoiceLevelSource? voiceLevelSourceFor(VoiceAudioRecorder recorder) {
  return recorder is VoiceLevelSource ? recorder as VoiceLevelSource : null;
}
