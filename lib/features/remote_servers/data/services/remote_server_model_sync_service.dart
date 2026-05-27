import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_entry.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_model_spec.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final remoteServerModelSyncServiceProvider =
    Provider<RemoteServerModelSyncService>(
      (ref) => RemoteServerModelSyncService(ref),
    );

class RemoteServerModelSyncService {
  RemoteServerModelSyncService(this._ref);

  final Ref _ref;

  static String sourceForModel({
    required String serverId,
    required String modelId,
  }) {
    final encoded = Uri.encodeComponent(modelId);
    return 'remote-server://$serverId/$encoded';
  }

  static String sourcePrefixForServer(String serverId) {
    return 'remote-server://$serverId/';
  }

  Future<int> syncServerModels({
    required RemoteServerEntry server,
    required String effectiveApiBaseUrl,
    required List<RemoteServerModelSpec> models,
  }) async {
    final database = _ref.read(genaDatabaseProvider);
    final seenSources = <String>{};

    for (final remoteModel in models) {
      final source = sourceForModel(
        serverId: server.id,
        modelId: remoteModel.id,
      );
      seenSources.add(source);
      final existing = await _findModelBySource(database, source);
      final companion = _toCompanion(
        server: server,
        effectiveApiBaseUrl: effectiveApiBaseUrl,
        model: remoteModel,
        source: source,
      );

      if (existing == null) {
        await database.into(database.models).insert(companion);
      } else {
        await (database.update(
          database.models,
        )..where((t) => t.id.equals(existing.id))).write(companion);
      }
    }

    await _removeStaleModelsForServer(
      database: database,
      serverId: server.id,
      validSources: seenSources,
    );

    return models.length;
  }

  Future<void> deleteAllModelsForServer(String serverId) async {
    final database = _ref.read(genaDatabaseProvider);
    final prefix = sourcePrefixForServer(serverId);
    await (database.delete(
      database.models,
    )..where((t) => t.source.like('$prefix%'))).go();
  }

  Future<db.Model?> _findModelBySource(
    db.GenaDatabase database,
    String source,
  ) {
    return (database.select(
      database.models,
    )..where((t) => t.source.equals(source))).getSingleOrNull();
  }

  db.ModelsCompanion _toCompanion({
    required RemoteServerEntry server,
    required String effectiveApiBaseUrl,
    required RemoteServerModelSpec model,
    required String source,
  }) {
    final normalizedModelId = model.id.trim();
    final context = model.contextLength ?? 8192;
    final tokenBuffer = context > 2048 ? 2048 : context;
    final modelType = _inferModelType(normalizedModelId);

    return db.ModelsCompanion(
      name: Value('${server.name} · ${model.displayName}'),
      description: Value('Remote model from ${server.baseUrl}'),
      modelId: Value(normalizedModelId),
      provider: const Value(ModelProviderType.remote),
      apiUrl: Value(effectiveApiBaseUrl),
      apiToken: Value(server.token.trim()),
      modelType: Value(modelType),
      supportImage: Value(_supportsImage(model.raw, normalizedModelId)),
      supportAudio: Value(_supportsAudio(model.raw, normalizedModelId)),
      supportsFunctionCalls: Value(_supportsToolCalls(normalizedModelId)),
      isThinking: Value(_isThinkingModel(normalizedModelId)),
      temperature: const Value(0.7),
      topK: const Value(40),
      topP: const Value(0.95),
      maxTokens: Value(context),
      tokenBuffer: Value(tokenBuffer <= 0 ? 512 : tokenBuffer),
      randomSeed: const Value(1),
      preferredBackend: const Value('gpu'),
      sourceType: const Value('remote'),
      source: Value(source),
    );
  }

  Future<void> _removeStaleModelsForServer({
    required db.GenaDatabase database,
    required String serverId,
    required Set<String> validSources,
  }) async {
    final prefix = sourcePrefixForServer(serverId);
    final existingRows = await (database.select(
      database.models,
    )..where((t) => t.source.like('$prefix%'))).get();

    for (final row in existingRows) {
      if (validSources.contains(row.source)) continue;
      await (database.delete(
        database.models,
      )..where((t) => t.id.equals(row.id))).go();
    }
  }

  String _inferModelType(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('gemma4')) return 'gemma4';
    if (lower.contains('gemma')) return 'gemmaIt';
    if (lower.contains('deepseek') || lower.contains('r1')) return 'deepSeek';
    if (lower.contains('qwen3')) return 'qwen3';
    if (lower.contains('qwen')) return 'qwen';
    if (lower.contains('llama')) return 'llama';
    if (lower.contains('phi')) return 'phi';
    return 'general';
  }

  bool _supportsImage(Map<String, dynamic> raw, String modelId) {
    final lower = modelId.toLowerCase();
    if (lower.contains('vision') ||
        lower.contains('vl') ||
        lower.contains('image')) {
      return true;
    }

    final modalities = raw['modalities'];
    if (modalities is List) {
      return modalities
          .map((item) => item.toString().toLowerCase())
          .contains('image');
    }
    return false;
  }

  bool _supportsAudio(Map<String, dynamic> raw, String modelId) {
    final lower = modelId.toLowerCase();
    if (lower.contains('audio')) return true;

    final modalities = raw['modalities'];
    if (modalities is List) {
      return modalities
          .map((item) => item.toString().toLowerCase())
          .contains('audio');
    }
    return false;
  }

  bool _supportsToolCalls(String modelId) {
    final lower = modelId.toLowerCase();
    return lower.contains('gpt') ||
        lower.contains('qwen') ||
        lower.contains('llama') ||
        lower.contains('gemma') ||
        lower.contains('deepseek');
  }

  bool _isThinkingModel(String modelId) {
    final lower = modelId.toLowerCase();
    return lower.contains('reason') ||
        lower.contains('thinking') ||
        lower.contains('r1') ||
        lower.contains('o1');
  }
}
