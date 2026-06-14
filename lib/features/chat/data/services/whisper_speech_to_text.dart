import 'dart:io';

import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';

import 'package:gena/core/platform/app_capabilities.dart';
import 'speech_to_text.dart';

/// Builds the native whisper-backed speech-to-text driver.
SpeechToText createSpeechToText() => WhisperSpeechToText();

/// On-device speech-to-text backed by whisper.cpp via `whisper_ggml_plus`.
///
/// Owns a single cached [WhisperController] and lazily downloads the whisper
/// model on first use (first-run download, like `RagModelProvisioner` — no
/// bundled model). Input must be a 16 kHz mono WAV file.
class WhisperSpeechToText implements SpeechToText {
  WhisperSpeechToText({
    WhisperController? controller,
    WhisperModel model = WhisperModel.base,
  }) : _controller = controller ?? WhisperController(),
       _model = model;

  final WhisperController _controller;
  final WhisperModel _model;

  Future<void>? _modelReady;

  @override
  bool get isAvailable => AppCapabilities.current.supportsSpeechToText;

  @override
  Future<void> ensureModelReady() {
    return _modelReady ??= _ensureModelReady().catchError((Object error) {
      // Allow a later retry if provisioning failed (e.g. offline).
      _modelReady = null;
      throw error;
    });
  }

  Future<void> _ensureModelReady() async {
    final path = await _controller.getPath(_model);
    if (File(path).existsSync()) return;
    try {
      await _controller.downloadModel(_model);
    } catch (error) {
      throw SpeechToTextException(
        'Failed to download the speech-to-text model: $error',
      );
    }
  }

  @override
  Future<SttResult> transcribe(String wavPath, {String lang = 'auto'}) async {
    await ensureModelReady();

    final result = await _transcribe(wavPath, lang);
    if (result == null) {
      throw const SpeechToTextException('Transcription returned no result.');
    }

    return SttResult(
      text: result.transcription.text.trim(),
      language: lang == 'auto' ? null : lang,
    );
  }

  // `TranscribeResult` is not exported by whisper_ggml_plus, so we keep the
  // type inferred here rather than naming it.
  Future<dynamic> _transcribe(String wavPath, String lang) async {
    try {
      return await _controller.transcribe(
        model: _model,
        audioPath: wavPath,
        lang: lang,
      );
    } catch (error) {
      throw SpeechToTextException('Transcription failed: $error');
    }
  }
}
