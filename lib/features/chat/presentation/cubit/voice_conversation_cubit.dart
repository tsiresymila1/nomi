import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:gena/features/chat/data/services/speech_to_text.dart';
import 'package:gena/features/chat/data/services/text_to_speech.dart';
import 'package:gena/features/chat/data/services/vad_controller.dart';
import 'package:gena/features/chat/presentation/cubit/text_to_speak.dart';
import 'package:gena/features/chat/presentation/cubit/voice_input_cubit.dart';

/// The phase of the hands-free conversation loop.
enum VoiceConversationPhase {
  /// Not running (entered/exited).
  idle,

  /// Recorder active; waiting for the user to finish speaking.
  listening,

  /// Recorder stopped; running on-device transcription.
  transcribing,

  /// Message sent; waiting for the assistant reply to finish generating.
  thinking,

  /// Speaking the assistant reply aloud.
  speaking,
}

/// Immutable state emitted by [VoiceConversationCubit].
class VoiceConversationState {
  const VoiceConversationState({
    this.phase = VoiceConversationPhase.idle,
    this.partialTranscript = '',
    this.micLevel = 0.0,
  });

  /// Current loop phase.
  final VoiceConversationPhase phase;

  /// The most recent transcript (shown while/after transcribing).
  final String partialTranscript;

  /// Normalised 0..1 mic loudness, for animating the orb while listening.
  final double micLevel;

  bool get isListening => phase == VoiceConversationPhase.listening;
  bool get isSpeaking => phase == VoiceConversationPhase.speaking;
  bool get isThinking => phase == VoiceConversationPhase.thinking;
  bool get isTranscribing => phase == VoiceConversationPhase.transcribing;
  bool get isActive => phase != VoiceConversationPhase.idle;

  VoiceConversationState copyWith({
    VoiceConversationPhase? phase,
    String? partialTranscript,
    double? micLevel,
  }) {
    return VoiceConversationState(
      phase: phase ?? this.phase,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      micLevel: micLevel ?? this.micLevel,
    );
  }
}

/// Orchestrates a continuous, hands-free voice conversation by composing the
/// existing on-device pieces — the recorder + VAD, Whisper STT, the normal chat
/// send/generate path, and flutter_tts — into one strictly sequential loop:
///
/// ```
/// listening → (VAD stop) → transcribing → (blank → listening)
///   → send + thinking → (reply finished) → speaking → listening → …
/// ```
///
/// Strictly sequential: the recorder and TTS never run at the same time (no
/// full-duplex, to avoid the mic picking up TTS output). Tapping during
/// `speaking` barges in (cancels TTS → listening); tapping during `listening`
/// stops the current turn now. [exit] tears everything down and returns to
/// `idle`.
///
/// Errors never crash the loop: STT/generation failures return to listening; a
/// TTS failure skips speaking and returns to listening.
class VoiceConversationCubit extends Cubit<VoiceConversationState> {
  VoiceConversationCubit({
    required VoiceAudioRecorder recorder,
    required SpeechToText speechToText,
    required TextToSpeech textToSpeech,
    required VadController vad,
    required Future<void> Function(String text) sendMessage,
    required GenerationSignal generationSignal,
    VoiceLevelSource? levelSource,
    void Function(String message)? onError,
  }) : _recorder = recorder,
       _speechToText = speechToText,
       _textToSpeech = textToSpeech,
       _vad = vad,
       _sendMessage = sendMessage,
       _generationSignal = generationSignal,
       _levelSource = levelSource,
       _onError = onError,
       super(const VoiceConversationState());

  final VoiceAudioRecorder _recorder;
  final SpeechToText _speechToText;
  final TextToSpeech _textToSpeech;
  final VadController _vad;
  final Future<void> Function(String text) _sendMessage;
  final GenerationSignal _generationSignal;
  final VoiceLevelSource? _levelSource;
  final void Function(String message)? _onError;

  StreamSubscription<MicLevel>? _levelSubscription;
  StreamSubscription<bool>? _speakingSubscription;

  /// Bumped on every [exit] (and re-entry) so a phase that was in flight when
  /// the user exits does not resume the loop afterwards.
  int _runToken = 0;

  bool _running(int token) => token == _runToken && !isClosed;

  /// Enters voice mode and starts the first listen turn. No-op if already
  /// running.
  Future<void> enter() async {
    if (state.isActive) return;
    _runToken++;
    await _startListening(_runToken);
  }

  /// Handles a tap on the orb: stop-listening-now during listening, or barge-in
  /// (cancel TTS) during speaking.
  Future<void> onTap() async {
    switch (state.phase) {
      case VoiceConversationPhase.listening:
        await _stopListeningAndContinue(_runToken);
      case VoiceConversationPhase.speaking:
        await _bargeIn(_runToken);
      case VoiceConversationPhase.idle:
      case VoiceConversationPhase.transcribing:
      case VoiceConversationPhase.thinking:
        // Nothing actionable mid-transcribe/think.
        break;
    }
  }

  // -- Phase: listening ------------------------------------------------------

  Future<void> _startListening(int token) async {
    if (!_running(token)) return;
    await _detachLevel();
    _vad.reset();

    try {
      await _recorder.start();
    } catch (error) {
      _reportError(error);
      await _exitInternal();
      return;
    }
    if (!_running(token)) {
      await _safeCancelRecorder();
      return;
    }

    emit(
      state.copyWith(
        phase: VoiceConversationPhase.listening,
        partialTranscript: '',
        micLevel: 0.0,
      ),
    );

    _vad.start(
      source: _levelSource,
      onStop: (_) => unawaited(_stopListeningAndContinue(token)),
    );

    final source = _levelSource;
    if (source != null) {
      _levelSubscription = source
          .levelStream(const Duration(milliseconds: 150))
          .listen((level) {
            if (!_running(token) || !state.isListening) return;
            emit(state.copyWith(micLevel: level.normalized()));
          }, onError: (_) {});
    }
  }

  bool _transitioningFromListening = false;

  Future<void> _stopListeningAndContinue(int token) async {
    if (!_running(token) || !state.isListening) return;
    if (_transitioningFromListening) return;
    _transitioningFromListening = true;
    try {
      final hadSpeech = _vad.hasDetectedSpeech;
      _vad.reset();
      await _detachLevel();

      String? wavPath;
      try {
        wavPath = await _recorder.stop();
      } catch (error) {
        _reportError(error);
        await _restartListening(token);
        return;
      }

      // No audio captured, or nothing above the speech threshold was heard:
      // keep listening without sending.
      if (wavPath == null || !hadSpeech) {
        await _restartListening(token);
        return;
      }

      await _transcribeAndSend(token, wavPath);
    } finally {
      _transitioningFromListening = false;
    }
  }

  // -- Phase: transcribing ---------------------------------------------------

  Future<void> _transcribeAndSend(int token, String wavPath) async {
    if (!_running(token)) return;
    emit(state.copyWith(phase: VoiceConversationPhase.transcribing));

    String transcript;
    try {
      final result = await _speechToText.transcribe(wavPath);
      transcript = result.text.trim();
    } catch (error) {
      _reportError(error);
      await _restartListening(token);
      return;
    }
    if (!_running(token)) return;

    // Blank transcript -> back to listening, no send.
    if (transcript.isEmpty) {
      await _restartListening(token);
      return;
    }

    emit(state.copyWith(partialTranscript: transcript));
    await _sendAndAwaitReply(token, transcript);
  }

  // -- Phase: thinking -------------------------------------------------------

  Future<void> _sendAndAwaitReply(int token, String text) async {
    if (!_running(token)) return;
    emit(state.copyWith(phase: VoiceConversationPhase.thinking));

    String? reply;
    try {
      reply = await _generationSignal.run(() => _sendMessage(text));
    } catch (error) {
      _reportError(error);
      await _restartListening(token);
      return;
    }
    if (!_running(token)) return;

    final spoken = stripMarkdownForSpeech(reply ?? '');
    if (spoken.isEmpty) {
      // Nothing to say (e.g. send was a no-op) — keep the conversation going.
      await _restartListening(token);
      return;
    }

    await _speak(token, spoken);
  }

  // -- Phase: speaking -------------------------------------------------------

  Future<void> _speak(int token, String text) async {
    if (!_running(token)) return;

    if (!_textToSpeech.isAvailable) {
      // TTS unavailable: skip speaking, keep looping.
      await _restartListening(token);
      return;
    }

    emit(state.copyWith(phase: VoiceConversationPhase.speaking));

    // Return to listening when the utterance ends (completion/cancel/error).
    await _speakingSubscription?.cancel();
    _speakingSubscription = _textToSpeech.speakingChanges.listen((speaking) {
      if (speaking) return;
      if (!_running(token) || state.phase != VoiceConversationPhase.speaking) {
        return;
      }
      unawaited(_speakingSubscription?.cancel());
      _speakingSubscription = null;
      unawaited(_restartListening(token));
    });

    try {
      await _textToSpeech.speak(text);
    } catch (error) {
      _reportError(error);
      await _speakingSubscription?.cancel();
      _speakingSubscription = null;
      await _restartListening(token);
    }
  }

  Future<void> _bargeIn(int token) async {
    if (!_running(token) || !state.isSpeaking) return;
    await _speakingSubscription?.cancel();
    _speakingSubscription = null;
    try {
      await _textToSpeech.stop();
    } catch (_) {
      // Stopping is best-effort.
    }
    await _restartListening(token);
  }

  // -- Loop helper -----------------------------------------------------------

  Future<void> _restartListening(int token) async {
    if (!_running(token)) return;
    await _startListening(token);
  }

  // -- Exit / teardown -------------------------------------------------------

  /// Exits voice mode: stops the recorder + TTS, abandons any in-flight phase,
  /// and returns to idle.
  Future<void> exit() => _exitInternal();

  Future<void> _exitInternal() async {
    _runToken++; // invalidate any in-flight phase
    _transitioningFromListening = false;
    _vad.reset();
    await _detachLevel();
    await _speakingSubscription?.cancel();
    _speakingSubscription = null;
    await _safeCancelRecorder();
    try {
      await _textToSpeech.stop();
    } catch (_) {
      // best-effort
    }
    if (!isClosed) emit(const VoiceConversationState());
  }

  Future<void> _detachLevel() async {
    await _levelSubscription?.cancel();
    _levelSubscription = null;
  }

  Future<void> _safeCancelRecorder() async {
    try {
      await _recorder.cancel();
    } catch (_) {
      // Cancelling is best-effort.
    }
  }

  void _reportError(Object error) {
    final message = switch (error) {
      SpeechToTextException() => error.message,
      TextToSpeechException() => error.message,
      _ => 'Voice conversation failed: $error',
    };
    _onError?.call(message);
  }

  @override
  Future<void> close() async {
    await _exitInternal();
    _vad.dispose();
    return super.close();
  }
}

/// Bridges the chat generation lifecycle so the cubit can wait for a reply to
/// finish and read its final text without depending on the chat cubits'
/// internals. [run] starts the send (via the supplied action), waits until
/// generation completes, and returns the final assistant text (or `null` if
/// none was produced).
abstract interface class GenerationSignal {
  Future<String?> run(Future<void> Function() send);
}
