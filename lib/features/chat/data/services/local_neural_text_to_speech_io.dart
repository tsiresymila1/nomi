import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/core/local_ai/local_ai_runtime_coordinator.dart';
import 'package:gena/features/chat/data/models/llamadart_tts_model_profile.dart';
import 'package:gena/features/chat/data/services/llamadart_tts_model_store.dart';
import 'package:gena/features/chat/data/services/local_neural_text_to_speech.dart';
import 'package:gena/features/chat/data/services/text_to_speech.dart';
import 'package:llamadart/llamadart.dart';

LocalNeuralTextToSpeech createPlatformLocalNeuralTextToSpeech({
  required LlamaDartTtsModelStore modelStore,
  required LocalAiRuntimeCoordinator coordinator,
  required String? Function() languageCode,
}) => LlamaDartTextToSpeech(
  modelStore: modelStore,
  coordinator: coordinator,
  languageCode: languageCode,
);

class LlamaDartTextToSpeech implements LocalNeuralTextToSpeech {
  LlamaDartTextToSpeech({
    required LlamaDartTtsModelStore modelStore,
    required LocalAiRuntimeCoordinator coordinator,
    required String? Function() languageCode,
    AudioPlayer? audioPlayer,
  }) : _modelStore = modelStore,
       _coordinator = coordinator,
       _languageCode = languageCode,
       _player = audioPlayer ?? AudioPlayer();

  final LlamaDartTtsModelStore _modelStore;
  final LocalAiRuntimeCoordinator _coordinator;
  final String? Function() _languageCode;
  final AudioPlayer _player;
  final StreamController<bool> _speakingController =
      StreamController<bool>.broadcast();
  final List<String> _queue = <String>[];

  TextToSpeechEngine? _engine;
  LocalAiRuntimeLease? _lease;
  TextToSpeechTask? _activeTask;
  Completer<void>? _playbackCompletion;
  Future<void>? _preparing;
  bool _processing = false;
  bool _disposed = false;
  int _serial = 0;

  @override
  bool get isAvailable => _modelStore.isSupported;

  @override
  Stream<bool> get speakingChanges => _speakingController.stream;

  @override
  Future<void> prepare() {
    if (!isAvailable) {
      throw const TextToSpeechException(
        'LlamaDart text-to-speech is unavailable on this platform.',
      );
    }
    return _preparing ??= _prepare().whenComplete(() => _preparing = null);
  }

  Future<void> _prepare() async {
    if (_disposed) {
      throw const TextToSpeechException(
        'The local text-to-speech engine has been disposed.',
      );
    }
    if (_engine != null && _lease?.isActive == true) return;
    final installed = await _modelStore.resolve(qwen3Tts17bQ4);
    if (installed == null) {
      throw const TextToSpeechException(
        'Install the Qwen3-TTS model before selecting Local AI voice.',
      );
    }
    final lease = await _coordinator.acquire(
      LocalAiWorkload.textToSpeech,
      onEvict: _evict,
    );
    try {
      final engine = await TextToSpeechEngine.load(
        TextToSpeechModel(
          ModelSource.path(installed.modelPath),
          projector: ModelSource.path(installed.projectorPath),
          adapter: const Qwen3TtsAdapter(),
        ),
        params: const ModelParams(
          contextSize: 4096,
          preferredBackend: GpuBackend.cpu,
          gpuLayers: 0,
        ),
      );
      _lease = lease;
      _engine = engine;
    } catch (_) {
      await lease.release();
      rethrow;
    }
  }

  @override
  Future<void> speak(String text) async {
    await clear();
    await enqueue(text);
  }

  @override
  Future<void> enqueue(String text) async {
    final spoken = text.trim();
    if (spoken.isEmpty) return;
    if (_disposed) {
      throw const TextToSpeechException(
        'The local text-to-speech engine has been disposed.',
      );
    }
    if (!_processing) await prepare();
    _queue.add(spoken);
    if (_processing) return;
    _processing = true;
    unawaited(_drain(_serial));
  }

  Future<void> _drain(int serial) async {
    _emit(true);
    try {
      await prepare();
      while (!_disposed && serial == _serial && _queue.isNotEmpty) {
        final text = _queue.removeAt(0);
        final engine = _engine;
        if (engine == null) {
          throw const TextToSpeechException(
            'The local text-to-speech engine was released.',
          );
        }
        final task = await engine.synthesize(
          TextToSpeechRequest(
            text: text,
            language: _normalizedLanguage(),
            maxFrames: 1024,
          ),
        );
        _activeTask = task;
        final result = await task.result;
        _activeTask = null;
        if (serial != _serial || _disposed) break;
        await _play(result.toWavBytes(), serial);
      }
    } catch (error, stackTrace) {
      if (serial == _serial && !_disposed) {
        _queue.clear();
        _emit(false);
        logger.e(
          'LlamaDart text-to-speech failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    } finally {
      if (serial == _serial) {
        _processing = false;
        _emit(false);
      }
    }
  }

  Future<void> _play(List<int> wavBytes, int serial) async {
    final completion = Completer<void>();
    _playbackCompletion = completion;
    late final StreamSubscription<void> subscription;
    subscription = _player.onPlayerComplete.listen((_) {
      if (!completion.isCompleted) completion.complete();
    });
    try {
      await _player.play(
        BytesSource(Uint8List.fromList(wavBytes), mimeType: 'audio/wav'),
      );
      if (serial != _serial && !completion.isCompleted) completion.complete();
      await completion.future;
    } finally {
      await subscription.cancel();
      if (identical(_playbackCompletion, completion)) {
        _playbackCompletion = null;
      }
    }
  }

  String? _normalizedLanguage() {
    final locale = _languageCode()?.trim().toLowerCase();
    if (locale == null || locale.isEmpty) return null;
    final code = locale.split(RegExp('[-_]')).first;
    const supported = <String>{
      'zh',
      'en',
      'ja',
      'ko',
      'de',
      'fr',
      'ru',
      'pt',
      'es',
      'it',
    };
    return supported.contains(code) ? code : null;
  }

  @override
  Future<void> clear() async {
    _serial++;
    _queue.clear();
    final activeTask = _activeTask;
    activeTask?.cancel();
    if (activeTask != null) {
      await activeTask.done;
    }
    _activeTask = null;
    final completion = _playbackCompletion;
    if (completion != null && !completion.isCompleted) completion.complete();
    await _player.stop();
    _processing = false;
    _emit(false);
  }

  @override
  Future<void> stop() => clear();

  Future<void> _evict() async {
    final preparing = _preparing;
    if (preparing != null) {
      try {
        await preparing;
      } catch (_) {
        // The load failure is already returned to its original caller.
      }
    }
    await clear();
    final engine = _engine;
    _engine = null;
    _lease = null;
    if (engine != null) await engine.dispose();
  }

  @override
  Future<void> unload() async {
    final preparing = _preparing;
    if (preparing != null) {
      try {
        await preparing;
      } catch (_) {
        // Continue cleanup after a failed load.
      }
    }
    await clear();
    final engine = _engine;
    final lease = _lease;
    _engine = null;
    _lease = null;
    if (engine != null) await engine.dispose();
    await lease?.release();
  }

  void _emit(bool speaking) {
    if (!_disposed && !_speakingController.isClosed) {
      _speakingController.add(speaking);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await unload();
    _disposed = true;
    await _player.dispose();
    await _speakingController.close();
  }
}
