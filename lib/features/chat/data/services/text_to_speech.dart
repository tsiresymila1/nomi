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

  /// Speaks [text] aloud. Any in-progress utterance is stopped first.
  Future<void> speak(String text);

  /// Stops any in-progress utterance.
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

  bool _disposed = false;

  @override
  bool get isAvailable => _capabilities.supportsTextToSpeech;

  @override
  Stream<bool> get speakingChanges => _speakingController.stream;

  void _wireHandlers() {
    _tts.setStartHandler(() => _emit(true));
    _tts.setCompletionHandler(() => _emit(false));
    _tts.setCancelHandler(() => _emit(false));
    _tts.setErrorHandler((_) => _emit(false));
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

    // Stop any in-progress utterance before starting a new one so toggling
    // between messages does not overlap audio.
    await _tts.stop();
    await _tts.speak(spoken);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    // Some platforms do not fire the cancel handler on an explicit stop, so
    // surface the idle state proactively.
    _emit(false);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
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
