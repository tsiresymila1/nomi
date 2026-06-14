import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Encodes normalised [-1, 1] PCM [samples] into a complete 16-bit mono WAV
/// byte buffer (44-byte RIFF/WAVE header + PCM data).
///
/// Pure and side-effect-free so it can be unit-tested without touching disk:
/// out-of-range samples are clamped to [-1, 1] before scaling to signed 16-bit.
/// [sampleRate] defaults to 16 kHz mono — the format whisper expects.
Uint8List encodePcm16Wav(List<double> samples, {int sampleRate = 16000}) {
  const int channels = 1;
  const int bitsPerSample = 16;
  const int bytesPerSample = bitsPerSample ~/ 8;

  final int dataSize = samples.length * bytesPerSample;
  final int byteRate = sampleRate * channels * bytesPerSample;
  final int blockAlign = channels * bytesPerSample;
  final int riffSize = 36 + dataSize;

  final bytes = Uint8List(44 + dataSize);
  final view = ByteData.view(bytes.buffer);

  // RIFF chunk descriptor.
  _writeAscii(bytes, 0, 'RIFF');
  view.setUint32(4, riffSize, Endian.little);
  _writeAscii(bytes, 8, 'WAVE');

  // "fmt " sub-chunk.
  _writeAscii(bytes, 12, 'fmt ');
  view.setUint32(16, 16, Endian.little); // PCM fmt chunk size
  view.setUint16(20, 1, Endian.little); // audio format = PCM
  view.setUint16(22, channels, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, byteRate, Endian.little);
  view.setUint16(32, blockAlign, Endian.little);
  view.setUint16(34, bitsPerSample, Endian.little);

  // "data" sub-chunk.
  _writeAscii(bytes, 36, 'data');
  view.setUint32(40, dataSize, Endian.little);

  var offset = 44;
  for (final sample in samples) {
    final clamped = sample.isNaN ? 0.0 : sample.clamp(-1.0, 1.0);
    // Scale to signed 16-bit, then clamp the rounded int into range so +1.0
    // maps to 32767 rather than overflowing to 32768.
    final value = (clamped * 32767.0).round().clamp(-32768, 32767);
    view.setInt16(offset, value, Endian.little);
    offset += bytesPerSample;
  }

  return bytes;
}

void _writeAscii(Uint8List bytes, int offset, String value) {
  for (var i = 0; i < value.length; i++) {
    bytes[offset + i] = value.codeUnitAt(i);
  }
}

/// Writes [samples] as a temporary 16-bit mono WAV file and returns its path.
///
/// The caller owns the returned file (whisper reads it, then it can be deleted).
Future<String> writePcm16Wav(
  List<double> samples, {
  int sampleRate = 16000,
}) async {
  final bytes = encodePcm16Wav(samples, sampleRate: sampleRate);
  final tempDir = await getTemporaryDirectory();
  final path =
      '${tempDir.path}/vad_${DateTime.now().microsecondsSinceEpoch}.wav';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return path;
}
