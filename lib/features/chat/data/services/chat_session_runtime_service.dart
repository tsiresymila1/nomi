import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/logger.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/downloads/data/services/model_background_download_service.dart';
import 'package:gena/features/setting/data/chat_model_settings.dart';

Future<gemma.InferenceModel?> loadActiveModelWithRecovery({
  required List<String> installedModels,
  required List<db.Model> catalogModels,
  required ChatModelSettings settings,
  required bool supportImage,
  required bool supportAudio,
}) async {
  try {
    return await getActiveModelWithBackendFallbacks(
      maxTokens: settings.maxTokens,
      preferredBackend: settings.backend,
      supportImage: supportImage,
      supportAudio: supportAudio,
    );
  } catch (e) {
    final isRecoverable = isActiveModelUnavailableError(e);

    if (!isRecoverable || installedModels.isEmpty) {
      logger.e(
        'Failed to create model runtime. Likely model file is invalid/corrupted or backend is unsupported.',
        error: e,
      );
      return null;
    }

    final recovered = await recoverActiveModelFromCatalog(
      installedModels: installedModels,
      catalogModels: catalogModels,
    );
    if (!recovered) {
      logger.e(
        'Active model recovery failed: no installed catalog entry matched.',
        error: e,
      );
      return null;
    }

    try {
      return await getActiveModelWithBackendFallbacks(
        maxTokens: settings.maxTokens,
        preferredBackend: settings.backend,
        supportImage: supportImage,
        supportAudio: supportAudio,
      );
    } catch (retryError) {
      logger.e(
        'Model load still failing after active model recovery.',
        error: retryError,
      );
      return null;
    }
  }
}

Future<gemma.InferenceModel> getActiveModelWithBackendFallbacks({
  required int maxTokens,
  required gemma.PreferredBackend? preferredBackend,
  required bool supportImage,
  required bool supportAudio,
}) async {
  final backends = <gemma.PreferredBackend?>[];

  void addBackend(gemma.PreferredBackend? backend) {
    if (backends.contains(backend)) return;
    backends.add(backend);
  }

  addBackend(preferredBackend);
  addBackend(null);
  addBackend(gemma.PreferredBackend.npu);
  addBackend(gemma.PreferredBackend.gpu);
  addBackend(gemma.PreferredBackend.cpu);

  Object? lastError;
  for (final backend in backends) {
    try {
      final model = await gemma.FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
        preferredBackend: backend,
        supportImage: supportImage,
        supportAudio: supportAudio,
      );
      if (backend != preferredBackend) {
        logger.w(
          'Model loaded with fallback backend: ${backendName(backend)} (preferred: ${backendName(preferredBackend)}).',
        );
      }
      return model;
    } catch (e) {
      logger.e(e, error: e);
      await AppToast.show(e.toString(), type: AppToastType.error);
      if (isActiveModelUnavailableError(e)) {
        logger.w(
          'Backend attempt aborted (${backendName(backend)}): active model is unavailable.',
        );
        rethrow;
      }
      lastError = e;
      logger.w(
        'Backend attempt failed: ${backendName(backend)}. Trying next fallback.',
      );
    }
  }

  throw Exception(
    'Failed to create engine on all backend attempts. Last error: $lastError',
  );
}

bool isActiveModelUnavailableError(Object error) {
  final message = error.toString();
  return message.contains('Active model is no longer installed') ||
      message.contains('No active inference model set');
}

String backendName(gemma.PreferredBackend? backend) {
  if (backend == null) return 'auto';
  return backend.name;
}

Future<bool> recoverActiveModelFromCatalog({
  required List<String> installedModels,
  required List<db.Model> catalogModels,
}) async {
  final installed = {for (final id in installedModels) id.toLowerCase(): id};

  for (final model in catalogModels) {
    final installedId = installedModelIdFromSource(model.source);
    if (!installed.containsKey(installedId.toLowerCase())) continue;

    await activateCatalogModel(model);
    logger.i('Recovered invalid active model with: $installedId');
    return true;
  }

  logger.w('Could not recover active model: no catalog model matched install.');
  return false;
}

Future<void> activateCatalogModel(db.Model model) async {
  final sourcePath = await resolveModelSourceForInstall(
    modelName: model.name,
    sourceType: model.sourceType,
    source: model.source,
  );
  final installer = gemma.FlutterGemma.installModel(
    modelType: parseModelType(model.modelType),
    fileType: inferFileTypeFromSource(sourcePath),
  );

  final builder = installer.fromFile(sourcePath);
  await builder.install();
}

Future<String> resolveModelSourceForInstall({
  required String modelName,
  required String sourceType,
  required String source,
}) async {
  if (sourceType == 'file') {
    return source;
  }

  final modelKey = _buildModelDownloadKey(modelName: modelName, source: source);
  final downloaded = await ModelBackgroundDownloadService.instance
      .downloadModelToFile(
        modelKey: modelKey,
        modelName: modelName,
        sourceUrl: source,
      );
  return downloaded.path;
}

String _buildModelDownloadKey({
  required String modelName,
  required String source,
}) {
  final normalizedName = modelName.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9._-]'),
    '_',
  );
  final normalizedSource = source.trim().toLowerCase();
  return 'runtime_${normalizedName}_${normalizedSource.hashCode}';
}

String installedModelIdFromSource(String source) {
  final parts = source.split(RegExp(r'[/\\]'));
  return parts.isEmpty ? source : parts.last;
}

gemma.ModelFileType inferFileTypeFromSource(String source) {
  final lower = source.toLowerCase();
  if (lower.endsWith('.litertlm')) return gemma.ModelFileType.litertlm;
  if (lower.endsWith('.task')) return gemma.ModelFileType.task;
  return gemma.ModelFileType.binary;
}

gemma.ModelType parseModelType(String value) {
  return switch (value) {
    'general' => gemma.ModelType.general,
    'gemmaIt' => gemma.ModelType.gemmaIt,
    'gemma4' => gemma.ModelType.gemma4,
    'deepSeek' => gemma.ModelType.deepSeek,
    'qwen' => gemma.ModelType.qwen,
    'qwen3' => gemma.ModelType.qwen3,
    'llama' => gemma.ModelType.llama,
    'hammer' => gemma.ModelType.hammer,
    'functionGemma' => gemma.ModelType.functionGemma,
    'phi' => gemma.ModelType.phi,
    _ => gemma.ModelType.gemmaIt,
  };
}

db.Model? resolveActiveCatalogModel(List<db.Model> catalogModels) {
  final activeSpec =
      gemma.FlutterGemmaPlugin.instance.modelManager.activeInferenceModel;
  if (activeSpec is! gemma.InferenceModelSpec) return null;
  final activeId = activeSpec.name.toLowerCase();

  for (final model in catalogModels) {
    final modelId = (model.modelId ?? '').trim().toLowerCase();
    if (modelId.isNotEmpty && modelId == activeId) return model;
  }

  for (final model in catalogModels) {
    final fallbackId = modelSpecNameFromSource(model.source).toLowerCase();
    if (fallbackId == activeId) return model;
  }

  return null;
}

String modelSpecNameFromSource(String source) {
  final parts = source.split(RegExp(r'[/\\]'));
  final filename = parts.isEmpty ? source : parts.last;
  final dotIndex = filename.lastIndexOf('.');
  if (dotIndex <= 0) return filename;
  return filename.substring(0, dotIndex);
}

String buildSystemInstruction(String basePrompt) {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  const weekdayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final weekday = weekdayNames[now.weekday - 1];
  final dateContext = [
    'CURRENT LOCAL DATE CONTEXT',
    '- Today is $weekday, ${now.year}-$month-$day.',
    '- Local timezone: ${now.timeZoneName}.',
  ].join('\n');

  if (basePrompt.trim().isEmpty) return dateContext;
  return '${basePrompt.trim()}\n\n$dateContext';
}
