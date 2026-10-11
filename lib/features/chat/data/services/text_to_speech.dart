import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'package:gena/core/platform/app_capabilities.dart';

class TextToSpeechPreferences {
  const TextToSpeechPreferences({
    this.engine,
    this.voiceName,
    this.voiceLocale,
    this.speechRate = 0.5,
    this.pitch = 1,
  });

  final String? engine;
  final String? voiceName;
  final String? voiceLocale;
  final double speechRate;
  final double pitch;
}

class TextToSpeechVoice {
  const TextToSpeechVoice({
    required this.name,
    required this.locale,
    this.quality = 'unknown',
    this.latency = 'unknown',
    this.networkRequired = false,
  });

  final String name;
  final String locale;
  final String quality;
  final String latency;
  final bool networkRequired;

  String get id => '$name::$locale';
  bool get isOffline => !networkRequired;
  bool get isHighQuality => quality == 'high' || quality == 'very high';

  Map<String, String> get platformValue => <String, String>{
    'name': name,
    'locale': locale,
  };
}

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
  FlutterTextToSpeech({
    FlutterTts? tts,
    AppCapabilities? capabilities,
    TextToSpeechPreferences preferences = const TextToSpeechPreferences(),
  }) : _tts = tts ?? FlutterTts(),
       _capabilities = capabilities ?? AppCapabilities.current {
    _wireHandlers();
    unawaited(applyPreferences(preferences).catchError((_) {}));
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

  Future<List<String>> availableEngines() async {
    if (!isAvailable) return const <String>[];
    try {
      final raw = await _tts.getEngines;
      if (raw is! List) return const <String>[];
      return raw
          .map((engine) => engine.toString().trim())
          .where((engine) => engine.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<List<TextToSpeechVoice>> availableVoices() async {
    if (!isAvailable) return const <TextToSpeechVoice>[];
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return const <TextToSpeechVoice>[];
      final voices = <TextToSpeechVoice>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final name = item['name']?.toString().trim() ?? '';
        final locale = item['locale']?.toString().trim() ?? '';
        if (name.isEmpty || locale.isEmpty) continue;
        voices.add(
          TextToSpeechVoice(
            name: name,
            locale: locale,
            quality: item['quality']?.toString().toLowerCase() ?? 'unknown',
            latency: item['latency']?.toString().toLowerCase() ?? 'unknown',
            networkRequired: item['network_required']?.toString() == '1',
          ),
        );
      }
      voices.sort((a, b) {
        final offline = (b.isOffline ? 1 : 0).compareTo(a.isOffline ? 1 : 0);
        if (offline != 0) return offline;
        final quality = _qualityScore(
          b.quality,
        ).compareTo(_qualityScore(a.quality));
        if (quality != 0) return quality;
        final locale = a.locale.compareTo(b.locale);
        return locale != 0 ? locale : a.name.compareTo(b.name);
      });
      return voices;
    } catch (_) {
      return const <TextToSpeechVoice>[];
    }
  }

  static int _qualityScore(String quality) => switch (quality) {
    'very high' => 4,
    'high' => 3,
    'normal' => 2,
    'low' => 1,
    _ => 0,
  };

  Future<void> applyPreferences(TextToSpeechPreferences preferences) async {
    if (!isAvailable) return;
    try {
      final engine = preferences.engine?.trim();
      if (engine != null && engine.isNotEmpty) {
        await _tts.setEngine(engine);
      }
      final voiceName = preferences.voiceName?.trim();
      final voiceLocale = preferences.voiceLocale?.trim();
      if (voiceName != null &&
          voiceName.isNotEmpty &&
          voiceLocale != null &&
          voiceLocale.isNotEmpty) {
        await _tts.setVoice(<String, String>{
          'name': voiceName,
          'locale': voiceLocale,
        });
      }
      await _tts.setSpeechRate(preferences.speechRate.clamp(0.2, 0.9));
      await _tts.setPitch(preferences.pitch.clamp(0.5, 1.5));
      await _tts.setVolume(1.0);
    } catch (error) {
      throw TextToSpeechException('Could not apply voice settings: $error');
    }
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
