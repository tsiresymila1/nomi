import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:gena/features/chat/data/services/text_to_speech.dart';
import 'package:gena/features/chat/presentation/cubit/text_to_speak.dart';

/// State for the read-aloud feature: which assistant message is currently being
/// spoken (if any) and whether playback is active.
class VoiceOutputState {
  const VoiceOutputState({this.speakingMessageId, this.isSpeaking = false});

  /// The id of the message currently being spoken, or `null` when idle.
  final String? speakingMessageId;

  /// Whether an utterance is currently playing.
  final bool isSpeaking;

  bool isSpeakingMessage(String messageId) =>
      isSpeaking && speakingMessageId == messageId;

  VoiceOutputState copyWith({String? speakingMessageId, bool? isSpeaking}) {
    return VoiceOutputState(
      speakingMessageId: speakingMessageId,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }
}

/// Drives reading assistant replies aloud through a [TextToSpeech] engine.
///
/// [toggle] starts speaking a message (stopping any other in-progress one), or
/// stops it if that same message is already speaking. The cubit listens to
/// [TextToSpeech.speakingChanges] so state clears when playback completes,
/// is cancelled, or errors. Message text is stripped of markdown before being
/// handed to the engine so formatting characters are not read aloud.
class VoiceOutputCubit extends Cubit<VoiceOutputState> {
  VoiceOutputCubit({
    required TextToSpeech textToSpeech,
    void Function(String message)? onError,
  }) : _textToSpeech = textToSpeech,
       _onError = onError,
       super(const VoiceOutputState()) {
    _speakingSubscription = _textToSpeech.speakingChanges.listen(
      _onSpeakingChanged,
    );
  }

  final TextToSpeech _textToSpeech;
  final void Function(String message)? _onError;
  late final StreamSubscription<bool> _speakingSubscription;

  /// Speaks [text] for [messageId], or stops if that message is already
  /// speaking. Switching to a different message stops the previous one.
  Future<void> toggle(String messageId, String text) async {
    if (state.isSpeakingMessage(messageId)) {
      await stop();
      return;
    }

    final plainText = stripMarkdownForSpeech(text);
    if (plainText.isEmpty) return;

    // Reflect the new target immediately; the start handler will confirm.
    emit(VoiceOutputState(speakingMessageId: messageId, isSpeaking: true));
    try {
      await _textToSpeech.speak(plainText);
    } catch (error) {
      emit(const VoiceOutputState());
      _reportError(error);
    }
  }

  /// Stops any in-progress playback and clears state.
  Future<void> stop() async {
    if (state.speakingMessageId == null && !state.isSpeaking) return;
    emit(const VoiceOutputState());
    try {
      await _textToSpeech.stop();
    } catch (_) {
      // Stopping is best-effort.
    }
  }

  void _onSpeakingChanged(bool speaking) {
    if (isClosed) return;
    if (!speaking) {
      emit(const VoiceOutputState());
    }
  }

  void _reportError(Object error) {
    final message = error is TextToSpeechException
        ? error.message
        : 'Voice output failed: $error';
    _onError?.call(message);
  }

  @override
  Future<void> close() async {
    await _speakingSubscription.cancel();
    return super.close();
  }
}
