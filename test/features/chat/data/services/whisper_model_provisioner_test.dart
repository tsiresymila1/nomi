import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/models/whisper_model_profile.dart';
import 'package:gena/features/chat/data/services/whisper_model_provisioner.dart';

class _FakeDownloadClient implements WhisperModelDownloadClient {
  _FakeDownloadClient(this.downloadedFile);

  final File downloadedFile;
  int downloads = 0;
  int cancellations = 0;

  @override
  Future<WhisperDownloadedModel> download({
    required WhisperModelProfile profile,
    required void Function(double progress, String message) onProgress,
  }) async {
    downloads += 1;
    onProgress(0.4, 'Downloading ${profile.label} 40%');
    return WhisperDownloadedModel(
      path: downloadedFile.path,
      sizeBytes: await downloadedFile.length(),
    );
  }

  @override
  Future<bool> cancel(WhisperModelProfile profile) async {
    cancellations += 1;
    return true;
  }
}

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'gena_whisper_model_',
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('reuses an installed model without starting a download', () async {
    final target = File('${tempDirectory.path}/ggml-tiny.bin');
    await target.writeAsBytes(<int>[1, 2, 3]);
    final downloaded = File('${tempDirectory.path}/unused.bin');
    await downloaded.writeAsBytes(<int>[9]);
    final client = _FakeDownloadClient(downloaded);
    final provisioner = WhisperModelProvisioner(
      downloadClient: client,
      modelDirectoryProvider: () async => tempDirectory,
    );

    final path = await provisioner.ensureReady(WhisperModelProfile.tiny);

    expect(path, target.path);
    expect(client.downloads, 0);
  });

  test(
    'downloads with progress then moves the model to Whisper path',
    () async {
      final stagingDirectory = Directory('${tempDirectory.path}/models');
      await stagingDirectory.create();
      final downloaded = File('${stagingDirectory.path}/ggml-tiny.bin');
      await downloaded.writeAsBytes(<int>[1, 2, 3, 4]);
      final client = _FakeDownloadClient(downloaded);
      final progress = <double>[];
      final provisioner = WhisperModelProvisioner(
        downloadClient: client,
        modelDirectoryProvider: () async => tempDirectory,
      );

      final path = await provisioner.ensureReady(
        WhisperModelProfile.tiny,
        onProgress: (value, _) => progress.add(value),
      );

      expect(path, '${tempDirectory.path}/ggml-tiny.bin');
      expect(await File(path).readAsBytes(), <int>[1, 2, 3, 4]);
      expect(await downloaded.exists(), isFalse);
      expect(progress, contains(0.4));
      expect(progress.last, 1);
    },
  );

  test('concurrent requests share one foreground download', () async {
    final stagingDirectory = Directory('${tempDirectory.path}/models');
    await stagingDirectory.create();
    final downloaded = File('${stagingDirectory.path}/ggml-base.bin');
    await downloaded.writeAsBytes(<int>[5, 6]);
    final client = _FakeDownloadClient(downloaded);
    final provisioner = WhisperModelProvisioner(
      downloadClient: client,
      modelDirectoryProvider: () async => tempDirectory,
    );

    final first = provisioner.ensureReady(WhisperModelProfile.base);
    final second = provisioner.ensureReady(WhisperModelProfile.base);

    expect(await first, await second);
    expect(client.downloads, 1);
  });

  test('cancel delegates using the selected profile', () async {
    final downloaded = File('${tempDirectory.path}/unused.bin');
    await downloaded.writeAsBytes(<int>[1]);
    final client = _FakeDownloadClient(downloaded);
    final provisioner = WhisperModelProvisioner(
      downloadClient: client,
      modelDirectoryProvider: () async => tempDirectory,
    );

    expect(await provisioner.cancel(WhisperModelProfile.base), isTrue);
    expect(client.cancellations, 1);
  });
}
