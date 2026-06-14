import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'package:gena/core/platform/app_capabilities.dart';

/// Provider-neutral text-to-speech contract.
///
/// Reads assistant replies aloud through the platform's native voices. Unlike
/// the on-device whisper/llamadart seams, `flutter_tts` compiles on web AND
/// native, so a single implementation backs every platform and no conditional
/// `dart.library.io` factory is needed. The cubit depends only on this
/// interface so the speak/stop flow is testable with a fake.
abstract interface class TextToSpeech {
  /// Whether text-to-speech is available on the current platform.
  bool get isAvailable;

  /// Speaks [text] aloud. Any in-progress utterance is stopped first, and any
  /// queued utterances (see [enqueue]) are cleared.
  Future<void> speak(String text);

  /// Queues [text] to be spoken after any currently-playing and previously
  /// queued utterances finish. Use this to stream a reply sentence-by-sentence:
  /// enqueue each completed sentence as it arrives so playback starts on the
  /// first sentence without waiting for the whole reply.
  ///
  /// Empty/blank text is ignored. The queue is drained in FIFO order; the next
  /// item starts when the engine reports the previous utterance finished.
  Future<void> enqueue(String text);

  /// Clears any queued utterances and stops the current one (barge-in). Leaves
  /// the engine ready for a new [speak]/[enqueue].
  Future<void> clear();

  /// Stops any in-progress utterance and clears the queue.
  Future<void> stop();

  /// Emits `true` when speaking starts and `false` when it ends (on
  /// completion, cancellation, or error). Broadcast so multiple listeners can
  /// observe the speaking state.
  Stream<bool> get speakingChanges;

  /// Releases the underlying engine and closes [speakingChanges].
  Future<void> dispose();
}

/// [TextToSpeech] backed by the platform-native `flutter_tts` engine.
class FlutterTextToSpeech implements TextToSpeech {
  FlutterTextToSpeech({FlutterTts? tts, AppCapabilities? capabilities})
    : _tts = tts ?? FlutterTts(),
      _capabilities = capabilities ?? AppCapabilities.current {
    _wireHandlers();
    _applyDefaults();
  }

  final FlutterTts _tts;
  final AppCapabilities _capabilities;
  final StreamController<bool> _speakingController =
      StreamController<bool>.broadcast();

  /// Pending utterances queued via [enqueue], drained FIFO as each finishes.
  final List<String> _queue = <String>[];

  /// Whether an utterance is currently playing (so the completion handler knows
  /// to start the next queued item rather than emit idle).
  bool _utteranceActive = false;

  bool _disposed = false;

  @override
  bool get isAvailable => _capabilities.supportsTextToSpeech;

  @override
  Stream<bool> get speakingChanges => _speakingController.stream;

  void _wireHandlers() {
    _tts.setStartHandler(() => _emit(true));
    _tts.setCompletionHandler(_onUtteranceFinished);
    // A cancel/error ends the whole queue: speakers expect barge-in/stop to
    // halt everything, and an engine error should not silently advance.
    _tts.setCancelHandler(() {
      _utteranceActive = false;
      _queue.clear();
      _emit(false);
    });
    _tts.setErrorHandler((_) {
      _utteranceActive = false;
      _queue.clear();
      _emit(false);
    });
  }

  /// Called when the engine finishes one utterance. If more are queued, speak
  /// the next one (staying "speaking"); otherwise go idle.
  void _onUtteranceFinished() {
    _utteranceActive = false;
    if (_disposed) {
      _emit(false);
      return;
    }
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      _utteranceActive = true;
      // Do not emit idle between queued sentences; keep listeners "speaking".
      unawaited(_tts.speak(next));
      return;
    }
    _emit(false);
  }

  void _applyDefaults() {
    // Best-effort defaults; failures are non-fatal (e.g. an engine that does
    // not support a given setter). Kept modest so playback is easy to follow.
    unawaited(_tts.setSpeechRate(0.5));
    unawaited(_tts.setPitch(1.0));
    unawaited(_tts.setVolume(1.0));
  }

  void _emit(bool speaking) {
    if (_disposed || _speakingController.isClosed) return;
    _speakingController.add(speaking);
  }

  @override
  Future<void> speak(String text) async {
    if (!isAvailable) {
      throw TextToSpeechException(_capabilities.textToSpeechUnavailableMessage);
    }
    final spoken = text.trim();
    if (spoken.isEmpty) return;

    // Stop any in-progress utterance and discard the queue before starting a
    // fresh one-shot so toggling between messages does not overlap audio.
    _queue.clear();
    await _tts.stop();
    _utteranceActive = true;
    await _tts.speak(spoken);
  }

  @override
  Future<void> enqueue(String text) async {
    if (!isAvailable) {
      throw TextToSpeechException(_capabilities.textToSpeechUnavailableMessage);
    }
    final spoken = text.trim();
    if (spoken.isEmpty) return;

    if (_utteranceActive) {
      _queue.add(spoken);
      return;
    }
    // Nothing playing: start immediately so the first sentence is not delayed.
    _utteranceActive = true;
    await _tts.speak(spoken);
  }

  @override
  Future<void> clear() async {
    _queue.clear();
    _utteranceActive = false;
    await _tts.stop();
    _emit(false);
  }

  @override
  Future<void> stop() async {
    _queue.clear();
    _utteranceActive = false;
    await _tts.stop();
    // Some platforms do not fire the cancel handler on an explicit stop, so
    // surface the idle state proactively.
    _emit(false);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _queue.clear();
    _utteranceActive = false;
    await _tts.stop();
    await _speakingController.close();
  }
}

/// Raised when text-to-speech is unavailable or playback fails.
class TextToSpeechException implements Exception {
  const TextToSpeechException(this.message);

  final String message;

  @override
  String toString() => 'TextToSpeechException: $message';
}
