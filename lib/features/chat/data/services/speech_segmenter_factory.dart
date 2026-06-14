import 'speech_segmenter.dart';
// Selects the native Silero-VAD-backed segmenter where dart:io is available,
// and an unsupported (no-op) segmenter on web.
import 'unsupported_speech_segmenter.dart'
    if (dart.library.io) 'vad_speech_segmenter.dart'
    as impl;

/// Returns the speech segmenter for the current platform.
SpeechSegmenter createSpeechSegmenter() => impl.createSpeechSegmenter();
