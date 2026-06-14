import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';

import 'package:gena/features/downloads/data/local_model_files.dart';
import 'local_model_runtime.dart';

/// Builds the native llamadart-backed local model runtime.
LocalModelRuntime createLocalModelRuntime() {
  return CachingLocalModelRuntime(const _LlamadartRuntimeLoader());
}

/// Loads a local model file through `genkit_llamadart`.
class _LlamadartRuntimeLoader implements LocalRuntimeLoader {
  const _LlamadartRuntimeLoader();

  @override
  Future<LoadedLocalRuntime> load(LocalRuntimeRequest request) async {
    final source = request.modelInfo.source;
    final canonical = canonicalLocalModelPath(source);
    final file = File(canonical);
    if (!file.existsSync()) {
      throw LocalModelRuntimeException('Model file not found: $canonical');
    }

    String? mmprojPath = request.mmprojPath?.trim();
    if (mmprojPath != null && mmprojPath.isEmpty) mmprojPath = null;
    if (mmprojPath != null && !File(mmprojPath).existsSync()) {
      throw LocalModelRuntimeException(
        'Multimodal projector file not found: $mmprojPath',
      );
    }

    final modelId = localModelIdForPath(canonical);
    final definition = LlamaModelDefinition(
      name: modelId,
      modelPath: canonical,
      mmprojPath: mmprojPath,
      modelParams: ModelParams(contextSize: request.contextSize),
      supportsEmbeddings: false,
      supportsTools: true,
      supportsConstrainedOutput: request.constrainedOutput,
    );

    final plugin = LlamaDartPlugin(models: <LlamaModelDefinition>[definition]);
    final modelRef = llamaDart.model(modelId);
    final ai = Genkit(plugins: <LlamaDartPlugin>[plugin], model: modelRef);

    return LoadedLocalRuntime(
      ai: ai,
      modelRef: modelRef,
      modelId: modelId,
      cancel: () => plugin.cancelActiveGeneration(definition.name),
      dispose: () async {
        await plugin.dispose();
        await ai.shutdown();
      },
    );
  }
}
