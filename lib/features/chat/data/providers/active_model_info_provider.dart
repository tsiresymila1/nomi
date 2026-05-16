import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';

final activeModelInfoProvider = Provider<ModelInfo?>((ref) {
  final models = ref.watch(modelRepositoryProvider).asData?.value;
  if (models == null || models.isEmpty) return null;

  final activeSpec =
      gemma.FlutterGemmaPlugin.instance.modelManager.activeInferenceModel;
  if (activeSpec is! gemma.InferenceModelSpec) return null;

  final activeModelId = activeSpec.name.toLowerCase();
  for (final model in models) {
    final modelId = (model.modelId ?? '').trim().toLowerCase();
    if (modelId.isNotEmpty && modelId == activeModelId) {
      return model;
    }

    final fallbackId = _modelSpecNameFromSource(model.source).toLowerCase();
    if (fallbackId == activeModelId) {
      return model;
    }
  }

  return null;
});

String _modelSpecNameFromSource(String source) {
  final parts = source.split(RegExp(r'[/\\]'));
  final filename = parts.isEmpty ? source : parts.last;
  final dotIndex = filename.lastIndexOf('.');
  if (dotIndex <= 0) return filename;
  return filename.substring(0, dotIndex);
}
