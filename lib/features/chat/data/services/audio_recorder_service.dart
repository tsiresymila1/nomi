import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:gena/features/chat/presentation/cubit/voice_input_cubit.dart';
import 'speech_to_text.dart';

/// Wraps the `record` plugin to capture microphone audio as a 16 kHz mono WAV
/// file — exactly the format whisper expects, so the output feeds
/// [SpeechToText.transcribe] with no conversion.
///
/// `dart:io` only; native and capability-gated. Web/unsupported paths never
/// import this file. Drives the manual hold-to-record flow ([VoiceInputCubit]);
/// hands-free voice mode uses the neural [SpeechSegmenter] instead.
class AudioRecorderService implements VoiceAudioRecorder {
  AudioRecorderService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  String? _activePath;

  /// 16 kHz mono WAV — the format whisper requires.
  static const RecordConfig recordConfig = RecordConfig(
    encoder: AudioEncoder.wav,
    numChannels: 1,
    sampleRate: 16000,
  );

  /// Whether a microphone permission has been granted (requesting if needed).
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Begins recording to a fresh temporary `*.wav` file.
  ///
  /// Throws [SpeechToTextException] if microphone permission is denied.
  @override
  Future<void> start() async {
    if (!await hasPermission()) {
      throw const SpeechToTextException(
        'Microphone permission is required for voice input.',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/stt_${DateTime.now().millisecondsSinceEpoch}.wav';
    _activePath = path;
    await _recorder.start(recordConfig, path: path);
  }

  /// Stops recording and returns the path to the captured WAV file, or null if
  /// nothing was recorded.
  @override
  Future<String?> stop() async {
    final path = await _recorder.stop();
    _activePath = null;
    return path;
  }

  /// Cancels the active recording and deletes the partial WAV file.
  @override
  Future<void> cancel() async {
    await _recorder.cancel();
    final path = _activePath;
    _activePath = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Releases the underlying recorder.
  Future<void> dispose() => _recorder.dispose();
}
