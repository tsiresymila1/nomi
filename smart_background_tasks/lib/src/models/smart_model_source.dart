class SmartModelSource {
  const SmartModelSource({
    required this.name,
    required this.url,
    required this.notes,
  });

  final String name;
  final String url;
  final String notes;
}

const List<SmartModelSource>
kDefaultFlutterGemmaModelSources = <SmartModelSource>[
  SmartModelSource(
    name: 'Gemma 4 E2B',
    url: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm',
    notes: 'From flutter_gemma supported models (LiteRT community hub).',
  ),
  SmartModelSource(
    name: 'Qwen3 0.6B',
    url: 'https://huggingface.co/litert-community/Qwen3-0.6B',
    notes: 'From flutter_gemma supported models (LiteRT community hub).',
  ),
  SmartModelSource(
    name: 'DeepSeek R1',
    url:
        'https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B',
    notes: 'From flutter_gemma supported models (LiteRT community hub).',
  ),
];
