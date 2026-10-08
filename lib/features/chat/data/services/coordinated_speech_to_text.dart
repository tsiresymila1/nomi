import 'dart:async';

import 'package:gena/core/local_ai/local_ai_runtime_coordinator.dart';

import 'speech_to_text.dart';

/// Reserves heavyweight local-AI memory only while Whisper is transcribing.
/// Model download/provisioning remains outside the lease because it does not
/// load the native inference graph.
class CoordinatedSpeechToText implements SpeechToText {
  CoordinatedSpeechToText({
    required SpeechToText delegate,
    required LocalAiRuntimeCoordinator coordinator,
  }) : _delegate = delegate,
       _coordinator = coordinator;

  final SpeechToText _delegate;
  final LocalAiRuntimeCoordinator _coordinator;

  @override
  bool get isAvailable => _delegate.isAvailable;

  @override
  Future<void> ensureModelReady() => _delegate.ensureModelReady();

  @override
  Future<SttResult> transcribe(String wavPath, {String lang = 'auto'}) async {
    final completed = Completer<void>();
    final lease = await _coordinator.acquire(
      LocalAiWorkload.speechToText,
      onEvict: () => completed.future,
    );
    try {
      return await _delegate.transcribe(wavPath, lang: lang);
    } finally {
      if (!completed.isCompleted) completed.complete();
      await lease.release();
    }
  }
}
