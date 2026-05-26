import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:smart_background_tasks/smart_background_tasks.dart';

final modelRepositoryProvider = StreamProvider<List<ModelInfo>>((ref) {
  final database = ref.watch(genaDatabaseProvider);
  final query = database.select(database.models)
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
        .toList(),
  );
});

final modelInstallerProvider = FutureProvider<List<String>>((ref) async {
  return await FlutterGemma.listInstalledModels();
});

final defaultModelSeedingProvider = Provider<void>((ref) {
  unawaited(ref.read(defaultModelSeederProvider).ensureSeeded());
});

final defaultModelSeederProvider = Provider<DefaultModelSeeder>(
  (ref) => DefaultModelSeeder(ref),
);

final modelRepositoryActionsProvider = Provider<ModelRepositoryActions>(
  (ref) => ModelRepositoryActions(ref),
);

class DefaultModelSeeder {
  final Ref ref;
  bool _seeded = false;
  Future<void>? _inFlight;

  DefaultModelSeeder(this.ref);

  Future<void> ensureSeeded() async {
    if (_seeded) return;
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

  Future<void> _seedMissingDefaultModels() async {
    final database = ref.read(genaDatabaseProvider);
    final existingRows = await database.select(database.models).get();

    final existingNames = existingRows
        .map((row) => _normalizeModelIdentity(row.name))
        .toSet();
    final existingSources = existingRows
        .map((row) => _normalizeModelIdentity(row.source))
        .toSet();

    for (final defaultModel in kDefaultFlutterGemmaModelSources) {
      final normalizedName = _normalizeModelIdentity(defaultModel.name);
      final normalizedSource = _normalizeModelIdentity(defaultModel.url);
      final alreadyExists =
          existingNames.contains(normalizedName) ||
          existingSources.contains(normalizedSource);
      if (alreadyExists) continue;

      await database
          .into(database.models)
          .insert(
            db.ModelsCompanion.insert(
              name: defaultModel.name,
              description: defaultModel.notes,
              modelId: const Value.absent(),
              provider: const Value(ModelProviderType.local),
              apiUrl: const Value.absent(),
              apiToken: const Value.absent(),
              modelType: _resolveModelTypeForDefault(defaultModel.name),
              supportImage: const Value(false),
              supportAudio: const Value(false),
              supportsFunctionCalls: const Value(false),
              isThinking: const Value(false),
              temperature: const Value(0.8),
              topK: const Value(40),
              topP: const Value(0.95),
              maxTokens: const Value(2048),
              tokenBuffer: const Value(256),
              randomSeed: const Value(1),
              preferredBackend: const Value('gpu'),
              sourceType: 'network',
              source: defaultModel.url,
            ),
          );

      existingNames.add(normalizedName);
      existingSources.add(normalizedSource);
    }
  }
}

String _resolveModelTypeForDefault(String modelName) {
  final normalized = _normalizeModelIdentity(modelName);
  if (normalized.contains('qwen3')) return ModelType.qwen3.name;
  if (normalized.contains('deepseek')) return ModelType.deepSeek.name;
  return ModelType.gemma4.name;
}

String _normalizeModelIdentity(String value) {
  return value.trim().toLowerCase();
}

class ModelRepositoryActions {
  final Ref ref;
  ModelRepositoryActions(this.ref);

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
    final database = ref.read(genaDatabaseProvider);
    await database
        .into(database.models)
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
    final database = ref.read(genaDatabaseProvider);
    await (database.update(
      database.models,
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
    final database = ref.read(genaDatabaseProvider);
    await (database.update(
      database.models,
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
    final database = ref.read(genaDatabaseProvider);
    await (database.delete(
      database.models,
    )..where((t) => t.id.equals(id))).go();
  }

  Future<void> updateModelId({required int id, required String modelId}) async {
    final database = ref.read(genaDatabaseProvider);
    await (database.update(database.models)..where((t) => t.id.equals(id)))
        .write(db.ModelsCompanion(modelId: Value(modelId)));
  }
}
