import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/services/speech_to_text.dart';
import 'package:gena/features/chat/data/services/text_to_speech.dart';
import 'package:gena/features/chat/data/services/vad_controller.dart';
import 'package:gena/features/chat/presentation/cubit/voice_conversation_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/voice_input_cubit.dart';

/// Recorder fake. Real mic levels arrive via the level stream during listening;
/// the cubit only proceeds when the VAD saw speech, so tests feed the VAD
/// directly via [_speakAndStop].
class _FakeRecorder implements VoiceAudioRecorder {
  _FakeRecorder();

  bool failStart = false;

  String? wavPath = 'recording.wav';
  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;

  @override
  Future<void> start() async {
    startCount++;
    if (failStart) {
      throw const SpeechToTextException('mic denied');
    }
  }

  @override
  Future<String?> stop() async {
    stopCount++;
    return wavPath;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }
}

class _FakeSpeechToText implements SpeechToText {
  String text = 'hello there';
  Object? error;

  @override
  bool get isAvailable => true;

  @override
  Future<void> ensureModelReady() async {}

  @override
  Future<SttResult> transcribe(String wavPath, {String lang = 'auto'}) async {
    if (error != null) throw error!;
    return SttResult(text: text);
  }
}

class _FakeTextToSpeech implements TextToSpeech {
  bool available = true;
  Object? speakError;

  final List<String> spoken = <String>[];
  int stopCount = 0;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  bool get isAvailable => available;

  @override
  Stream<bool> get speakingChanges => _controller.stream;

  @override
  Future<void> speak(String text) async {
    if (speakError != null) throw speakError!;
    spoken.add(text);
    _controller.add(true);
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _controller.add(false);
  }

  /// Simulates the engine finishing the utterance.
  void finish() => _controller.add(false);

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

/// Generation signal that returns a canned reply (or throws) without touching
/// real chat cubits.
class _FakeGenerationSignal implements GenerationSignal {
  String? reply = 'assistant reply';
  Object? error;
  int runCount = 0;

  @override
  Future<String?> run(Future<void> Function() send) async {
    runCount++;
    await send();
    if (error != null) throw error!;
    return reply;
  }
}

/// Pumps the microtask/event queue so awaited phase transitions settle.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// Feeds above-threshold "speech" into [vad] and ends the listen turn — the
/// cubit only proceeds to transcribe/send when the VAD saw speech this turn.
Future<void> _speakAndStop(
  VoiceConversationCubit cubit,
  VadController vad,
) async {
  vad.add(const MicLevel(-10)); // above the -35 speech threshold
  await cubit.onTap();
  await _settle();
}

void main() {
  late _FakeRecorder recorder;
  late _FakeSpeechToText stt;
  late _FakeTextToSpeech tts;
  late _FakeGenerationSignal gen;
  late VadController vad;
  late List<String> sent;

  VoiceConversationCubit build({List<String>? errors}) {
    sent = <String>[];
    vad = VadController();
    recorder = _FakeRecorder();
    return VoiceConversationCubit(
      recorder: recorder,
      speechToText: stt,
      textToSpeech: tts,
      vad: vad,
      levelSource: null,
      sendMessage: (text) async {
        sent.add(text);
      },
      generationSignal: gen,
      onError: errors?.add,
    );
  }

  setUp(() {
    stt = _FakeSpeechToText();
    tts = _FakeTextToSpeech();
    gen = _FakeGenerationSignal();
  });

  tearDown(() async {
    await tts.dispose();
  });

  test('full loop advances listening → transcribing → thinking → speaking → '
      'listening', () async {
    final cubit = build();

    await cubit.enter();
    expect(cubit.state.phase, VoiceConversationPhase.listening);
    expect(recorder.startCount, 1);

    // Speak, then stop the turn.
    await _speakAndStop(cubit, vad);

    // Transcribe ran, message sent, generation ran, reply spoken.
    expect(recorder.stopCount, 1);
    expect(stt.text, 'hello there');
    expect(sent, ['hello there']);
    expect(gen.runCount, 1);
    expect(cubit.state.phase, VoiceConversationPhase.speaking);
    expect(tts.spoken, ['assistant reply']);
    expect(cubit.state.partialTranscript, 'hello there');

    // Engine finishes speaking -> back to listening (new turn).
    tts.finish();
    await _settle();
    expect(cubit.state.phase, VoiceConversationPhase.listening);
    expect(recorder.startCount, 2);

    await cubit.exit();
    await cubit.close();
  });

  test('blank transcript returns to listening without sending', () async {
    stt.text = '   ';
    final cubit = build();

    await cubit.enter();
    await _speakAndStop(cubit, vad);

    expect(sent, isEmpty);
    expect(gen.runCount, 0);
    expect(cubit.state.phase, VoiceConversationPhase.listening);
    // Started once on enter, again after the blank transcript.
    expect(recorder.startCount, 2);

    await cubit.exit();
    await cubit.close();
  });

  test('a silent turn (no speech detected) loops without sending', () async {
    final cubit = build();

    await cubit.enter();
    // No speech fed into the VAD this turn.
    await cubit.onTap(); // stop-now, but VAD saw no speech
    await _settle();

    expect(sent, isEmpty);
    expect(gen.runCount, 0);
    expect(cubit.state.phase, VoiceConversationPhase.listening);

    await cubit.exit();
    await cubit.close();
  });

  test(
    'barge-in during speaking cancels TTS and returns to listening',
    () async {
      final cubit = build();

      await cubit.enter();
      await _speakAndStop(cubit, vad);
      expect(cubit.state.phase, VoiceConversationPhase.speaking);

      // Tap to barge in.
      await cubit.onTap();
      await _settle();

      expect(tts.stopCount, greaterThanOrEqualTo(1));
      expect(cubit.state.phase, VoiceConversationPhase.listening);

      await cubit.exit();
      await cubit.close();
    },
  );

  test('exit stops recorder + TTS and returns to idle', () async {
    final cubit = build();

    await cubit.enter();
    await _speakAndStop(cubit, vad);
    expect(cubit.state.phase, VoiceConversationPhase.speaking);

    await cubit.exit();

    expect(cubit.state.phase, VoiceConversationPhase.idle);
    expect(recorder.cancelCount, greaterThanOrEqualTo(1));
    expect(tts.stopCount, greaterThanOrEqualTo(1));

    await cubit.close();
  });

  test('STT error returns to listening without throwing', () async {
    stt.error = const SpeechToTextException('whisper failed');
    final errors = <String>[];
    final cubit = build(errors: errors);

    await cubit.enter();
    await _speakAndStop(cubit, vad);

    expect(sent, isEmpty);
    expect(errors, contains('whisper failed'));
    expect(cubit.state.phase, VoiceConversationPhase.listening);

    await cubit.exit();
    await cubit.close();
  });

  test('generation error returns to listening without throwing', () async {
    gen.error = StateError('model failed');
    final errors = <String>[];
    final cubit = build(errors: errors);

    await cubit.enter();
    await _speakAndStop(cubit, vad);

    expect(cubit.state.phase, VoiceConversationPhase.listening);
    expect(errors, isNotEmpty);

    await cubit.exit();
    await cubit.close();
  });

  test('TTS unavailable skips speaking and keeps listening', () async {
    tts.available = false;
    final cubit = build();

    await cubit.enter();
    final startsBefore = recorder.startCount;
    await _speakAndStop(cubit, vad);

    expect(tts.spoken, isEmpty);
    expect(cubit.state.phase, VoiceConversationPhase.listening);
    expect(recorder.startCount, greaterThan(startsBefore));

    await cubit.exit();
    await cubit.close();
  });

  test('TTS speak error returns to listening without throwing', () async {
    tts.speakError = const TextToSpeechException('engine down');
    final errors = <String>[];
    final cubit = build(errors: errors);

    await cubit.enter();
    await _speakAndStop(cubit, vad);

    expect(errors, contains('engine down'));
    expect(cubit.state.phase, VoiceConversationPhase.listening);

    await cubit.exit();
    await cubit.close();
  });

  test('mic permission failure on enter exits to idle', () async {
    final errors = <String>[];
    final cubit = build(errors: errors);
    recorder.failStart = true;

    await cubit.enter();
    await _settle();

    expect(cubit.state.phase, VoiceConversationPhase.idle);
    expect(errors, contains('mic denied'));

    await cubit.close();
  });

  test('empty reply text loops without speaking', () async {
    gen.reply = '   ';
    final cubit = build();

    await cubit.enter();
    await _speakAndStop(cubit, vad);

    expect(tts.spoken, isEmpty);
    expect(cubit.state.phase, VoiceConversationPhase.listening);

    await cubit.exit();
    await cubit.close();
  });
}
