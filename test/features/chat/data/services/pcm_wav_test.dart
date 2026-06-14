import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/services/pcm_wav.dart';

String _ascii(Uint8List bytes, int offset, int length) {
  return String.fromCharCodes(bytes.sublist(offset, offset + length));
}

void main() {
  group('encodePcm16Wav', () {
    test('emits a valid 44-byte RIFF/WAVE header for 16 kHz mono 16-bit', () {
      final wav = encodePcm16Wav(<double>[0.0, 0.0], sampleRate: 16000);
      final view = ByteData.view(wav.buffer);

      // Header (44 bytes) + 2 samples * 2 bytes.
      expect(wav.length, 44 + 4);

      expect(_ascii(wav, 0, 4), 'RIFF');
      // riffSize = 36 + dataSize(=4) = 40.
      expect(view.getUint32(4, Endian.little), 40);
      expect(_ascii(wav, 8, 4), 'WAVE');

      expect(_ascii(wav, 12, 4), 'fmt ');
      expect(view.getUint32(16, Endian.little), 16); // PCM fmt chunk size
      expect(view.getUint16(20, Endian.little), 1); // PCM format
      expect(view.getUint16(22, Endian.little), 1); // mono
      expect(view.getUint32(24, Endian.little), 16000); // sample rate
      expect(view.getUint32(28, Endian.little), 32000); // byte rate
      expect(view.getUint16(32, Endian.little), 2); // block align
      expect(view.getUint16(34, Endian.little), 16); // bits per sample

      expect(_ascii(wav, 36, 4), 'data');
      expect(view.getUint32(40, Endian.little), 4); // data size
    });

    test('produces the correct sample count and data size', () {
      final wav = encodePcm16Wav(List<double>.filled(100, 0.25));
      final view = ByteData.view(wav.buffer);

      expect(view.getUint32(40, Endian.little), 200); // 100 samples * 2 bytes
      expect(wav.length, 44 + 200);
    });

    test('honours a non-default sample rate in the header', () {
      final wav = encodePcm16Wav(<double>[0.0], sampleRate: 8000);
      final view = ByteData.view(wav.buffer);

      expect(view.getUint32(24, Endian.little), 8000); // sample rate
      expect(view.getUint32(28, Endian.little), 16000); // byte rate = 8000*2
    });

    test('scales normalised samples to signed 16-bit', () {
      final wav = encodePcm16Wav(<double>[0.0, 1.0, -1.0, 0.5]);
      final view = ByteData.view(wav.buffer);

      expect(view.getInt16(44, Endian.little), 0);
      expect(view.getInt16(46, Endian.little), 32767);
      expect(view.getInt16(48, Endian.little), -32767);
      expect(view.getInt16(50, Endian.little), (0.5 * 32767).round());
    });

    test('clamps out-of-range samples into [-32768, 32767]', () {
      final wav = encodePcm16Wav(<double>[2.0, -2.0, double.nan]);
      final view = ByteData.view(wav.buffer);

      expect(view.getInt16(44, Endian.little), 32767); // +2.0 clamped to +1.0
      expect(view.getInt16(46, Endian.little), -32767); // -2.0 clamped to -1.0
      expect(view.getInt16(48, Endian.little), 0); // NaN -> 0
    });

    test('handles an empty sample list (header only)', () {
      final wav = encodePcm16Wav(const <double>[]);
      final view = ByteData.view(wav.buffer);

      expect(wav.length, 44);
      expect(view.getUint32(40, Endian.little), 0); // data size
      expect(view.getUint32(4, Endian.little), 36); // riffSize = 36 + 0
    });
  });
}
