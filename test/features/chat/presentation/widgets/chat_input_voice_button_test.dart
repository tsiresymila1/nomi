import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/services/chat_thread_actions_service.dart';
import 'package:gena/features/chat/data/services/speech_to_text.dart';
import 'package:gena/features/chat/presentation/cubit/chat_input_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/voice_input_cubit.dart';
import 'package:gena/features/chat/presentation/widgets/chat_input_voice_button.dart';

class _RecorderFake implements VoiceAudioRecorder {
  final amplitudes = StreamController<double>.broadcast();
  bool started = false;
  bool stopped = false;

  @override
  Stream<double> get amplitudeStream => amplitudes.stream;

  @override
  Future<void> start() async => started = true;

  @override
  Future<String?> stop() async {
    stopped = true;
    return '/tmp/voice.wav';
  }

  @override
  Future<void> cancel() async {}
}

class _SpeechToTextFake implements SpeechToText {
  @override
  bool get isAvailable => true;

  @override
  Future<void> ensureModelReady() async {}

  @override
  Future<SttResult> transcribe(String wavPath, {String lang = 'auto'}) async {
    return const SttResult(text: 'hello by voice');
  }
}

class _ChatThreadActionsFake extends Fake implements ChatThreadActions {}

void main() {
  testWidgets('long press records, shows waveform and transcribes on release', (
    tester,
  ) async {
    final recorder = _RecorderFake();
    final inputCubit = ChatInputCubit(
      chatThreadActions: _ChatThreadActionsFake(),
    );
    final voiceCubit = VoiceInputCubit(
      recorder: recorder,
      speechToText: _SpeechToTextFake(),
      chatInputCubit: inputCubit,
    );
    addTearDown(() async {
      await voiceCubit.close();
      await inputCubit.close();
      await recorder.amplitudes.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ChatInputVoiceButton(cubit: voiceCubit, enabled: true),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ChatInputVoiceButton)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

    expect(recorder.started, isTrue);
    expect(voiceCubit.state.isRecording, isTrue);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNWidgets(5));

    recorder.amplitudes.add(0.9);
    await tester.pump(const Duration(milliseconds: 100));
    expect(voiceCubit.state.micLevel, greaterThan(0));

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(recorder.stopped, isTrue);
    expect(inputCubit.state.draftText, 'hello by voice');
    expect(voiceCubit.state.status, VoiceInputStatus.idle);
  });
}
