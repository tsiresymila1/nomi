import 'dart:async';

import 'package:vad/vad.dart';

import 'speech_segmenter.dart';

/// Builds the native Silero-VAD-backed segmenter. Pulled in only where
/// `dart:io` is available (the conditional [createSpeechSegmenter] factory).
SpeechSegmenter createSpeechSegmenter() => VadSpeechSegmenter();

/// Wraps the `vad` package's [VadHandler] (neural Silero VAD) behind the
/// provider-neutral [SpeechSegmenter] seam.
///
/// The handler captures the microphone itself (via `record`), runs the Silero
/// v5 model frame-by-frame, and emits:
/// - [VadHandler.onFrameProcessed] → mapped to [levelStream] (speech prob),
/// - [VadHandler.onRealSpeechStart] → [onSpeechStart],
/// - [VadHandler.onSpeechEnd] (a `List<double>` of 16 kHz mono PCM in [-1, 1])
///   → [onSpeech] as a [SpeechSegment].
///
/// The Silero model loads from a bundled local asset ([_baseAssetPath]) so VAD
/// works offline, matching the app's offline-first design; if the asset is
/// missing the handler falls back to its CDN default (see [createSpeechSegmenter]
/// docs / the asset note in pubspec).
class VadSpeechSegmenter implements SpeechSegmenter {
  VadSpeechSegmenter({VadHandler? handler})
    : _handler = handler ?? VadHandler.create(isDebug: false);

  final VadHandler _handler;

  /// Where the Silero `.onnx` model is bundled. The handler appends
  /// `silero_vad_v5.onnx` to this base path and loads it via the asset bundle.
  ///
  /// Bundled model provenance (offline-first; no CDN round-trip at runtime):
  ///   source : https://cdn.jsdelivr.net/npm/@keyurmaru/vad@0.0.1/silero_vad_v5.onnx
  ///   sha256 : 2623a2953f6ff3d2c1e61740c6cdb7168133479b267dfef114a4a3cc5bdd788f
  static const String _baseAssetPath = 'assets/vad/';

  final StreamController<double> _levelController =
      StreamController<double>.broadcast();
  final StreamController<SpeechSegment> _speechController =
      StreamController<SpeechSegment>.broadcast();
  final StreamController<void> _speechStartController =
      StreamController<void>.broadcast();

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  bool _wired = false;
  bool _started = false;
  bool _disposed = false;

  @override
  Stream<double> get levelStream => _levelController.stream;

  @override
  Stream<SpeechSegment> get onSpeech => _speechController.stream;

  @override
  Stream<void> get onSpeechStart => _speechStartController.stream;

  void _wire() {
    if (_wired) return;
    _wired = true;

    _subscriptions.add(
      _handler.onFrameProcessed.listen((frame) {
        if (_levelController.isClosed) return;
        // `isSpeech` is the Silero speech probability in [0, 1] — exactly the
        // orb level we want.
        _levelController.add(frame.isSpeech.clamp(0.0, 1.0));
      }, onError: (_) {}),
    );

    _subscriptions.add(
      _handler.onRealSpeechStart.listen((_) {
        if (!_speechStartController.isClosed) _speechStartController.add(null);
      }, onError: (_) {}),
    );

    _subscriptions.add(
      _handler.onSpeechEnd.listen((pcm) {
        if (_speechController.isClosed) return;
        _speechController.add(SpeechSegment(pcm16: pcm, sampleRate: 16000));
      }, onError: (_) {}),
    );

    // Surface VAD errors as level resets so the loop keeps polling; the cubit
    // recovers on its own. Errors are otherwise non-fatal here.
    _subscriptions.add(_handler.onError.listen((_) {}, onError: (_) {}));
  }

  @override
  Future<void> start() async {
    if (_disposed) return;
    _wire();
    _started = true;
    await _handler.startListening(
      model: 'v5',
      baseAssetPath: _baseAssetPath,
      positiveSpeechThreshold: 0.5,
      negativeSpeechThreshold: 0.35,
      frameSamples: 512,
    );
  }

  @override
  Future<void> pause() async {
    if (_disposed || !_started) return;
    await _handler.pauseListening();
  }

  @override
  Future<void> stop() async {
    if (_disposed || !_started) return;
    _started = false;
    await _handler.stopListening();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _handler.dispose();
    await _levelController.close();
    await _speechController.close();
    await _speechStartController.close();
  }
}
