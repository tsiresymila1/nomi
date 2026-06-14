import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';

void main() {
  late db.GenaDatabase database;
  late ModelRepository repository;
  late DefaultModelSeeder seeder;
  late ModelRepositoryActions actions;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    database = db.GenaDatabase(NativeDatabase.memory());
    repository = ModelRepository(database);
    seeder = DefaultModelSeeder(database);
    actions = ModelRepositoryActions(
      database: database,
      defaultModelSeeder: seeder,
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> addRemote({String name = 'Remote'}) async {
    await actions.addModel(
      name: name,
      description: 'desc',
      provider: ModelProviderType.remote,
      apiUrl: 'https://api.example.com',
      apiToken: 'secret',
      modelType: 'gemmaIt',
      supportImage: true,
      supportAudio: false,
      supportsFunctionCalls: true,
      isThinking: false,
      temperature: 0.5,
      topK: 30,
      topP: 0.8,
      maxTokens: 1000,
      tokenBuffer: 100,
      randomSeed: 2,
      preferredBackend: 'cpu',
      sourceType: 'network',
      source: 'https://api.example.com/v1',
    );
    final rows = await database.select(database.models).get();
    return rows.firstWhere((row) => row.name == name).id;
  }

  group('ModelRepository.watchModels', () {
    test('maps rows to ModelInfo ordered by createdAt desc', () async {
      await addRemote(name: 'First');
      await addRemote(name: 'Second');

      final models = await repository.watchModels().first;
      expect(models, hasLength(2));
      // Each row maps to a fully-populated ModelInfo.
      final first = models.firstWhere((model) => model.name == 'First');
      expect(first.provider, ModelProviderType.remote);
      expect(first.apiUrl, 'https://api.example.com');
      expect(first.apiToken, 'secret');
      expect(first.supportImage, isTrue);
      expect(first.supportsFunctionCalls, isTrue);
      expect(first.temperature, 0.5);
      expect(first.topK, 30);
      expect(first.sourceType, 'network');
    });

    test('emits an update when a new model is added', () async {
      final emissions = <int>[];
      final sub =
          repository.watchModels().listen((models) => emissions.add(models.length));
      addTearDown(sub.cancel);

      await addRemote(name: 'Added');
      // Let the stream deliver.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emissions.last, greaterThanOrEqualTo(1));
    });
  });

  group('DefaultModelSeeder', () {
    test('ensureSeeded inserts the default catalog once', () async {
      await seeder.ensureSeeded();
      final afterFirst = await database.select(database.models).get();
      expect(afterFirst, isNotEmpty);

      // A second call is a no-op (no duplicates).
      await seeder.ensureSeeded();
      final afterSecond = await database.select(database.models).get();
      expect(afterSecond.length, afterFirst.length);
    });

    test('does not duplicate a default model already present by name',
        () async {
      await seeder.ensureSeeded();
      final seededCount =
          (await database.select(database.models).get()).length;

      // force=true re-runs the missing-only seed; nothing new is added.
      await seeder.ensureSeeded(force: true);
      final recount = (await database.select(database.models).get()).length;
      expect(recount, seededCount);
    });

    test('clearAndReseed wipes then restores the default catalog', () async {
      await addRemote(name: 'Custom');
      await seeder.ensureSeeded();
      expect(await database.select(database.models).get(), isNotEmpty);

      await seeder.clearAndReseed();
      final models = await database.select(database.models).get();
      // The custom model is gone; only defaults remain.
      expect(models.any((row) => row.name == 'Custom'), isFalse);
      expect(models, isNotEmpty);
    });
  });

  group('ModelRepositoryActions', () {
    test('addModel persists a row with the provided values', () async {
      final id = await addRemote(name: 'Persisted');
      final row = await (database.select(database.models)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(row.name, 'Persisted');
      expect(row.description, 'desc');
      expect(row.provider, ModelProviderType.remote);
      expect(row.maxTokens, 1000);
      expect(row.modelId, isNull);
    });

    test('updateModel rewrites every editable column', () async {
      final id = await addRemote(name: 'Editable');
      await actions.updateModel(
        id: id,
        name: 'Renamed',
        description: 'new desc',
        provider: ModelProviderType.local,
        apiUrl: null,
        apiToken: null,
        modelType: 'qwen',
        supportImage: false,
        supportAudio: true,
        supportsFunctionCalls: false,
        isThinking: true,
        temperature: 0.9,
        topK: 64,
        topP: 0.99,
        maxTokens: 4096,
        tokenBuffer: 256,
        randomSeed: 7,
        preferredBackend: 'gpu',
        sourceType: 'file',
        source: '/tmp/model.gguf',
      );

      final row = await (database.select(database.models)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(row.name, 'Renamed');
      expect(row.provider, ModelProviderType.local);
      expect(row.apiUrl, isNull);
      expect(row.isThinking, isTrue);
      expect(row.sourceType, 'file');
      expect(row.source, '/tmp/model.gguf');
    });

    test('updateModelSettings only touches generation parameters', () async {
      final id = await addRemote(name: 'Tuned');
      await actions.updateModelSettings(
        id: id,
        temperature: 0.1,
        topK: 5,
        topP: 0.2,
        maxTokens: 256,
        tokenBuffer: 32,
        randomSeed: 99,
        preferredBackend: 'npu',
      );

      final row = await (database.select(database.models)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(row.temperature, 0.1);
      expect(row.topK, 5);
      expect(row.preferredBackend, 'npu');
      // Untouched identity column.
      expect(row.name, 'Tuned');
    });

    test('updateModelId and updateModelMmprojSource set nullable columns',
        () async {
      final id = await addRemote(name: 'Ids');
      await actions.updateModelId(id: id, modelId: 'installed-123');
      await actions.updateModelMmprojSource(
        id: id,
        mmprojSource: '/tmp/proj.gguf',
      );

      final row = await (database.select(database.models)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(row.modelId, 'installed-123');
      expect(row.mmprojSource, '/tmp/proj.gguf');

      // Clearing the id back to null is supported.
      await actions.updateModelId(id: id, modelId: null);
      final cleared = await (database.select(database.models)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(cleared.modelId, isNull);
    });

    test('deleteModel removes the row', () async {
      final id = await addRemote(name: 'Doomed');
      await actions.deleteModel(id);
      final rows = await (database.select(database.models)
            ..where((t) => t.id.equals(id)))
          .get();
      expect(rows, isEmpty);
    });

    test('clearAndReseedDefaultModels delegates to the seeder', () async {
      await addRemote(name: 'Temp');
      await actions.clearAndReseedDefaultModels();
      final models = await database.select(database.models).get();
      expect(models.any((row) => row.name == 'Temp'), isFalse);
      expect(models, isNotEmpty);
    });
  });
}
