import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/downloads/data/default_seed_models.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';

class ModelRepository {
  ModelRepository(this._database);

  final db.GenaDatabase _database;

  Stream<List<ModelInfo>> watchModels() {
    final query = _database.select(_database.models)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ModelInfo(
              id: row.id,
              name: row.name,
              description: row.description,
              modelId: row.modelId,
              provider: row.provider,
              apiUrl: row.apiUrl,
              apiToken: row.apiToken,
              modelType: row.modelType,
              supportImage: row.supportImage,
              supportAudio: row.supportAudio,
              supportsFunctionCalls: row.supportsFunctionCalls,
              isThinking: row.isThinking,
              temperature: row.temperature,
              topK: row.topK,
              topP: row.topP,
              maxTokens: row.maxTokens,
              tokenBuffer: row.tokenBuffer,
              randomSeed: row.randomSeed,
              preferredBackend: row.preferredBackend,
              sourceType: row.sourceType,
              source: row.source,
            ),
          )
          .toList(growable: false),
    );
  }
}

class ModelInstallerService {
  const ModelInstallerService();

  Future<List<String>> listInstalledModels() {
    return gemma.FlutterGemma.listInstalledModels();
  }
}

class DefaultModelSeeder {
  DefaultModelSeeder(this._database);

  final db.GenaDatabase _database;
  bool _seeded = false;
  Future<void>? _inFlight;

  Future<void> ensureSeeded({bool force = false}) async {
    if (_seeded && !force) return;
    final currentTask = _inFlight;
    if (currentTask != null) {
      await currentTask;
      return;
    }

    final completer = Completer<void>();
    _inFlight = completer.future;
    try {
      await _seedMissingDefaultModels();
      _seeded = true;
    } finally {
      completer.complete();
      if (identical(_inFlight, completer.future)) {
        _inFlight = null;
      }
    }
  }

  Future<void> clearAndReseed() async {
    await _database.delete(_database.models).go();
    _seeded = false;
    await ensureSeeded(force: true);
  }

  Future<void> _seedMissingDefaultModels() async {
    final existingRows = await _database.select(_database.models).get();

    final existingNames = existingRows
        .map((row) => _normalizeModelIdentity(row.name))
        .toSet();
    final existingSources = existingRows
        .map((row) => _normalizeModelIdentity(row.source))
        .toSet();

    for (final defaultModel in kDefaultSeedModels) {
      final normalizedName = _normalizeModelIdentity(defaultModel.displayName);
      final normalizedSource = _normalizeModelIdentity(defaultModel.sourceUrl);
      final alreadyExists =
          existingNames.contains(normalizedName) ||
          existingSources.contains(normalizedSource);
      if (alreadyExists) continue;

      await _database
          .into(_database.models)
          .insert(
            db.ModelsCompanion.insert(
              name: defaultModel.displayName,
              description: defaultModel.notes,
              modelId: const Value.absent(),
              provider: const Value(ModelProviderType.local),
              apiUrl: const Value.absent(),
              apiToken: const Value.absent(),
              modelType: defaultModel.modelType.name,
              supportImage: Value(defaultModel.supportImage),
              supportAudio: Value(defaultModel.supportAudio),
              supportsFunctionCalls: Value(defaultModel.supportsFunctionCalls),
              isThinking: Value(defaultModel.isThinking),
              temperature: Value(defaultModel.temperature),
              topK: Value(defaultModel.topK),
              topP: Value(defaultModel.topP),
              maxTokens: Value(defaultModel.maxTokens),
              tokenBuffer: const Value(256),
              randomSeed: const Value(1),
              preferredBackend: Value(defaultModel.preferredBackend.name),
              sourceType: 'file',
              source: defaultModel.sourceUrl,
            ),
          );

      existingNames.add(normalizedName);
      existingSources.add(normalizedSource);
    }
  }
}

String _normalizeModelIdentity(String value) {
  return value.trim().toLowerCase();
}

class ModelRepositoryActions {
  ModelRepositoryActions({
    required db.GenaDatabase database,
    required DefaultModelSeeder defaultModelSeeder,
  }) : _database = database,
       _defaultModelSeeder = defaultModelSeeder;

  final db.GenaDatabase _database;
  final DefaultModelSeeder _defaultModelSeeder;

  Future<void> addModel({
    required String name,
    required String description,
    required String provider,
    String? apiUrl,
    String? apiToken,
    required String modelType,
    required bool supportImage,
    required bool supportAudio,
    required bool supportsFunctionCalls,
    required bool isThinking,
    required double temperature,
    required int topK,
    required double topP,
    required int maxTokens,
    required int tokenBuffer,
    required int randomSeed,
    required String preferredBackend,
    required String sourceType,
    required String source,
  }) async {
    await _database
        .into(_database.models)
        .insert(
          db.ModelsCompanion.insert(
            name: name,
            description: description,
            modelId: const Value.absent(),
            provider: Value(provider),
            apiUrl: Value(apiUrl),
            apiToken: Value(apiToken),
            modelType: modelType,
            supportImage: Value(supportImage),
            supportAudio: Value(supportAudio),
            supportsFunctionCalls: Value(supportsFunctionCalls),
            isThinking: Value(isThinking),
            temperature: Value(temperature),
            topK: Value(topK),
            topP: Value(topP),
            maxTokens: Value(maxTokens),
            tokenBuffer: Value(tokenBuffer),
            randomSeed: Value(randomSeed),
            preferredBackend: Value(preferredBackend),
            sourceType: sourceType,
            source: source,
          ),
        );
  }

  Future<void> updateModelSettings({
    required int id,
    required double temperature,
    required int topK,
    required double topP,
    required int maxTokens,
    required int tokenBuffer,
    required int randomSeed,
    required String preferredBackend,
  }) async {
    await (_database.update(
      _database.models,
    )..where((t) => t.id.equals(id))).write(
      db.ModelsCompanion(
        temperature: Value(temperature),
        topK: Value(topK),
        topP: Value(topP),
        maxTokens: Value(maxTokens),
        tokenBuffer: Value(tokenBuffer),
        randomSeed: Value(randomSeed),
        preferredBackend: Value(preferredBackend),
      ),
    );
  }

  Future<void> updateModel({
    required int id,
    required String name,
    required String description,
    required String provider,
    String? apiUrl,
    String? apiToken,
    required String modelType,
    required bool supportImage,
    required bool supportAudio,
    required bool supportsFunctionCalls,
    required bool isThinking,
    required double temperature,
    required int topK,
    required double topP,
    required int maxTokens,
    required int tokenBuffer,
    required int randomSeed,
    required String preferredBackend,
    required String sourceType,
    required String source,
  }) async {
    await (_database.update(
      _database.models,
    )..where((t) => t.id.equals(id))).write(
      db.ModelsCompanion(
        name: Value(name),
        description: Value(description),
        provider: Value(provider),
        apiUrl: Value(apiUrl),
        apiToken: Value(apiToken),
        modelType: Value(modelType),
        supportImage: Value(supportImage),
        supportAudio: Value(supportAudio),
        supportsFunctionCalls: Value(supportsFunctionCalls),
        isThinking: Value(isThinking),
        temperature: Value(temperature),
        topK: Value(topK),
        topP: Value(topP),
        maxTokens: Value(maxTokens),
        tokenBuffer: Value(tokenBuffer),
        randomSeed: Value(randomSeed),
        preferredBackend: Value(preferredBackend),
        sourceType: Value(sourceType),
        source: Value(source),
      ),
    );
  }

  Future<void> deleteModel(int id) async {
    await (_database.delete(
      _database.models,
    )..where((t) => t.id.equals(id))).go();
  }

  Future<void> updateModelId({required int id, required String modelId}) async {
    await (_database.update(_database.models)..where((t) => t.id.equals(id)))
        .write(db.ModelsCompanion(modelId: Value(modelId)));
  }

  Future<void> clearAndReseedDefaultModels() async {
    await _defaultModelSeeder.clearAndReseed();
  }
}
