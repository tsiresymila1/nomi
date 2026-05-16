import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:shared_preferences/shared_preferences.dart';

class ChatModelSettings {
  final String systemPrompt;
  final double temperature;
  final int topK;
  final double topP;
  final int maxTokens;
  final int tokenBuffer;
  final int randomSeed;
  final String preferredBackend;
  final bool isThinking;

  const ChatModelSettings({
    required this.systemPrompt,
    required this.temperature,
    required this.topK,
    required this.topP,
    required this.maxTokens,
    required this.tokenBuffer,
    required this.randomSeed,
    required this.preferredBackend,
    required this.isThinking,
  });

  factory ChatModelSettings.defaults() {
    return const ChatModelSettings(
      systemPrompt: '',
      temperature: 0.8,
      topK: 40,
      topP: 0.95,
      maxTokens: 2048,
      tokenBuffer: 256,
      randomSeed: 1,
      preferredBackend: 'gpu',
      isThinking: false,
    );
  }

  ChatModelSettings copyWith({
    String? systemPrompt,
    double? temperature,
    int? topK,
    double? topP,
    int? maxTokens,
    int? tokenBuffer,
    int? randomSeed,
    String? preferredBackend,
    bool? isThinking,
  }) {
    return ChatModelSettings(
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      topK: topK ?? this.topK,
      topP: topP ?? this.topP,
      maxTokens: maxTokens ?? this.maxTokens,
      tokenBuffer: tokenBuffer ?? this.tokenBuffer,
      randomSeed: randomSeed ?? this.randomSeed,
      preferredBackend: preferredBackend ?? this.preferredBackend,
      isThinking: isThinking ?? this.isThinking,
    );
  }

  gemma.PreferredBackend? get backend {
    return switch (preferredBackend) {
      'cpu' => gemma.PreferredBackend.cpu,
      'gpu' => gemma.PreferredBackend.gpu,
      'npu' => gemma.PreferredBackend.npu,
      _ => null,
    };
  }

  factory ChatModelSettings.fromPrefs(SharedPreferences prefs) {
    final defaults = ChatModelSettings.defaults();
    return ChatModelSettings(
      systemPrompt:
          prefs.getString(_Keys.systemPrompt) ?? defaults.systemPrompt,
      temperature: prefs.getDouble(_Keys.temperature) ?? defaults.temperature,
      topK: prefs.getInt(_Keys.topK) ?? defaults.topK,
      topP: prefs.getDouble(_Keys.topP) ?? defaults.topP,
      maxTokens: prefs.getInt(_Keys.maxTokens) ?? defaults.maxTokens,
      tokenBuffer: prefs.getInt(_Keys.tokenBuffer) ?? defaults.tokenBuffer,
      randomSeed: prefs.getInt(_Keys.randomSeed) ?? defaults.randomSeed,
      preferredBackend:
          prefs.getString(_Keys.preferredBackend) ?? defaults.preferredBackend,
      isThinking: prefs.getBool(_Keys.isThinking) ?? defaults.isThinking,
    );
  }

  Future<void> saveToPrefs(SharedPreferences prefs) async {
    await prefs.setString(_Keys.systemPrompt, systemPrompt);
    await prefs.setDouble(_Keys.temperature, temperature);
    await prefs.setInt(_Keys.topK, topK);
    await prefs.setDouble(_Keys.topP, topP);
    await prefs.setInt(_Keys.maxTokens, maxTokens);
    await prefs.setInt(_Keys.tokenBuffer, tokenBuffer);
    await prefs.setInt(_Keys.randomSeed, randomSeed);
    await prefs.setString(_Keys.preferredBackend, preferredBackend);
    await prefs.setBool(_Keys.isThinking, isThinking);
  }
}

class _Keys {
  static const systemPrompt = 'chat_settings_system_prompt';
  static const temperature = 'chat_settings_temperature';
  static const topK = 'chat_settings_top_k';
  static const topP = 'chat_settings_top_p';
  static const maxTokens = 'chat_settings_max_tokens';
  static const tokenBuffer = 'chat_settings_token_buffer';
  static const randomSeed = 'chat_settings_random_seed';
  static const preferredBackend = 'chat_settings_preferred_backend';
  static const isThinking = 'chat_settings_is_thinking';
}
