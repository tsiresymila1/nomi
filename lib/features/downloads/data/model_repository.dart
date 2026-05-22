import 'package:drift/drift.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';

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

final modelRepositoryActionsProvider = Provider<ModelRepositoryActions>(
  (ref) => ModelRepositoryActions(ref),
);

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
