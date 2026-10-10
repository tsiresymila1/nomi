import 'package:flutter/foundation.dart';
import 'package:gena/features/downloads/data/models/local_model_capabilities.dart';

enum ModelValidationStatus { stable, experimental }

class DefaultSeedModel {
  const DefaultSeedModel({
    required this.key,
    required this.displayName,
    required this.baseUrl,
    this.webUrl,
    this.desktopUrl,
    required this.size,
    required this.modelType,
    required this.preferredBackend,
    required this.temperature,
    required this.topK,
    required this.topP,
    required this.maxTokens,
    required this.minimumRamGb,
    required this.recommendedRamGb,
    required this.parameterCountB,
    this.validationStatus = ModelValidationStatus.stable,
    this.supportImage = false,
    this.supportAudio = false,
    this.supportsFunctionCalls = false,
    this.isThinking = false,
    this.mmprojUrl,
    this.mmprojSize,
  });

  final String key;
  final String displayName;
  final String baseUrl;
  final String? webUrl;
  final String? desktopUrl;
  final String size;

  /// Optional multimodal projector (`mmproj-*.gguf`) for GGUF vision models.
  /// LiteRT-LM vision bundles do not need a separate projector.
  final String? mmprojUrl;

  /// Human-readable size of the projector file, when [mmprojUrl] is set.
  final String? mmprojSize;
  final LocalModelType modelType;
  final LocalModelBackend preferredBackend;
  final double temperature;
  final int topK;
  final double topP;
  final int maxTokens;
  final double minimumRamGb;
  final double recommendedRamGb;
  final double parameterCountB;
  final ModelValidationStatus validationStatus;
  final bool supportImage;
  final bool supportAudio;
  final bool supportsFunctionCalls;
  final bool isThinking;

  String get sourceUrl {
    if (_isDesktop && desktopUrl != null && desktopUrl!.isNotEmpty) {
      return desktopUrl!;
    }
    if (kIsWeb && webUrl != null && webUrl!.isNotEmpty) {
      return webUrl!;
    }
    return baseUrl;
  }

  /// Local model file format inferred from the primary source URL.
  String get format {
    if (sourceUrl.endsWith('.gguf')) return 'GGUF';
    if (sourceUrl.endsWith('.litertlm')) return 'LiteRT-LM';
    return 'unknown';
  }

  String get notes {
    final caps = <String>[modelType.name];
    if (supportImage) caps.add('image');
    if (supportAudio) caps.add('audio');
    if (supportsFunctionCalls) caps.add('functions');
    if (isThinking) caps.add('thinking');
    return 'Seeded default for llamadart. Format: $format. Size: $size. '
        'Recommended RAM: ${recommendedRamGb.toStringAsFixed(1)} GB. '
        'Capabilities: ${caps.join(', ')}. '
        'Validation: ${validationStatus.name}.';
  }

  bool matchesModelNameOrSource(String name, String source) {
    final nName = _normalize(name);
    final nSource = _normalize(source);
    if (_normalize(displayName) == nName) return true;

    final candidates = <String>{
      _normalize(baseUrl),
      if (webUrl != null && webUrl!.isNotEmpty) _normalize(webUrl!),
      if (desktopUrl != null && desktopUrl!.isNotEmpty) _normalize(desktopUrl!),
      _normalize(sourceUrl),
    };
    return candidates.contains(nSource);
  }
}

bool get _isDesktop {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

// Android-first GGUF catalog. Sources were verified against Hugging Face on
// 2026-10-10. The conservative RAM tiers account for model weights, KV cache,
// native runtime buffers, and the memory already used by Flutter/Android.
const Set<String> kLegacyDefaultSeedSources = <String>{
  'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
  'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
  'https://huggingface.co/google/gemma-3n-E2B-it-litert-lm/resolve/main/gemma-3n-E2B-it-int4.litertlm',
  'https://huggingface.co/google/gemma-3n-E4B-it-litert-lm/resolve/main/gemma-3n-E4B-it-int4.litertlm',
  'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm',
  'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.litertlm',
  'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B.litertlm',
  'https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B_multi-prefill-seq_q8_ekv4096.litertlm',
  'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm',
  'https://huggingface.co/litert-community/SmolLM2-135M-Instruct/resolve/main/SmolLM2_135M_Instruct.litertlm',
  'https://huggingface.co/litert-community/FastVLM-0.5B/resolve/main/FastVLM-0.5B.litertlm',
  'https://huggingface.co/litert-community/Phi-4-mini-instruct/resolve/main/Phi-4-mini-instruct_multi-prefill-seq_q8_ekv4096.litertlm',
  'https://huggingface.co/sasha-denisov/function-gemma-270M-it/resolve/main/functiongemma-270M-it.litertlm',
  'https://huggingface.co/sasha-denisov/functiongemma-flutter-gemma-demo/resolve/main/functiongemma-flutter_q8_ekv1024.litertlm',
};

final List<DefaultSeedModel> kDefaultSeedModels = <DefaultSeedModel>[
  const DefaultSeedModel(
    key: 'qwen3_0_6b_q4_k_m',
    displayName: 'Qwen3 0.6B Q4_K_M',
    baseUrl:
        'https://huggingface.co/unsloth/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf',
    size: '397MB',
    modelType: LocalModelType.qwen3,
    preferredBackend: LocalModelBackend.cpu,
    temperature: 0.7,
    topK: 40,
    topP: 0.95,
    maxTokens: 4096,
    minimumRamGb: 2,
    recommendedRamGb: 3,
    parameterCountB: 0.6,
    supportsFunctionCalls: true,
    isThinking: true,
  ),
  const DefaultSeedModel(
    key: 'gemma3_1b_it_q4_k_m',
    displayName: 'Gemma 3 1B IT Q4_K_M',
    baseUrl:
        'https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf',
    size: '806MB',
    modelType: LocalModelType.gemmaIt,
    preferredBackend: LocalModelBackend.cpu,
    temperature: 1.0,
    topK: 64,
    topP: 0.95,
    maxTokens: 4096,
    minimumRamGb: 2.5,
    recommendedRamGb: 4,
    parameterCountB: 1,
  ),
  const DefaultSeedModel(
    key: 'llama3_2_1b_instruct_q4_k_m',
    displayName: 'Llama 3.2 1B Instruct Q4_K_M',
    baseUrl:
        'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
    size: '808MB',
    modelType: LocalModelType.general,
    preferredBackend: LocalModelBackend.cpu,
    temperature: 0.7,
    topK: 40,
    topP: 0.95,
    maxTokens: 4096,
    minimumRamGb: 2.5,
    recommendedRamGb: 4,
    parameterCountB: 1,
  ),
  const DefaultSeedModel(
    key: 'qwen2_5_1_5b_instruct_q4_k_m',
    displayName: 'Qwen 2.5 1.5B Instruct Q4_K_M',
    baseUrl:
        'https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
    size: '0.99GB',
    modelType: LocalModelType.qwen,
    preferredBackend: LocalModelBackend.cpu,
    temperature: 1.0,
    topK: 40,
    topP: 0.95,
    maxTokens: 4096,
    minimumRamGb: 3,
    recommendedRamGb: 5,
    parameterCountB: 1.5,
    supportsFunctionCalls: true,
  ),
  const DefaultSeedModel(
    key: 'qwen2_5_0_5b_instruct_q4_k_m',
    displayName: 'Qwen 2.5 0.5B Instruct Q4_K_M',
    baseUrl:
        'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
    size: '0.4GB',
    modelType: LocalModelType.qwen,
    preferredBackend: LocalModelBackend.cpu,
    temperature: 1.0,
    topK: 40,
    topP: 0.95,
    maxTokens: 4096,
    minimumRamGb: 2,
    recommendedRamGb: 3,
    parameterCountB: 0.5,
    supportsFunctionCalls: true,
  ),
  const DefaultSeedModel(
    key: 'smolvlm2_500m_q8_0',
    displayName: 'SmolVLM2 500M Instruct Q8_0 (Vision)',
    baseUrl:
        'https://huggingface.co/ggml-org/SmolVLM2-500M-Video-Instruct-GGUF/resolve/main/SmolVLM2-500M-Video-Instruct-Q8_0.gguf',
    size: '417MB',
    modelType: LocalModelType.general,
    preferredBackend: LocalModelBackend.cpu,
    temperature: 0.7,
    topK: 40,
    topP: 0.95,
    maxTokens: 4096,
    minimumRamGb: 2.5,
    recommendedRamGb: 4,
    parameterCountB: 0.5,
    supportImage: true,
    mmprojUrl:
        'https://huggingface.co/ggml-org/SmolVLM2-500M-Video-Instruct-GGUF/resolve/main/mmproj-SmolVLM2-500M-Video-Instruct-Q8_0.gguf',
    mmprojSize: '109MB',
  ),
  const DefaultSeedModel(
    key: 'smollm3_3b_q4_k_m',
    displayName: 'SmolLM3 3B Q4_K_M',
    baseUrl:
        'https://huggingface.co/ggml-org/SmolLM3-3B-GGUF/resolve/main/SmolLM3-Q4_K_M.gguf',
    size: '1.92GB',
    modelType: LocalModelType.general,
    preferredBackend: LocalModelBackend.cpu,
    temperature: 0.7,
    topK: 40,
    topP: 0.95,
    maxTokens: 4096,
    minimumRamGb: 5,
    recommendedRamGb: 6,
    parameterCountB: 3,
    isThinking: true,
  ),
];

DefaultSeedModel? findDefaultSeedModelByNameOrSource({
  required String name,
  required String source,
}) {
  for (final model in kDefaultSeedModels) {
    if (model.matchesModelNameOrSource(name, source)) {
      return model;
    }
  }
  return null;
}

String _normalize(String value) {
  return value.trim().toLowerCase();
}
