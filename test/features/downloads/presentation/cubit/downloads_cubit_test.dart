import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/presentation/cubit/downloads_cubit.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

const _webCapabilities = AppCapabilities(
  platform: AppPlatform.web,
  supportsRemoteModels: true,
  supportsLocalModels: false,
  supportsWorkspaceRag: false,
  supportsSpeechToText: false,
  supportsTextToSpeech: false,
  supportsMcp: true,
);

ModelInfo _model({
  required int id,
  required String name,
  String provider = ModelProviderType.remote,
  String sourceType = 'network',
  String source = 'https://example.com/model',
  String? modelId,
}) {
  return ModelInfo(
    id: id,
    name: name,
    description: '',
    modelId: modelId,
    provider: provider,
    modelType: 'gemmaIt',
    supportImage: false,
    supportAudio: false,
    supportsFunctionCalls: false,
    isThinking: false,
    temperature: 0.7,
    topK: 40,
    topP: 0.95,
    maxTokens: 2048,
    tokenBuffer: 256,
    randomSeed: 1,
    preferredBackend: 'gpu',
    sourceType: sourceType,
    source: source,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Fluttertoast talks to a platform channel that has no backend in tests; stub
  // it so AppToast.show calls resolve instead of throwing.
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  late db.GenaDatabase database;
  late ModelRepository repository;
  late DefaultModelSeeder seeder;
  late ModelRepositoryActions actions;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, (call) async => true);
    database = db.GenaDatabase(NativeDatabase.memory());
    repository = ModelRepository(database);
    seeder = DefaultModelSeeder(database);
    actions = ModelRepositoryActions(
      database: database,
      defaultModelSeeder: seeder,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, null);
    await database.close();
  });

  Future<DownloadsCubit> buildCubit() async {
    final cubit = DownloadsCubit(
      modelRepository: repository,
      modelInstallerService: ModelInstallerService(repository),
      modelRepositoryActions: actions,
      defaultModelSeeder: seeder,
      capabilities: _webCapabilities,
    );
    // Let _init seed + subscribe.
    await _settle();
    await _settle();
    return cubit;
  }

  group('initialization (no local support)', () {
    test('seeds models and reports an empty installed list', () async {
      final cubit = await buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.models, isNotEmpty);
      expect(cubit.state.installedModels, isEmpty);
      expect(cubit.state.errorMessage, isNull);
    });
  });

  group('install key helpers', () {
    test('installKeyForModel derives a stable per-id key', () async {
      final cubit = await buildCubit();
      addTearDown(cubit.close);

      expect(cubit.installKeyForModel(_model(id: 12, name: 'A')), 'model_12');
    });

    test('installedIdForModel uses modelId or source for non-file models',
        () async {
      final cubit = await buildCubit();
      addTearDown(cubit.close);

      expect(
        cubit.installedIdForModel(
          _model(id: 1, name: 'A', modelId: 'resolved-id'),
        ),
        'resolved-id',
      );
      expect(
        cubit.installedIdForModel(
          _model(id: 1, name: 'A', source: 'https://x/y'),
        ),
        'https://x/y',
      );
    });
  });

  group('installModel guards', () {
    test('is a no-op for remote models', () async {
      final cubit = await buildCubit();
      addTearDown(cubit.close);

      final before = cubit.state;
      await cubit.installModel(
        _model(id: 1, name: 'Remote', provider: ModelProviderType.remote),
      );
      // No active install, no progress, no error created.
      expect(cubit.state.activeInstall, isNull);
      expect(cubit.state.progressByKey, before.progressByKey);
    });

    test('reports the unavailable message for local models on web', () async {
      final cubit = await buildCubit();
      addTearDown(cubit.close);

      await cubit.installModel(
        _model(
          id: 2,
          name: 'Local',
          provider: ModelProviderType.local,
          sourceType: 'file',
          source: '/tmp/model.gguf',
        ),
      );
      expect(
        cubit.state.errorMessage,
        _webCapabilities.localModelsUnavailableMessage,
      );
      expect(cubit.state.activeInstall, isNull);
    });
  });

  group('removeModel', () {
    test('deletes a remote model entry from the catalog', () async {
      // Insert a custom remote model (not a default static one).
      await actions.addModel(
        name: 'Removable Remote',
        description: '',
        provider: ModelProviderType.remote,
        modelType: 'gemmaIt',
        supportImage: false,
        supportAudio: false,
        supportsFunctionCalls: false,
        isThinking: false,
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxTokens: 2048,
        tokenBuffer: 256,
        randomSeed: 1,
        preferredBackend: 'gpu',
        sourceType: 'network',
        source: 'https://custom.example.com/remote',
      );
      final cubit = await buildCubit();
      addTearDown(cubit.close);

      final row = (await database.select(database.models).get())
          .firstWhere((model) => model.name == 'Removable Remote');

      await cubit.removeModel(
        _model(
          id: row.id,
          name: 'Removable Remote',
          provider: ModelProviderType.remote,
          source: 'https://custom.example.com/remote',
        ),
      );
      await _settle();

      final remaining = await (database.select(database.models)
            ..where((t) => t.id.equals(row.id)))
          .get();
      expect(remaining, isEmpty);
    });

    test('refuses to delete a default static model', () async {
      await seeder.ensureSeeded();
      final cubit = await buildCubit();
      addTearDown(cubit.close);

      final staticRow =
          (await database.select(database.models).get()).first;
      final countBefore =
          (await database.select(database.models).get()).length;

      await cubit.removeModel(
        _model(
          id: staticRow.id,
          name: staticRow.name,
          provider: ModelProviderType.local,
          sourceType: staticRow.sourceType,
          source: staticRow.source,
        ),
      );
      await _settle();

      final countAfter = (await database.select(database.models).get()).length;
      expect(countAfter, countBefore);
    });
  });

  group('resetSeedModels', () {
    test('reseeds default models', () async {
      final cubit = await buildCubit();
      addTearDown(cubit.close);

      await cubit.resetSeedModels();
      await _settle();
      expect(await database.select(database.models).get(), isNotEmpty);
    });
  });
}
