import 'dart:async';

/// A microphone level reading, normalised so callers don't depend on the
/// `record` plugin's `Amplitude` type directly.
///
/// [dbfs] is the current amplitude in dBFS (decibels relative to full scale):
/// `0.0` is the loudest possible signal and large negative values (e.g. `-60`
/// or lower) are effectively silence.
class MicLevel {
  const MicLevel(this.dbfs);

  final double dbfs;

  /// A 0..1 loudness suitable for animating a meter, mapping the usable dBFS
  /// range [[floorDbfs], 0] onto [0, 1].
  double normalized({double floorDbfs = -60.0}) {
    if (dbfs.isNaN || dbfs.isInfinite) return 0.0;
    final clamped = dbfs.clamp(floorDbfs, 0.0);
    return ((clamped - floorDbfs) / (0.0 - floorDbfs)).clamp(0.0, 1.0);
  }
}

/// Emits microphone levels while recording. Implemented by the native
/// `record`-backed recorder; kept separate from [VoiceAudioRecorder] so the
/// existing hold-to-record flow (and its fakes) are untouched, and so web /
/// unsupported builds never import the native amplitude API.
abstract interface class VoiceLevelSource {
  /// A broadcast stream of microphone levels sampled at roughly [interval].
  Stream<MicLevel> levelStream(Duration interval);
}

/// Tuning constants for [VadController]. Exposed so they can be adjusted per
/// device/mic if the defaults prove too eager or too sluggish.
class VadConfig {
  const VadConfig({
    this.sampleInterval = const Duration(milliseconds: 150),
    this.speechThresholdDbfs = -35.0,
    this.silenceWindow = const Duration(milliseconds: 1500),
    this.minSpeechDuration = const Duration(milliseconds: 300),
    this.maxListenDuration = const Duration(seconds: 30),
  });

  /// How often the underlying level source is sampled.
  final Duration sampleInterval;

  /// Levels at or above this dBFS count as speech; below it counts as silence.
  final double speechThresholdDbfs;

  /// Sustained silence of at least this long *after* speech was detected fires
  /// end-of-speech.
  final Duration silenceWindow;

  /// Speech must have lasted at least this long before a silence window can fire
  /// end-of-speech — guards against a single transient blip.
  final Duration minSpeechDuration;

  /// Hard cap on a single listen turn. Fires end-of-speech regardless once
  /// reached (only if some speech was detected — pure silence never fires).
  final Duration maxListenDuration;
}

/// Why a [VadController] listen turn ended.
enum VadStopReason {
  /// Sustained silence followed detected speech.
  silence,

  /// The max-listen cap was reached after some speech.
  maxDuration,
}

/// Watches a [MicLevel] stream and decides when the speaker has finished a turn.
///
/// Pure and fully testable: feed it levels via [add] (or attach it to a real
/// [VoiceLevelSource] with [start]) and it fires [onStop] once, when a
/// sustained sub-threshold window follows detected speech, or when the
/// max-listen cap is hit after speech. It never fires on pure silence (the user
/// said nothing), so the conversation loop can keep listening.
class VadController {
  VadController({
    VadConfig config = const VadConfig(),
    Duration Function()? clock,
  }) : _config = config,
       _now =
           clock ??
           (() =>
               Duration(microseconds: DateTime.now().microsecondsSinceEpoch));

  final VadConfig _config;
  final Duration Function() _now;

  StreamSubscription<MicLevel>? _subscription;
  void Function(VadStopReason reason)? _onStop;

  Duration? _startedAt;
  Duration? _firstSpeechAt;
  Duration? _lastSpeechAt;
  bool _speechDetected = false;
  bool _stopped = false;

  /// Whether any above-threshold level has been seen this turn.
  bool get hasDetectedSpeech => _speechDetected;

  /// Begins a listen turn. [onStop] is invoked at most once. If [source] is
  /// given, levels are pulled from it; otherwise feed levels manually via [add].
  void start({
    required void Function(VadStopReason reason) onStop,
    VoiceLevelSource? source,
  }) {
    reset();
    _onStop = onStop;
    _startedAt = _now();
    if (source != null) {
      _subscription = source
          .levelStream(_config.sampleInterval)
          .listen(add, onError: (_) {});
    }
  }

  /// Feeds a single level reading. Safe to call after the turn has stopped
  /// (ignored).
  void add(MicLevel level) {
    if (_stopped) return;
    final now = _now();
    _startedAt ??= now;

    final isSpeech = level.dbfs >= _config.speechThresholdDbfs;
    if (isSpeech) {
      _speechDetected = true;
      _firstSpeechAt ??= now;
      _lastSpeechAt = now;
    }

    // Max-listen cap only matters once the user has actually started speaking,
    // so a silent mic never auto-sends.
    if (_speechDetected && now - _startedAt! >= _config.maxListenDuration) {
      _fire(VadStopReason.maxDuration);
      return;
    }

    // End-of-speech: speech happened, lasted long enough, and we've now seen a
    // sustained silence window with no further speech.
    if (_speechDetected && !isSpeech && _lastSpeechAt != null) {
      final spokeFor = _lastSpeechAt! - _firstSpeechAt!;
      final silentFor = now - _lastSpeechAt!;
      if (spokeFor >= _config.minSpeechDuration &&
          silentFor >= _config.silenceWindow) {
        _fire(VadStopReason.silence);
      }
    }
  }

  void _fire(VadStopReason reason) {
    if (_stopped) return;
    _stopped = true;
    final callback = _onStop;
    _onStop = null;
    callback?.call(reason);
  }

  /// Stops watching and detaches from any source without firing [onStop].
  void reset() {
    _subscription?.cancel();
    _subscription = null;
    _onStop = null;
    _startedAt = null;
    _firstSpeechAt = null;
    _lastSpeechAt = null;
    _speechDetected = false;
    _stopped = false;
  }

  /// Releases resources. Alias for [reset]; safe to call repeatedly.
  void dispose() => reset();
}
