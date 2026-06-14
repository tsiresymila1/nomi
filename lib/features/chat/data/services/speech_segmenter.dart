/// Provider-neutral speech-segmentation contract for hands-free voice mode.
///
/// A segmenter owns the microphone, runs a neural voice-activity detector over
/// the live audio, and emits a [SpeechSegment] each time the user finishes an
/// utterance. The [VoiceConversationCubit] drives this seam instead of talking
/// to the recorder + VAD directly, so the conversation loop is fully testable
/// with a fake and web/unsupported builds never import the native VAD plugin.
///
/// A conditional factory ([createSpeechSegmenter]) selects the native
/// Silero-VAD implementation where `dart:io` is available and an unsupported
/// implementation on web. Voice mode is itself gated on `supportsSpeechToText`,
/// so the web stub is never reached at runtime.
abstract interface class SpeechSegmenter {
  /// A 0..1 speech-probability stream sampled per audio frame, suitable for
  /// animating the listening orb. Higher means more likely speech.
  Stream<double> get levelStream;

  /// Fires once per completed utterance, carrying the captured PCM.
  Stream<SpeechSegment> get onSpeech;

  /// Fires when validated (real) speech begins — i.e. the user has started
  /// talking, not just a transient blip. Drives the "hearing you" hint.
  Stream<void> get onSpeechStart;

  /// Starts (or resumes) capturing the microphone and detecting speech.
  Future<void> start();

  /// Pauses detection while keeping the session alive so [start] can resume it
  /// cheaply. Used to mute the mic while the assistant is speaking.
  Future<void> pause();

  /// Stops capturing and releases the microphone, but keeps the segmenter
  /// reusable via a later [start].
  Future<void> stop();

  /// Releases all resources and closes the event streams. Not reusable after.
  Future<void> dispose();
}

/// A completed spoken utterance captured by a [SpeechSegmenter].
///
/// [pcm16] holds normalised [-1, 1] PCM samples (the format the Silero VAD
/// emits); [sampleRate] is the capture rate, always 16 kHz mono so it feeds
/// whisper after a trivial WAV wrapping.
class SpeechSegment {
  const SpeechSegment({required this.pcm16, this.sampleRate = 16000});

  /// Normalised [-1, 1] mono PCM samples for the utterance.
  final List<double> pcm16;

  /// Capture sample rate in Hz (16 kHz, what whisper expects).
  final int sampleRate;
}
