import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/downloads/data/local_model_files.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';

void main() {
  group('local model source compatibility', () {
    test('supports gguf and litertlm case-insensitively', () {
      expect(isCompatibleLocalModelSource('/models/assistant.GGUF'), isTrue);
      expect(
        isCompatibleLocalModelSource('/models/assistant.LiteRTLM'),
        isTrue,
      );
    });

    test('uses a network URL path when query and fragment are present', () {
      expect(
        isCompatibleLocalModelSource(
          'https://example.com/models/assistant.GGUF?download=1#release',
        ),
        isTrue,
      );
      expect(
        isCompatibleLocalModelSource(
          'https://example.com/models/assistant.LiteRTLM?download=1#release',
        ),
        isTrue,
      );
    });

    test(
      'rejects task and unknown extensions with actionable explanations',
      () {
        expect(
          localModelSourceValidationError(
            'https://example.com/models/assistant.task?download=1#release',
          ),
          allOf(contains('.task'), contains('.gguf'), contains('.litertlm')),
        );
        expect(
          localModelSourceValidationError('/models/assistant.bin'),
          allOf(contains('.bin'), contains('.gguf'), contains('.litertlm')),
        );
      },
    );
  });

  group('local model identity', () {
    test('derives a stable ID from a normalized canonical path', () {
      expect(
        localModelIdForPath('/models/team/../assistant/model.gguf'),
        localModelIdForPath('/models/assistant/model.gguf'),
      );
    });

    test('avoids collisions for files with the same basename', () {
      expect(
        localModelIdForPath('/models/alpha/model.gguf'),
        isNot(localModelIdForPath('/models/beta/model.gguf')),
      );
    });

    test('recognizes only paths inside the app-owned model directory', () {
      expect(
        isPathWithinDirectory(
          path: '/app/support/models/team/model.gguf',
          directory: '/app/support/models',
        ),
        isTrue,
      );
      expect(
        isPathWithinDirectory(
          path: '/app/support/models-other/model.gguf',
          directory: '/app/support/models',
        ),
        isFalse,
      );
    });
  });

  test(
    'installed discovery reports only existing compatible local catalog files',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'local_model_files_test_',
      );
      addTearDown(() => tempDirectory.delete(recursive: true));

      final gguf = await File(
        '${tempDirectory.path}/assistant.gguf',
      ).writeAsString('gguf');
      final litertlm = await File(
        '${tempDirectory.path}/assistant.litertlm',
      ).writeAsString('litertlm');
      final task = await File(
        '${tempDirectory.path}/legacy.task',
      ).writeAsString('task');
      final remoteFile = await File(
        '${tempDirectory.path}/remote.gguf',
      ).writeAsString('remote');

      final repository = _ModelRepositoryFake([
        _model(id: 1, source: gguf.path),
        _model(id: 2, source: litertlm.uri.toString()),
        _model(id: 3, source: task.path),
        _model(id: 4, source: '${tempDirectory.path}/missing.gguf'),
        _model(
          id: 5,
          provider: ModelProviderType.remote,
          sourceType: 'remote',
          source: remoteFile.path,
        ),
        _model(
          id: 6,
          sourceType: 'network',
          source: 'https://example.com/model.gguf',
        ),
      ]);

      final installed = await ModelInstallerService(
        repository,
      ).listInstalledModels();

      expect(installed, {
        localModelIdForPath(gguf.path),
        localModelIdForPath(litertlm.path),
      });
    },
  );
}

ModelInfo _model({
  required int id,
  String provider = ModelProviderType.local,
  String sourceType = 'file',
  required String source,
}) {
  return ModelInfo(
    id: id,
    name: 'Model $id',
    description: '',
    provider: provider,
    modelType: 'llama',
    supportImage: false,
    supportAudio: false,
    supportsFunctionCalls: false,
    isThinking: false,
    temperature: 0.7,
    topK: 40,
    topP: 0.95,
    maxTokens: 4096,
    tokenBuffer: 256,
    randomSeed: 1,
    preferredBackend: 'cpu',
    sourceType: sourceType,
    source: source,
  );
}

class _ModelRepositoryFake extends Fake implements ModelRepository {
  _ModelRepositoryFake(this.models);

  final List<ModelInfo> models;

  @override
  Stream<List<ModelInfo>> watchModels() => Stream.value(models);
}
