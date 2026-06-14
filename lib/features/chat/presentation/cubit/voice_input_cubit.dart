import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:gena/features/chat/data/services/speech_to_text.dart';
import 'package:gena/features/chat/presentation/cubit/chat_input_cubit.dart';

/// Minimal audio-recorder seam the [VoiceInputCubit] drives. The native
/// `AudioRecorderService` (which wraps the `record` plugin) satisfies this, but
/// the cubit depends only on this interface so the record→transcribe flow is
/// testable with a fake and web builds never pull in `record`.
abstract interface class VoiceAudioRecorder {
  Future<void> start();
  Future<String?> stop();
  Future<void> cancel();
}

enum VoiceInputStatus { idle, recording, transcribing }

class VoiceInputState {
  const VoiceInputState({this.status = VoiceInputStatus.idle});

  final VoiceInputStatus status;

  bool get isRecording => status == VoiceInputStatus.recording;
  bool get isTranscribing => status == VoiceInputStatus.transcribing;
  bool get isBusy => isRecording || isTranscribing;

  VoiceInputState copyWith({VoiceInputStatus? status}) {
    return VoiceInputState(status: status ?? this.status);
  }
}

/// Drives the hold-to-record voice-input flow: start recording, then on release
/// stop the recorder, transcribe the WAV on-device, and append the transcript
/// to the chat input draft. A cancel gesture discards the recording.
///
/// Errors are surfaced through [onError] (so the widget can toast) and never
/// clear the existing draft.
class VoiceInputCubit extends Cubit<VoiceInputState> {
  VoiceInputCubit({
    required VoiceAudioRecorder recorder,
    required SpeechToText speechToText,
    required ChatInputCubit chatInputCubit,
    void Function(String message)? onError,
  }) : _recorder = recorder,
       _speechToText = speechToText,
       _chatInputCubit = chatInputCubit,
       _onError = onError,
       super(const VoiceInputState());

  final VoiceAudioRecorder _recorder;
  final SpeechToText _speechToText;
  final ChatInputCubit _chatInputCubit;
  final void Function(String message)? _onError;

  /// Begins recording. No-op if already recording or transcribing.
  Future<void> startRecording() async {
    if (state.isBusy) return;
    try {
      await _recorder.start();
      emit(state.copyWith(status: VoiceInputStatus.recording));
    } catch (error) {
      emit(const VoiceInputState());
      _reportError(error);
    }
  }

  /// Stops recording, transcribes the audio, and appends the transcript to the
  /// chat input draft. No-op unless currently recording.
  Future<void> stopAndTranscribe() async {
    if (!state.isRecording) return;

    String? wavPath;
    try {
      wavPath = await _recorder.stop();
    } catch (error) {
      emit(const VoiceInputState());
      _reportError(error);
      return;
    }

    if (wavPath == null) {
      emit(const VoiceInputState());
      return;
    }

    emit(state.copyWith(status: VoiceInputStatus.transcribing));
    try {
      final result = await _speechToText.transcribe(wavPath);
      if (result.text.isNotEmpty) {
        _chatInputCubit.appendText(result.text);
      }
    } catch (error) {
      _reportError(error);
    } finally {
      emit(const VoiceInputState());
    }
  }

  /// Discards the active recording without transcribing.
  Future<void> cancelRecording() async {
    if (!state.isRecording) return;
    try {
      await _recorder.cancel();
    } catch (_) {
      // Cancelling is best-effort; ignore failures.
    } finally {
      emit(const VoiceInputState());
    }
  }

  void _reportError(Object error) {
    final message = error is SpeechToTextException
        ? error.message
        : 'Voice input failed: $error';
    _onError?.call(message);
  }
}
