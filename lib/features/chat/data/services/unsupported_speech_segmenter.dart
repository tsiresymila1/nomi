import 'speech_segmenter.dart';

/// Builds the unsupported-platform segmenter (e.g. web). Imports neither the
/// `vad` plugin nor `dart:io`, so those never reach a web build.
SpeechSegmenter createSpeechSegmenter() => const _UnsupportedSpeechSegmenter();

/// No-op segmenter for platforms without native VAD support. Voice conversation
/// mode is gated on `supportsSpeechToText`, so this is never driven at runtime;
/// it exists only so web/unsupported builds compile.
class _UnsupportedSpeechSegmenter implements SpeechSegmenter {
  const _UnsupportedSpeechSegmenter();

  static const _message = 'Voice conversation is unavailable on this platform.';

  @override
  Stream<double> get levelStream => const Stream<double>.empty();

  @override
  Stream<SpeechSegment> get onSpeech => const Stream<SpeechSegment>.empty();

  @override
  Stream<void> get onSpeechStart => const Stream<void>.empty();

  @override
  Future<void> start() => throw const _SpeechSegmenterUnsupported(_message);

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _SpeechSegmenterUnsupported implements Exception {
  const _SpeechSegmenterUnsupported(this.message);

  final String message;

  @override
  String toString() => 'SpeechSegmenterUnsupported: $message';
}
