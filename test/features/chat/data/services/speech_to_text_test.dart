import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/services/speech_to_text.dart';
import 'package:gena/features/chat/data/services/unsupported_speech_to_text.dart';

/// Minimal fake proving the [SpeechToText] contract is fake-able for tests.
class _FakeSpeechToText implements SpeechToText {
  _FakeSpeechToText(this._result);

  final SttResult _result;
  bool ensureCalled = false;

  @override
  bool get isAvailable => true;

  @override
  Future<void> ensureModelReady() async {
    ensureCalled = true;
  }

  @override
  Future<SttResult> transcribe(String wavPath, {String lang = 'auto'}) async {
    return _result;
  }
}

void main() {
  group('UnsupportedSpeechToText', () {
    final stt = UnsupportedSpeechToText();

    test('is not available', () {
      expect(stt.isAvailable, isFalse);
    });

    test('ensureModelReady throws SpeechToTextException', () {
      expect(
        () => stt.ensureModelReady(),
        throwsA(isA<SpeechToTextException>()),
      );
    });

    test('transcribe throws SpeechToTextException', () {
      expect(
        () => stt.transcribe('audio.wav'),
        throwsA(isA<SpeechToTextException>()),
      );
    });
  });

  group('SpeechToText contract', () {
    test('a fake driver returns the configured result', () async {
      final fake = _FakeSpeechToText(
        const SttResult(text: 'hello world', language: 'en'),
      );

      expect(fake.isAvailable, isTrue);

      final result = await fake.transcribe('audio.wav');

      expect(result.text, 'hello world');
      expect(result.language, 'en');
    });
  });
}
