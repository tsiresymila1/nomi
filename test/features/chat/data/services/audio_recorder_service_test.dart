import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/services/audio_recorder_service.dart';
import 'package:record/record.dart';

void main() {
  group('AudioRecorderService.recordConfig', () {
    test('captures 16 kHz mono WAV (the format whisper requires)', () {
      const config = AudioRecorderService.recordConfig;

      expect(config.encoder, AudioEncoder.wav);
      expect(config.numChannels, 1);
      expect(config.sampleRate, 16000);
    });
  });
}
