import 'package:gena/features/chat/data/models/whisper_model_profile.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';

import 'package:gena/core/platform/app_capabilities.dart';
import 'speech_to_text.dart';
import 'whisper_model_provisioner.dart';

/// Builds the native whisper-backed speech-to-text driver.
SpeechToText createSpeechToText({
  required WhisperProvisioner provisioner,
  required WhisperModelProfile Function() selectedProfile,
}) => WhisperSpeechToText(
  provisioner: provisioner,
  selectedProfile: selectedProfile,
);

abstract interface class WhisperEngine {
  Future<String?> transcribe({
    required WhisperModelProfile profile,
    required String audioPath,
    required String language,
  });
}

class NativeWhisperEngine implements WhisperEngine {
  NativeWhisperEngine({WhisperController? controller})
    : _controller = controller ?? WhisperController();

  final WhisperController _controller;

  @override
  Future<String?> transcribe({
    required WhisperModelProfile profile,
    required String audioPath,
    required String language,
  }) async {
    final result = await _controller.transcribe(
      model: switch (profile) {
        WhisperModelProfile.tiny => WhisperModel.tiny,
        WhisperModelProfile.base => WhisperModel.base,
      },
      audioPath: audioPath,
      lang: language,
    );
    return result?.transcription.text;
  }
}

/// On-device speech-to-text backed by whisper.cpp via `whisper_ggml_plus`.
///
/// Owns a single cached [WhisperController] and lazily downloads the whisper
/// model on first use (first-run download, like `RagModelProvisioner` — no
/// bundled model). Input must be a 16 kHz mono WAV file.
class WhisperSpeechToText implements SpeechToText {
  WhisperSpeechToText({
    required WhisperProvisioner provisioner,
    required WhisperModelProfile Function() selectedProfile,
    WhisperEngine? engine,
    bool Function()? availability,
  }) : _provisioner = provisioner,
       _selectedProfile = selectedProfile,
       _engine = engine ?? NativeWhisperEngine(),
       _availability =
           availability ?? (() => AppCapabilities.current.supportsSpeechToText);

  final WhisperProvisioner _provisioner;
  final WhisperModelProfile Function() _selectedProfile;
  final WhisperEngine _engine;
  final bool Function() _availability;

  @override
  bool get isAvailable => _availability();

  @override
  Future<void> ensureModelReady() async {
    final profile = _selectedProfile();
    try {
      await _provisioner.ensureReady(profile);
    } catch (error) {
      throw SpeechToTextException(
        'Failed to prepare the speech-to-text model: $error',
      );
    }
  }

  @override
  Future<SttResult> transcribe(String wavPath, {String lang = 'auto'}) async {
    final profile = _selectedProfile();
    try {
      await _provisioner.ensureReady(profile);
    } catch (error) {
      throw SpeechToTextException(
        'Failed to prepare the speech-to-text model: $error',
      );
    }

    final text = await _transcribe(profile, wavPath, lang);
    if (text == null) {
      throw const SpeechToTextException('Transcription returned no result.');
    }

    return SttResult(text: text.trim(), language: lang == 'auto' ? null : lang);
  }

  Future<String?> _transcribe(
    WhisperModelProfile profile,
    String wavPath,
    String lang,
  ) async {
    try {
      return await _engine.transcribe(
        profile: profile,
        audioPath: wavPath,
        language: lang,
      );
    } catch (error) {
      throw SpeechToTextException('Transcription failed: $error');
    }
  }
}
