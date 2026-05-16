import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/providers/chat_session_provider.dart';
import 'package:gena/features/setting/data/chat_model_settings.dart';
import 'package:gena/features/setting/data/providers/chat_model_settings_provider.dart';

final modelSettingsActionsProvider = Provider<ModelSettingsActions>(
  (ref) => ModelSettingsActions(ref),
);

class ModelSettingsValidationException implements Exception {
  final String message;
  const ModelSettingsValidationException(this.message);

  @override
  String toString() => message;
}

class ModelSettingsSaveInput {
  final String systemPrompt;
  final String topKText;
  final String maxTokensText;
  final String tokenBufferText;
  final String randomSeedText;
  final double temperature;
  final double topP;
  final String preferredBackend;
  final bool isThinking;

  const ModelSettingsSaveInput({
    required this.systemPrompt,
    required this.topKText,
    required this.maxTokensText,
    required this.tokenBufferText,
    required this.randomSeedText,
    required this.temperature,
    required this.topP,
    required this.preferredBackend,
    required this.isThinking,
  });
}

class ModelSettingsActions {
  final Ref ref;
  ModelSettingsActions(this.ref);

  Future<void> save(ModelSettingsSaveInput input) async {
    final topK = int.tryParse(input.topKText.trim());
    final maxTokens = int.tryParse(input.maxTokensText.trim());
    final tokenBuffer = int.tryParse(input.tokenBufferText.trim());
    final randomSeed = int.tryParse(input.randomSeedText.trim());

    if (topK == null || topK < 1 || topK > 200) {
      throw const ModelSettingsValidationException(
        'Top-K must be between 1 and 200',
      );
    }
    if (maxTokens == null || maxTokens < 256 || maxTokens > 8192) {
      throw const ModelSettingsValidationException(
        'Max tokens must be between 256 and 8192',
      );
    }
    if (tokenBuffer == null || tokenBuffer < 32 || tokenBuffer > 4096) {
      throw const ModelSettingsValidationException(
        'Token buffer must be between 32 and 4096',
      );
    }
    if (randomSeed == null || randomSeed < 0) {
      throw const ModelSettingsValidationException(
        'Random seed must be 0 or greater',
      );
    }
    if (tokenBuffer >= maxTokens) {
      throw const ModelSettingsValidationException(
        'Token buffer must be smaller than max tokens',
      );
    }

    final next = ChatModelSettings(
      systemPrompt: input.systemPrompt.trim(),
      temperature: input.temperature,
      topK: topK,
      topP: input.topP,
      maxTokens: maxTokens,
      tokenBuffer: tokenBuffer,
      randomSeed: randomSeed,
      preferredBackend: input.preferredBackend,
      isThinking: input.isThinking,
    );

    await ref.read(chatModelSettingsProvider.notifier).save(next);
    ref.invalidate(activeGemmaChatProvider);
  }

  Future<ChatModelSettings> resetDefaults() async {
    await ref.read(chatModelSettingsProvider.notifier).resetDefaults();
    ref.invalidate(activeGemmaChatProvider);
    return ref.read(chatModelSettingsProvider);
  }

  void resetFlutterGemma() {
    FlutterGemma.reset();
    ref.invalidate(activeGemmaChatProvider);
  }
}
