import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/services/speech_segmenter.dart';
import 'package:gena/features/chat/data/services/speech_to_text.dart';
import 'package:gena/features/chat/data/services/text_to_speech.dart';
import 'package:gena/features/chat/presentation/cubit/voice_conversation_cubit.dart';

/// Fake neural-VAD segmenter. Tests drive an utterance by calling [emitSpeech]
/// (the real Silero VAD fires `onSpeech` when the user stops talking).
class _FakeSegmenter implements SpeechSegmenter {
  bool failStart = false;

  int startCount = 0;
  int pauseCount = 0;
  int stopCount = 0;
  int disposeCount = 0;

  final StreamController<double> _level = StreamController<double>.broadcast();
  final StreamController<SpeechSegment> _speech =
      StreamController<SpeechSegment>.broadcast();
  final StreamController<void> _speechStart =
      StreamController<void>.broadcast();

  @override
  Stream<double> get levelStream => _level.stream;

  @override
  Stream<SpeechSegment> get onSpeech => _speech.stream;

  @override
  Stream<void> get onSpeechStart => _speechStart.stream;

  @override
  Future<void> start() async {
    startCount++;
    if (failStart) {
      throw const SpeechToTextException('mic denied');
    }
  }

  @override
  Future<void> pause() async {
    pauseCount++;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    await _level.close();
    await _speech.close();
    await _speechStart.close();
  }

  void emitLevel(double v) => _level.add(v);
  void emitSpeechStart() => _speechStart.add(null);
  void emitSpeech({List<double>? pcm}) =>
      _speech.add(SpeechSegment(pcm16: pcm ?? const <double>[0.1, -0.1, 0.2]));
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

/// Emits a completed utterance and lets the cubit advance through transcribe →
/// send → speak.
Future<void> _speak(VoiceConversationCubit cubit, _FakeSegmenter seg) async {
  seg.emitSpeechStart();
  seg.emitSpeech();
  await _settle();
  await _settle();
}

void main() {
  late _FakeSegmenter seg;
  late _FakeSpeechToText stt;
  late _FakeTextToSpeech tts;
  late _FakeGenerationSignal gen;
  late List<String> sent;

  VoiceConversationCubit build({List<String>? errors}) {
    sent = <String>[];
    seg = _FakeSegmenter();
    return VoiceConversationCubit(
      segmenter: seg,
      speechToText: stt,
      textToSpeech: tts,
      sendMessage: (text) async {
        sent.add(text);
      },
      generationSignal: gen,
      onError: errors?.add,
      // Avoid touching the filesystem in unit tests.
      writeWav: (segment) async => 'segment.wav',
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
    expect(seg.startCount, 1);

    // The user speaks an utterance.
    await _speak(cubit, seg);

    // Segment paused the mic, transcribe ran, message sent, reply spoken.
    expect(seg.pauseCount, greaterThanOrEqualTo(1));
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
    expect(seg.startCount, 2);

    await cubit.exit();
    await cubit.close();
  });

  test('level stream drives the orb only while listening', () async {
    final cubit = build();
    await cubit.enter();

    seg.emitLevel(0.8);
    await _settle();
    expect(cubit.state.micLevel, closeTo(0.8, 1e-9));

    await cubit.exit();
    await cubit.close();
  });

  test('blank transcript returns to listening without sending', () async {
    stt.text = '   ';
    final cubit = build();

    await cubit.enter();
    await _speak(cubit, seg);

    expect(sent, isEmpty);
    expect(gen.runCount, 0);
    expect(cubit.state.phase, VoiceConversationPhase.listening);
    // Started once on enter, again after the blank transcript.
    expect(seg.startCount, 2);

    await cubit.exit();
    await cubit.close();
  });

  test('an empty segment loops without sending', () async {
    final cubit = build();

    await cubit.enter();
    seg.emitSpeech(pcm: const <double>[]);
    await _settle();
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
      await _speak(cubit, seg);
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

  test('exit stops segmenter + TTS and returns to idle', () async {
    final cubit = build();

    await cubit.enter();
    await _speak(cubit, seg);
    expect(cubit.state.phase, VoiceConversationPhase.speaking);

    await cubit.exit();

    expect(cubit.state.phase, VoiceConversationPhase.idle);
    expect(seg.stopCount, greaterThanOrEqualTo(1));
    expect(tts.stopCount, greaterThanOrEqualTo(1));

    await cubit.close();
  });

  test('close disposes the segmenter', () async {
    final cubit = build();
    await cubit.enter();
    await cubit.close();
    expect(seg.disposeCount, 1);
  });

  test('STT error returns to listening without throwing', () async {
    stt.error = const SpeechToTextException('whisper failed');
    final errors = <String>[];
    final cubit = build(errors: errors);

    await cubit.enter();
    await _speak(cubit, seg);

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
    await _speak(cubit, seg);

    expect(cubit.state.phase, VoiceConversationPhase.listening);
    expect(errors, isNotEmpty);

    await cubit.exit();
    await cubit.close();
  });

  test('TTS unavailable skips speaking and keeps listening', () async {
    tts.available = false;
    final cubit = build();

    await cubit.enter();
    final startsBefore = seg.startCount;
    await _speak(cubit, seg);

    expect(tts.spoken, isEmpty);
    expect(cubit.state.phase, VoiceConversationPhase.listening);
    expect(seg.startCount, greaterThan(startsBefore));

    await cubit.exit();
    await cubit.close();
  });

  test('TTS speak error returns to listening without throwing', () async {
    tts.speakError = const TextToSpeechException('engine down');
    final errors = <String>[];
    final cubit = build(errors: errors);

    await cubit.enter();
    await _speak(cubit, seg);

    expect(errors, contains('engine down'));
    expect(cubit.state.phase, VoiceConversationPhase.listening);

    await cubit.exit();
    await cubit.close();
  });

  test('mic permission failure on enter exits to idle', () async {
    final errors = <String>[];
    final cubit = build(errors: errors);
    seg.failStart = true;

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
    await _speak(cubit, seg);

    expect(tts.spoken, isEmpty);
    expect(cubit.state.phase, VoiceConversationPhase.listening);

    await cubit.exit();
    await cubit.close();
  });
}
