import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/data/services/image_model_store.dart';
import 'package:gena/features/image_generation/data/services/image_model_store_io.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('gena_image_model_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'downloads, streams verification, and trusts a verified marker',
    () async {
      final bytes = <int>[1, 2, 3, 4];
      final profile = _profile(
        sizeBytes: bytes.length,
        digest: sha256.convert(bytes).toString(),
      );
      final downloader = _FakeDownloadClient(directory, bytes);
      var digestCalls = 0;
      final store = IoImageModelStore(
        downloadClient: downloader,
        modelsDirectoryProvider: () async => directory,
        digestProvider: (file) async {
          digestCalls++;
          return sha256.convert(await file.readAsBytes()).toString();
        },
      );
      final progress = <double>[];
      var verifying = false;

      final installed = await store.install(
        profile,
        onProgress: progress.add,
        onVerifying: () => verifying = true,
      );
      final resolved = await store.resolve(profile);

      expect(installed.modelPath, '${directory.path}/${profile.fileName}');
      expect(resolved?.modelPath, installed.modelPath);
      expect(verifying, isTrue);
      expect(progress.last, 1);
      expect(digestCalls, 1, reason: 'resolve should trust the SHA marker');
      expect(await File('${installed.modelPath}.sha256').exists(), isTrue);
    },
  );

  test('deletes a download with a mismatched checksum', () async {
    final profile = _profile(
      sizeBytes: 4,
      digest: List<String>.filled(64, '0').join(),
    );
    final downloader = _FakeDownloadClient(directory, <int>[1, 2, 3, 4]);
    final store = IoImageModelStore(
      downloadClient: downloader,
      modelsDirectoryProvider: () async => directory,
    );

    await expectLater(
      store.install(profile, onProgress: (_) {}, onVerifying: () {}),
      throwsA(isA<ImageModelIntegrityException>()),
    );

    expect(
      await File('${directory.path}/${profile.fileName}').exists(),
      isFalse,
    );
  });

  test('removes the model and its verification marker', () async {
    final bytes = <int>[1, 2, 3, 4];
    final profile = _profile(
      sizeBytes: bytes.length,
      digest: sha256.convert(bytes).toString(),
    );
    final downloader = _FakeDownloadClient(directory, bytes);
    final store = IoImageModelStore(
      downloadClient: downloader,
      modelsDirectoryProvider: () async => directory,
    );
    await store.install(profile, onProgress: (_) {}, onVerifying: () {});

    await store.delete(profile);

    expect(
      await File('${directory.path}/${profile.fileName}').exists(),
      isFalse,
    );
    expect(
      await File('${directory.path}/${profile.fileName}.sha256').exists(),
      isFalse,
    );
    expect(downloader.cancelCalls, 1);
  });
}

ImageModelProfile _profile({required int sizeBytes, required String digest}) =>
    ImageModelProfile(
      id: 'tiny',
      name: 'Tiny',
      description: 'Fixture',
      url: 'https://example.test/tiny.gguf',
      fileName: 'tiny.gguf',
      sizeBytes: sizeBytes,
      sha256: digest,
      steps: 1,
      guidanceScale: 1,
    );

class _FakeDownloadClient implements ImageModelDownloadClient {
  _FakeDownloadClient(this.directory, this.bytes);

  final Directory directory;
  final List<int> bytes;
  int cancelCalls = 0;

  @override
  Future<void> cancel(ImageModelProfile profile) async {
    cancelCalls++;
  }

  @override
  Future<DownloadedImageModelFile> download(
    ImageModelProfile profile, {
    required void Function(double progress) onProgress,
  }) async {
    final file = File('${directory.path}/${profile.fileName}');
    await file.writeAsBytes(bytes, flush: true);
    onProgress(0.5);
    return DownloadedImageModelFile(path: file.path, sizeBytes: bytes.length);
  }
}
