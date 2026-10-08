import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/services/chat_thread_actions_service.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';

void main() {
  test('local failure proposes the first configured remote model', () {
    final proposal = resolveRemoteFallbackProposal(
      failedModel: _model(1, ModelProviderType.local),
      models: [
        _model(1, ModelProviderType.local),
        _model(
          2,
          ModelProviderType.remote,
          apiUrl: 'https://api.example.com/v1',
        ),
      ],
    );

    expect(proposal?.modelId, 2);
    expect(proposal?.modelName, 'Model 2');
    expect(proposal?.providerLabel, 'api.example.com');
  });

  test('remote failure never proposes another automatic remote fallback', () {
    final proposal = resolveRemoteFallbackProposal(
      failedModel: _model(1, ModelProviderType.remote),
      models: [_model(2, ModelProviderType.remote)],
    );

    expect(proposal, isNull);
  });
}

ModelInfo _model(int id, String provider, {String? apiUrl}) => ModelInfo(
  id: id,
  name: 'Model $id',
  description: '',
  provider: provider,
  apiUrl: apiUrl,
  modelType: 'general',
  supportImage: false,
  supportAudio: false,
  supportsFunctionCalls: false,
  isThinking: false,
  temperature: 0.7,
  topK: 40,
  topP: 0.95,
  maxTokens: 2048,
  tokenBuffer: 256,
  randomSeed: 1,
  preferredBackend: 'cpu',
  sourceType: provider == ModelProviderType.local ? 'file' : 'remote',
  source: provider == ModelProviderType.local
      ? '/models/model-$id.gguf'
      : 'remote-server://server/model-$id',
);
