import 'package:flutter/foundation.dart';
import 'package:gena/features/downloads/data/models/local_model_capabilities.dart';

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
    this.supportImage = false,
    this.supportAudio = false,
    this.supportsFunctionCalls = false,
    this.isThinking = false,
  });

  final String key;
  final String displayName;
  final String baseUrl;
  final String? webUrl;
  final String? desktopUrl;
  final String size;
  final LocalModelType modelType;
  final LocalModelBackend preferredBackend;
  final double temperature;
  final int topK;
  final double topP;
  final int maxTokens;
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
        'Capabilities: ${caps.join(', ')}.';
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

// Catalog sources verified against Hugging Face on 2026-06-13.
// `public` sources resolve with HTTP 200; `gated` sources resolve with HTTP 401
// until the Hugging Face access token is supplied (the app sends it as a bearer
// header when downloading). All sources are single-file .litertlm or .gguf
// bundles loadable by llamadart (LiteRT-LM via llamadart_litert_lm_flutter,
// GGUF via llamadart_llama_cpp_flutter).
final List<DefaultSeedModel> kDefaultSeedModels = <DefaultSeedModel>[
  const DefaultSeedModel(
    key: 'gemma4_E2B',
    displayName: 'Gemma 4 E2B IT',
    // public
    baseUrl:
        'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
    size: '2.4GB',
    modelType: LocalModelType.gemma4,
    preferredBackend: LocalModelBackend.gpu,
    temperature: 1.0,
    topK: 64,
    topP: 0.95,
    supportImage: true,
    supportAudio: true,
    maxTokens: 4096,
    isThinking: true,
  ),
  const DefaultSeedModel(
    key: 'gemma4_E4B',
    displayName: 'Gemma 4 E4B IT',
    // public
    baseUrl:
        'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
    size: '4.3GB',
    modelType: LocalModelType.gemma4,
    preferredBackend: LocalModelBackend.gpu,
    temperature: 1.0,
    topK: 64,
    topP: 0.95,
    supportImage: true,
    supportAudio: true,
    maxTokens: 4096,
    isThinking: true,
  ),
  const DefaultSeedModel(
    key: 'gemma3n_2B',
    displayName: 'Gemma 3 Nano E2B IT',
    // gated (Google license + HF token)
    baseUrl:
        'https://huggingface.co/google/gemma-3n-E2B-it-litert-lm/resolve/main/gemma-3n-E2B-it-int4.litertlm',
    size: '3.1GB',
    modelType: LocalModelType.gemmaIt,
    preferredBackend: LocalModelBackend.gpu,
    temperature: 1.0,
    topK: 64,
    topP: 0.95,
    supportImage: true,
    supportAudio: true,
    maxTokens: 4096,
  ),
  const DefaultSeedModel(
    key: 'gemma3n_4B',
    displayName: 'Gemma 3 Nano E4B IT',
    // gated (Google license + HF token)
    baseUrl:
        'https://huggingface.co/google/gemma-3n-E4B-it-litert-lm/resolve/main/gemma-3n-E4B-it-int4.litertlm',
    size: '6.5GB',
    modelType: LocalModelType.gemmaIt,
    preferredBackend: LocalModelBackend.gpu,
    temperature: 1.0,
    topK: 64,
    topP: 0.95,
    supportImage: true,
    supportAudio: true,
    maxTokens: 4096,
  ),
  const DefaultSeedModel(
    key: 'gemma3_1B',
    displayName: 'Gemma 3 1B IT',
    // gated (Google license + HF token)
    baseUrl:
        'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm',
    size: '0.5GB',
    modelType: LocalModelType.gemmaIt,
    preferredBackend: LocalModelBackend.gpu,
    temperature: 1.0,
    topK: 64,
    topP: 0.95,
    maxTokens: 1024,
  ),
  const DefaultSeedModel(
    key: 'gemma3_270M',
    displayName: 'Gemma 3 270M IT',
    // gated (Google license + HF token)
    baseUrl:
        'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.litertlm',
    size: '0.3GB',
    modelType: LocalModelType.gemmaIt,
    preferredBackend: LocalModelBackend.gpu,
    temperature: 1.0,
    topK: 64,
    topP: 0.95,
    maxTokens: 1024,
  ),
  const DefaultSeedModel(
    key: 'qwen3_0_6B',
    displayName: 'Qwen3 0.6B',
    // public
    baseUrl:
        'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B.litertlm',
    size: '586MB',
    modelType: LocalModelType.qwen3,
    preferredBackend: LocalModelBackend.cpu,
    temperature: 0.7,
    topK: 40,
    topP: 0.95,
    maxTokens: 4096,
    supportsFunctionCalls: true,
    isThinking: true,
  ),
  const DefaultSeedModel(
    key: 'deepseek',
    displayName: 'DeepSeek R1 Distill Qwen 1.5B',
    // public
    baseUrl:
        'https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B_multi-prefill-seq_q8_ekv4096.litertlm',
    size: '1.7GB',
    modelType: LocalModelType.deepSeek,
    preferredBackend: LocalModelBackend.cpu,
    temperature: 0.6,
    topK: 40,
    topP: 0.7,
    maxTokens: 4096,
    isThinking: true,
  ),
  const DefaultSeedModel(
    key: 'qwen25_1_5B_Instruct',
    displayName: 'Qwen 2.5 1.5B Instruct',
    // public
    baseUrl:
        'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm',
    size: '1.6GB',
    modelType: LocalModelType.qwen,
    preferredBackend: LocalModelBackend.cpu,
    temperature: 1.0,
    topK: 40,
    topP: 0.95,
    maxTokens: 4096,
    supportsFunctionCalls: true,
  ),
  const DefaultSeedModel(
    key: 'qwen25_0_5B_Instruct',
    displayName: 'Qwen 2.5 0.5B Instruct',
    // public (GGUF Q4_K_M from the Qwen org)
    baseUrl:
        'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
    size: '0.4GB',
    modelType: LocalModelType.qwen,
    preferredBackend: LocalModelBackend.cpu,
    temperature: 1.0,
    topK: 40,
    topP: 0.95,
    maxTokens: 4096,
    supportsFunctionCalls: true,
  ),
  const DefaultSeedModel(
    key: 'smolLM_135M',
    displayName: 'SmolLM2 135M Instruct',
    // public
    baseUrl:
        'https://huggingface.co/litert-community/SmolLM2-135M-Instruct/resolve/main/SmolLM2_135M_Instruct.litertlm',
    size: '135MB',
    modelType: LocalModelType.general,
    preferredBackend: LocalModelBackend.cpu,
    temperature: 0.7,
    topK: 40,
    topP: 0.9,
    maxTokens: 1024,
  ),
  const DefaultSeedModel(
    key: 'fastVLM_0_5B',
    displayName: 'FastVLM 0.5B (Vision)',
    // public
    baseUrl:
        'https://huggingface.co/litert-community/FastVLM-0.5B/resolve/main/FastVLM-0.5B.litertlm',
    size: '0.5GB',
    modelType: LocalModelType.general,
    preferredBackend: LocalModelBackend.gpu,
    temperature: 0.7,
    topK: 40,
    topP: 0.95,
    supportImage: true,
    maxTokens: 2048,
  ),
  const DefaultSeedModel(
    key: 'phi4_mini',
    displayName: 'Phi-4 Mini Instruct',
    // public
    baseUrl:
        'https://huggingface.co/litert-community/Phi-4-mini-instruct/resolve/main/Phi-4-mini-instruct_multi-prefill-seq_q8_ekv4096.litertlm',
    size: '3.9GB',
    modelType: LocalModelType.general,
    preferredBackend: LocalModelBackend.gpu,
    temperature: 0.7,
    topK: 40,
    topP: 0.95,
    maxTokens: 4096,
    supportsFunctionCalls: true,
  ),
  const DefaultSeedModel(
    key: 'functionGemma_270M',
    displayName: 'FunctionGemma 270M IT',
    // public
    baseUrl:
        'https://huggingface.co/sasha-denisov/function-gemma-270M-it/resolve/main/functiongemma-270M-it.litertlm',
    size: '284MB',
    modelType: LocalModelType.functionGemma,
    preferredBackend: LocalModelBackend.gpu,
    temperature: 1.0,
    topK: 64,
    topP: 0.95,
    maxTokens: 1024,
    supportsFunctionCalls: true,
  ),
  const DefaultSeedModel(
    key: 'functionGemma_demo',
    displayName: 'FunctionGemma Demo (Fine-tuned)',
    // public
    baseUrl:
        'https://huggingface.co/sasha-denisov/functiongemma-flutter-gemma-demo/resolve/main/functiongemma-flutter_q8_ekv1024.litertlm',
    size: '284MB',
    modelType: LocalModelType.functionGemma,
    preferredBackend: LocalModelBackend.gpu,
    temperature: 1.0,
    topK: 64,
    topP: 0.95,
    maxTokens: 1024,
    supportsFunctionCalls: true,
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
