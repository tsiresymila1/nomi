import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:gena/features/chat/data/services/pcm_wav.dart';
import 'package:gena/features/chat/data/services/speech_segmenter.dart';
import 'package:gena/features/chat/data/services/speech_to_text.dart';
import 'package:gena/features/chat/data/services/text_to_speech.dart';
import 'package:gena/features/chat/presentation/cubit/sentence_chunker.dart';

/// The phase of the hands-free conversation loop.
enum VoiceConversationPhase {
  /// Not running (entered/exited).
  idle,

  /// Microphone + neural VAD active; waiting for the user to finish an
  /// utterance (or to tap to end the turn).
  listening,

  /// Segment captured; running on-device transcription.
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

  /// Normalised 0..1 speech probability, for animating the orb while listening.
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
/// on-device pieces — a neural Silero-VAD [SpeechSegmenter], Whisper STT, the
/// normal chat send/generate path, and flutter_tts — into one strictly
/// sequential loop:
///
/// ```
/// listening → (segment) → transcribing → (blank → listening)
///   → send + thinking → (reply finished) → speaking → listening → …
/// ```
///
/// Strictly sequential: the microphone and TTS never run at the same time. The
/// segmenter is paused/stopped before transcribing/thinking/speaking so it never
/// captures the assistant's own speech (no full-duplex). Tapping during
/// `speaking` barges in (cancels TTS → listening); tapping during `listening`
/// ends the current turn now. [exit] tears everything down and returns to
/// `idle`.
///
/// Errors never crash the loop: STT/generation failures return to listening; a
/// TTS failure skips speaking and returns to listening.
class VoiceConversationCubit extends Cubit<VoiceConversationState> {
  VoiceConversationCubit({
    required SpeechSegmenter segmenter,
    required SpeechToText speechToText,
    required TextToSpeech textToSpeech,
    required Future<void> Function(String text) sendMessage,
    required GenerationSignal generationSignal,
    void Function(String message)? onError,
    Future<String> Function(SpeechSegment segment)? writeWav,
  }) : _segmenter = segmenter,
       _speechToText = speechToText,
       _textToSpeech = textToSpeech,
       _sendMessage = sendMessage,
       _generationSignal = generationSignal,
       _onError = onError,
       _writeWav =
           writeWav ??
           ((segment) =>
               writePcm16Wav(segment.pcm16, sampleRate: segment.sampleRate)),
       super(const VoiceConversationState());

  final SpeechSegmenter _segmenter;
  final SpeechToText _speechToText;
  final TextToSpeech _textToSpeech;
  final Future<void> Function(String text) _sendMessage;
  final GenerationSignal _generationSignal;
  final void Function(String message)? _onError;

  /// Writes a captured segment to a temporary WAV and returns its path.
  /// Injectable so the loop is testable without touching the filesystem.
  final Future<String> Function(SpeechSegment segment) _writeWav;

  /// Splits the streaming reply into sentences so TTS can start speaking the
  /// first sentence before the whole reply is generated. Reset per reply.
  final SentenceChunker _chunker = SentenceChunker();

  StreamSubscription<double>? _levelSubscription;
  StreamSubscription<SpeechSegment>? _speechSubscription;
  StreamSubscription<void>? _speechStartSubscription;
  StreamSubscription<bool>? _speakingSubscription;

  bool _wired = false;

  /// Bumped on every [exit] (and re-entry) so a phase that was in flight when
  /// the user exits does not resume the loop afterwards.
  int _runToken = 0;

  bool _running(int token) => token == _runToken && !isClosed;

  /// Enters voice mode and starts the first listen turn. No-op if already
  /// running.
  Future<void> enter() async {
    if (state.isActive) return;
    _runToken++;
    _wireSegmenter();
    await _startListening(_runToken);
  }

  /// Handles a tap on the orb: end-the-turn-now during listening, or barge-in
  /// (cancel TTS) during speaking.
  Future<void> onTap() async {
    switch (state.phase) {
      case VoiceConversationPhase.listening:
        await _endTurnEarly(_runToken);
      case VoiceConversationPhase.speaking:
        await _bargeIn(_runToken);
      case VoiceConversationPhase.idle:
      case VoiceConversationPhase.transcribing:
      case VoiceConversationPhase.thinking:
        // Nothing actionable mid-transcribe/think.
        break;
    }
  }

  // -- Segmenter wiring ------------------------------------------------------

  /// Subscribes once to the segmenter's lifetime streams. The handlers are
  /// guarded by [_running] + the current phase so events that arrive while
  /// paused/transitioning are ignored.
  void _wireSegmenter() {
    if (_wired) return;
    _wired = true;

    _levelSubscription = _segmenter.levelStream.listen((level) {
      if (isClosed || !state.isListening) return;
      emit(state.copyWith(micLevel: level.clamp(0.0, 1.0)));
    }, onError: (_) {});

    _speechStartSubscription = _segmenter.onSpeechStart.listen((_) {
      // Purely a hint that the user has started talking; no phase change. The
      // orb level already reflects it, so nothing to emit here.
    }, onError: (_) {});

    _speechSubscription = _segmenter.onSpeech.listen((segment) {
      final token = _runToken;
      if (!_running(token) || !state.isListening) return;
      unawaited(_handleSegment(token, segment));
    }, onError: (_) {});
  }

  // -- Phase: listening ------------------------------------------------------

  Future<void> _startListening(int token) async {
    if (!_running(token)) return;

    try {
      await _segmenter.start();
    } catch (error) {
      _reportError(error);
      await _exitInternal();
      return;
    }
    if (!_running(token)) {
      await _safeStopSegmenter();
      return;
    }

    emit(
      state.copyWith(
        phase: VoiceConversationPhase.listening,
        partialTranscript: '',
        micLevel: 0.0,
      ),
    );
  }

  /// Tap-to-end during listening: the neural VAD captures continuously, so we
  /// just keep listening (there is no recorder to stop). A subsequent
  /// [onSpeech] event handles whatever was said.
  Future<void> _endTurnEarly(int token) async {
    // No-op beyond guarding: the segmenter emits a segment when the user stops
    // talking. Tapping mid-listen has no separate "finish now" on the neural
    // VAD, so we leave the turn running rather than truncating audio.
    if (!_running(token) || !state.isListening) return;
  }

  bool _transitioningFromListening = false;

  Future<void> _handleSegment(int token, SpeechSegment segment) async {
    if (!_running(token) || !state.isListening) return;
    if (_transitioningFromListening) return;
    _transitioningFromListening = true;
    try {
      // Pause the mic immediately so it never captures the assistant's reply.
      await _pauseSegmenter();

      if (segment.pcm16.isEmpty) {
        await _restartListening(token);
        return;
      }

      String wavPath;
      try {
        wavPath = await _writeWav(segment);
      } catch (error) {
        _reportError(error);
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

    // Stream completed sentences into TTS as the reply grows. The mic is already
    // paused for the whole thinking/speaking span, so this never records the
    // assistant. Sentences are only enqueued when TTS is available.
    _chunker.reset();
    final ttsAvailable = _textToSpeech.isAvailable;
    var spokeAnything = false;
    var ttsFailed = false;
    final enqueues = <Future<void>>[];

    void enqueueSentence(String sentence) {
      if (!spokeAnything) {
        // First sentence: wire the drain listener and reflect speaking before
        // audio starts.
        _beginSpeakingPhase(token);
        spokeAnything = true;
      }
      // Track the future so we can observe enqueue errors before deciding the
      // post-generation phase, but do not block the streaming callback on it.
      enqueues.add(_enqueueSpoken(sentence, onError: () => ttsFailed = true));
    }

    void enqueueCompleted(String draftSoFar) {
      if (!ttsAvailable || !_running(token) || ttsFailed) return;
      // Stop feeding the queue if the user barged in / the turn moved on (e.g.
      // back to listening) while generation is still streaming.
      if (spokeAnything && state.phase != VoiceConversationPhase.speaking) {
        return;
      }
      for (final sentence in _chunker.takeCompletedSentences(draftSoFar)) {
        enqueueSentence(sentence);
      }
    }

    String? reply;
    try {
      reply = await _generationSignal.run(
        () => _sendMessage(text),
        onDraft: enqueueCompleted,
      );
    } catch (error) {
      _reportError(error);
      await _clearSpeaking();
      await _restartListening(token);
      return;
    }
    if (!_running(token)) return;

    // Flush the trailing partial sentence (the reply is now complete). Skip if
    // the user already barged in (back to listening) while we were generating.
    final fullReply = reply ?? '';
    final bargedIn =
        spokeAnything && state.phase != VoiceConversationPhase.speaking;
    if (ttsAvailable && !bargedIn && !ttsFailed) {
      for (final sentence in _chunker.flush(fullReply)) {
        enqueueSentence(sentence);
      }
    }

    // Let all in-flight enqueues settle so `ttsFailed` reflects any engine
    // error before we choose the next phase.
    await Future.wait(enqueues);
    if (!_running(token)) return;

    if (bargedIn) {
      // Already returned to listening via barge-in; nothing more to do.
      return;
    }
    if (ttsFailed) {
      // The engine errored while enqueuing: tear down speaking and keep looping.
      await _clearSpeaking();
      await _restartListening(token);
      return;
    }
    if (!spokeAnything) {
      // Nothing to say (empty reply, or TTS unavailable) — keep looping.
      await _restartListening(token);
      return;
    }
    // Otherwise the speaking-phase listener returns to listening once the queue
    // drains (speakingChanges -> false).
  }

  // -- Phase: speaking -------------------------------------------------------

  /// Switches to the speaking phase (idempotent) and wires the listener that
  /// returns to listening once the spoken queue drains.
  void _beginSpeakingPhase(int token) {
    if (state.phase != VoiceConversationPhase.speaking) {
      emit(state.copyWith(phase: VoiceConversationPhase.speaking));
    }
    if (_speakingSubscription != null) return;

    _speakingSubscription = _textToSpeech.speakingChanges.listen((speaking) {
      if (speaking) return;
      if (!_running(token) || state.phase != VoiceConversationPhase.speaking) {
        return;
      }
      unawaited(_speakingSubscription?.cancel());
      _speakingSubscription = null;
      unawaited(_restartListening(token));
    });
  }

  Future<void> _enqueueSpoken(
    String sentence, {
    void Function()? onError,
  }) async {
    try {
      await _textToSpeech.enqueue(sentence);
    } catch (error) {
      _reportError(error);
      onError?.call();
    }
  }

  Future<void> _clearSpeaking() async {
    await _speakingSubscription?.cancel();
    _speakingSubscription = null;
    try {
      await _textToSpeech.clear();
    } catch (_) {
      // best-effort
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

  /// Exits voice mode: stops the segmenter + TTS, abandons any in-flight phase,
  /// and returns to idle.
  Future<void> exit() => _exitInternal();

  Future<void> _exitInternal() async {
    _runToken++; // invalidate any in-flight phase
    _transitioningFromListening = false;
    await _speakingSubscription?.cancel();
    _speakingSubscription = null;
    await _safeStopSegmenter();
    try {
      await _textToSpeech.stop();
    } catch (_) {
      // best-effort
    }
    if (!isClosed) emit(const VoiceConversationState());
  }

  Future<void> _pauseSegmenter() async {
    try {
      await _segmenter.pause();
    } catch (_) {
      // Pausing is best-effort.
    }
  }

  Future<void> _safeStopSegmenter() async {
    try {
      await _segmenter.stop();
    } catch (_) {
      // Stopping is best-effort.
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
    await _levelSubscription?.cancel();
    _levelSubscription = null;
    await _speechSubscription?.cancel();
    _speechSubscription = null;
    await _speechStartSubscription?.cancel();
    _speechStartSubscription = null;
    await _segmenter.dispose();
    return super.close();
  }
}

/// Bridges the chat generation lifecycle so the cubit can wait for a reply to
/// finish and read its final text without depending on the chat cubits'
/// internals. [run] starts the send (via the supplied action), waits until
/// generation completes, and returns the final assistant text (or `null` if
/// none was produced).
///
/// While generation is in flight, every growing-draft update is delivered to the
/// optional [onDraft] callback. This lets the caller stream the partial reply
/// through a sentence chunker and start speaking completed sentences before the
/// whole reply is finished.
abstract interface class GenerationSignal {
  Future<String?> run(
    Future<void> Function() send, {
    void Function(String draftSoFar)? onDraft,
  });
}
