import 'package:flutter_test/flutter_test.dart';

import 'package:gena/features/chat/data/services/chat_thread_actions_service.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';

ModelInfo _model({required bool supportImage}) {
  return ModelInfo(
    id: 1,
    name: 'Test',
    description: '',
    provider: 'local',
    modelType: 'general',
    supportImage: supportImage,
    supportAudio: false,
    supportsFunctionCalls: false,
    isThinking: false,
    temperature: 0.7,
    topK: 40,
    topP: 0.95,
    maxTokens: 4096,
    tokenBuffer: 256,
    randomSeed: 0,
    preferredBackend: 'cpu',
    sourceType: 'file',
    source: '/models/a.gguf',
  );
}

void main() {
  group('isImageInputRejected', () {
    test('rejects an image attached to a non-vision model', () {
      expect(
        isImageInputRejected(
          model: _model(supportImage: false),
          hasImage: true,
        ),
        isTrue,
      );
    });

    test('allows an image attached to a vision model', () {
      expect(
        isImageInputRejected(model: _model(supportImage: true), hasImage: true),
        isFalse,
      );
    });

    test('does not reject text-only messages on any model', () {
      expect(
        isImageInputRejected(
          model: _model(supportImage: false),
          hasImage: false,
        ),
        isFalse,
      );
    });

    test('does not reject when there is no active model yet', () {
      expect(isImageInputRejected(model: null, hasImage: true), isFalse);
    });

    test('exposes a clear rejection message', () {
      expect(imageInputUnsupportedMessage, contains('vision model'));
    });
  });
}
