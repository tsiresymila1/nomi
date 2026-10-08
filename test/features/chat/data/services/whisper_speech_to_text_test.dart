import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/models/whisper_model_profile.dart';
import 'package:gena/features/chat/data/services/whisper_model_provisioner.dart';
import 'package:gena/features/chat/data/services/whisper_speech_to_text.dart';

class _FakeProvisioner implements WhisperProvisioner {
  final List<WhisperModelProfile> ensured = <WhisperModelProfile>[];

  @override
  Future<String> ensureReady(
    WhisperModelProfile profile, {
    void Function(double progress, String message)? onProgress,
  }) async {
    ensured.add(profile);
    return '/models/${profile.fileName}';
  }
}

class _FakeEngine implements WhisperEngine {
  final List<WhisperModelProfile> profiles = <WhisperModelProfile>[];

  @override
  Future<String?> transcribe({
    required WhisperModelProfile profile,
    required String audioPath,
    required String language,
  }) async {
    profiles.add(profile);
    return ' transcript ';
  }
}

void main() {
  test('provisions the selected profile before transcription', () async {
    var selected = WhisperModelProfile.tiny;
    final provisioner = _FakeProvisioner();
    final engine = _FakeEngine();
    final speechToText = WhisperSpeechToText(
      provisioner: provisioner,
      engine: engine,
      selectedProfile: () => selected,
      availability: () => true,
    );

    final first = await speechToText.transcribe('/tmp/first.wav');
    selected = WhisperModelProfile.base;
    final second = await speechToText.transcribe('/tmp/second.wav');

    expect(first.text, 'transcript');
    expect(second.text, 'transcript');
    expect(provisioner.ensured, <WhisperModelProfile>[
      WhisperModelProfile.tiny,
      WhisperModelProfile.base,
    ]);
    expect(engine.profiles, provisioner.ensured);
  });

  test('ensureModelReady follows a changed selected profile', () async {
    var selected = WhisperModelProfile.tiny;
    final provisioner = _FakeProvisioner();
    final speechToText = WhisperSpeechToText(
      provisioner: provisioner,
      engine: _FakeEngine(),
      selectedProfile: () => selected,
      availability: () => true,
    );

    await speechToText.ensureModelReady();
    selected = WhisperModelProfile.base;
    await speechToText.ensureModelReady();

    expect(provisioner.ensured, <WhisperModelProfile>[
      WhisperModelProfile.tiny,
      WhisperModelProfile.base,
    ]);
  });
}
