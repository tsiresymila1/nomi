import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' hide ModelInfo;
import 'package:gena/core/local_ai/local_ai_runtime_coordinator.dart';
import 'package:gena/features/chat/data/services/coordinated_local_model_runtime.dart';
import 'package:gena/features/chat/data/services/coordinated_speech_to_text.dart';
import 'package:gena/features/chat/data/services/local_model_runtime.dart';
import 'package:gena/features/chat/data/services/speech_to_text.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';

void main() {
  test(
    'chat runtime is evicted for Whisper and lazily restored afterwards',
    () async {
      final coordinator = LocalAiRuntimeCoordinator(
        requiresExclusiveAccess: () async => true,
      );
      addTearDown(coordinator.close);
      final chatDelegate = _LocalModelRuntimeFake();
      final sttDelegate = _SpeechToTextFake();
      final chat = CoordinatedLocalModelRuntime(
        delegate: chatDelegate,
        coordinator: coordinator,
      );
      final stt = CoordinatedSpeechToText(
        delegate: sttDelegate,
        coordinator: coordinator,
      );

      await chat.prepare(_model());
      expect(coordinator.state.activeWorkloads, {LocalAiWorkload.chat});

      final transcription = stt.transcribe('/tmp/voice.wav');
      await sttDelegate.started.future;
      expect(chatDelegate.cancels, 1);
      expect(chatDelegate.resets, 1);
      expect(coordinator.state.activeWorkloads, {LocalAiWorkload.speechToText});

      var chatRestored = false;
      final restore = chat.prepare(_model()).then((_) => chatRestored = true);
      await Future<void>.delayed(Duration.zero);
      expect(chatRestored, isFalse);

      sttDelegate.complete(const SttResult(text: 'hello'));
      expect((await transcription).text, 'hello');
      await restore;

      expect(chatRestored, isTrue);
      expect(chatDelegate.prepares, 2);
      expect(coordinator.state.activeWorkloads, {LocalAiWorkload.chat});
    },
  );

  test(
    'model provisioning does not reserve heavyweight runtime memory',
    () async {
      final coordinator = LocalAiRuntimeCoordinator(
        requiresExclusiveAccess: () async => true,
      );
      addTearDown(coordinator.close);
      final delegate = _SpeechToTextFake();
      final stt = CoordinatedSpeechToText(
        delegate: delegate,
        coordinator: coordinator,
      );

      await stt.ensureModelReady();

      expect(delegate.ensureReadyCalls, 1);
      expect(coordinator.state.phase, LocalAiRuntimePhase.idle);
    },
  );
}

ModelInfo _model() => const ModelInfo(
  id: 1,
  name: 'Local GGUF',
  description: '',
  provider: 'local',
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
  sourceType: 'file',
  source: '/models/local.gguf',
);

class _LocalModelRuntimeFake implements LocalModelRuntime {
  int prepares = 0;
  int resets = 0;
  int cancels = 0;

  @override
  Future<PreparedLocalModel> prepare(ModelInfo model) async {
    prepares++;
    return PreparedLocalModel(
      ai: Genkit(),
      modelRef: modelRef<dynamic>('local'),
      modelId: 'local',
    );
  }

  @override
  void cancelActiveGeneration() => cancels++;

  @override
  Future<int> countTokens(String text) async => 1;

  @override
  Future<void> reset() async => resets++;
}

class _SpeechToTextFake implements SpeechToText {
  final Completer<void> started = Completer<void>();
  final Completer<SttResult> _result = Completer<SttResult>();
  int ensureReadyCalls = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<void> ensureModelReady() async => ensureReadyCalls++;

  @override
  Future<SttResult> transcribe(String wavPath, {String lang = 'auto'}) {
    if (!started.isCompleted) started.complete();
    return _result.future;
  }

  void complete(SttResult result) => _result.complete(result);
}
