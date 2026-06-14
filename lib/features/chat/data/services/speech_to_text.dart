/// Provider-neutral on-device speech-to-text contract.
///
/// Implementations own a single cached whisper runtime, lazily download the
/// model on first use, and transcribe a 16 kHz mono WAV file into text. A
/// conditional factory ([createSpeechToText]) selects the native whisper
/// implementation where `dart:io` is available and an unsupported
/// implementation on web, so the rest of the app (and unit tests) compile
/// without the native plugin.
abstract interface class SpeechToText {
  /// Whether speech-to-text is available on the current platform.
  bool get isAvailable;

  /// Downloads the whisper model if it is not already present on disk.
  ///
  /// Safe to call repeatedly; subsequent calls are cheap once the model exists.
  Future<void> ensureModelReady();

  /// Transcribes the 16 kHz mono WAV file at [wavPath].
  ///
  /// [lang] is the spoken language hint (`'auto'` lets whisper detect it).
  Future<SttResult> transcribe(String wavPath, {String lang = 'auto'});
}

/// A completed transcription.
class SttResult {
  const SttResult({required this.text, this.language});

  /// The transcribed text (already trimmed of surrounding whitespace).
  final String text;

  /// The detected/requested spoken language, if known.
  final String? language;
}

/// Raised when speech-to-text is unavailable or transcription fails.
class SpeechToTextException implements Exception {
  const SpeechToTextException(this.message);

  final String message;

  @override
  String toString() => 'SpeechToTextException: $message';
}
