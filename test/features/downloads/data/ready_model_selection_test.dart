import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/downloads/data/local_model_files.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/data/ready_model_selection.dart';

void main() {
  final remote = _model(id: 2, provider: ModelProviderType.remote);
  final local = _model(
    id: 1,
    provider: ModelProviderType.local,
    source: '/models/local.gguf',
  );

  test('remote-only installed-model load never calls local registry', () async {
    var registryCalled = false;

    final installed = await loadInstalledModelsIfSupported(
      capabilities: AppCapabilities.forPlatform(AppPlatform.web),
      loadInstalledModels: () async {
        registryCalled = true;
        throw StateError('local registry unavailable');
      },
    );

    expect(installed, isEmpty);
    expect(registryCalled, isFalse);
  });

  test('remote-only ready models contain only remote catalog entries', () {
    final ready = readyModelsForCapabilities(
      models: [local, remote],
      installedModels: [localModelIdForPath(local.source)],
      capabilities: AppCapabilities.forPlatform(AppPlatform.windows),
    );

    expect(ready.map((model) => model.id), [remote.id]);
  });

  test('native ready models preserve installed local and remote entries', () {
    final ready = readyModelsForCapabilities(
      models: [local, remote],
      installedModels: [localModelIdForPath(local.source)],
      capabilities: AppCapabilities.forPlatform(AppPlatform.android),
    );

    expect(ready.map((model) => model.id), [local.id, remote.id]);
  });

  test('native automatic selection never falls back to remote', () {
    expect(
      automaticReadyModelForPlatform(
        readyModels: [remote],
        supportsLocalModels: true,
      ),
      isNull,
    );
    expect(
      automaticReadyModelForPlatform(
        readyModels: [remote, local],
        supportsLocalModels: true,
      )?.id,
      local.id,
    );
  });

  test('remote-only platform may automatically select a remote model', () {
    expect(
      automaticReadyModelForPlatform(
        readyModels: [remote],
        supportsLocalModels: false,
      )?.id,
      remote.id,
    );
  });
}

ModelInfo _model({
  required int id,
  required String provider,
  String source = 'remote-server://server/model',
}) {
  return ModelInfo(
    id: id,
    name: 'Model $id',
    description: '',
    provider: provider,
    modelType: 'gemmaIt',
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
    sourceType: provider == ModelProviderType.local ? 'file' : 'remote',
    source: source,
  );
}
