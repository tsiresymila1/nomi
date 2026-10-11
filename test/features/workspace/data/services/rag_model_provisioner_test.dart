import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/downloads/data/services/model_background_download_service.dart';
import 'package:gena/features/workspace/data/services/rag_model_provisioner.dart';

void main() {
  test(
    'downloads both RAG assets through the background model service',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nomi_rag_provisioner_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final downloadedKeys = <String>[];
      final statuses = <String>[];

      final provisioner = RagModelProvisioner(
        directoryProvider: () async => directory,
        download:
            ({
              required modelKey,
              required modelName,
              required sourceUrl,
              onProgress,
            }) async {
              downloadedKeys.add(modelKey);
              onProgress?.call(0.5, 'halfway');
              final isTokenizer = sourceUrl.endsWith('tokenizer.json');
              final sizeBytes = isTokenizer ? 466247 : 23026053;
              final file = File(
                '${directory.path}/download_${downloadedKeys.length}.part',
              );
              final handle = await file.open(mode: FileMode.write);
              await handle.truncate(sizeBytes);
              await handle.close();
              return DownloadedModelFile(
                path: file.path,
                fileName: file.uri.pathSegments.last,
                sizeBytes: sizeBytes,
              );
            },
        digestProvider: (file) async => await file.length() == 466247
            ? 'be50c3628f2bf5bb5e3a7f17b1f74611b2561a3a27eeab05e5aa30f411572037'
            : '4278337fd0ff3c68bfb6291042cad8ab363e1d9fbc43dcb499fe91c871902474',
      );

      await provisioner.ensure(onProgress: statuses.add);
      await provisioner.ensure(onProgress: statuses.add);

      expect(downloadedKeys, [
        'workspace-rag:tokenizer.json',
        'workspace-rag:model.onnx',
      ]);
      expect(await File('${directory.path}/tokenizer.json').length(), 466247);
      expect(await File('${directory.path}/model.onnx').length(), 23026053);
      expect(statuses, contains('Downloading Workspace RAG tokenizer 50%'));
      expect(statuses, contains('Verifying Workspace RAG model...'));
    },
  );
}
