import 'package:drift/drift.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/features/downloads/domain/model_info.dart';

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
            modelType: row.modelType,
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
    required String modelType,
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
            modelType: modelType,
            sourceType: sourceType,
            source: source,
          ),
        );
  }

  Future<void> deleteModel(int id) async {
    final database = ref.read(genaDatabaseProvider);
    await (database.delete(
      database.models,
    )..where((t) => t.id.equals(id))).go();
  }
}
