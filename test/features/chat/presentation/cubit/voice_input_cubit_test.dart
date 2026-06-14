import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/services/chat_thread_actions_service.dart';
import 'package:gena/features/chat/data/services/speech_to_text.dart';
import 'package:gena/features/chat/presentation/cubit/chat_input_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/voice_input_cubit.dart';

class _FakeRecorder implements VoiceAudioRecorder {
  _FakeRecorder({this.failStart = false});

  String? wavPath = 'recording.wav';
  bool failStart;
  bool started = false;
  bool stopped = false;
  bool cancelled = false;

  @override
  Future<void> start() async {
    if (failStart) {
      throw const SpeechToTextException('Microphone permission is required.');
    }
    started = true;
  }

  @override
  Future<String?> stop() async {
    stopped = true;
    return wavPath;
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
  }
}

class _FakeSpeechToText implements SpeechToText {
  _FakeSpeechToText({this.result, this.error});

  final SttResult? result;
  final Object? error;

  @override
  bool get isAvailable => true;

  @override
  Future<void> ensureModelReady() async {}

  @override
  Future<SttResult> transcribe(String wavPath, {String lang = 'auto'}) async {
    if (error != null) throw error!;
    return result ?? const SttResult(text: '');
  }
}

/// Stub: voice input never touches generation, so a no-dependency cubit is fine.
class _StubChatThreadActions implements ChatThreadActions {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ChatInputCubit chatInputCubit;

  setUp(() {
    chatInputCubit = ChatInputCubit(
      chatThreadActions: _StubChatThreadActions(),
    );
  });

  tearDown(() {
    chatInputCubit.close();
  });

  VoiceInputCubit buildCubit({
    required VoiceAudioRecorder recorder,
    required SpeechToText speechToText,
    List<String>? errors,
  }) {
    return VoiceInputCubit(
      recorder: recorder,
      speechToText: speechToText,
      chatInputCubit: chatInputCubit,
      onError: errors?.add,
    );
  }

  test('transcript is appended to the chat input draft', () async {
    chatInputCubit.setDraftText('Note:');
    final recorder = _FakeRecorder();
    final cubit = buildCubit(
      recorder: recorder,
      speechToText: _FakeSpeechToText(
        result: const SttResult(text: 'buy milk', language: 'en'),
      ),
    );

    await cubit.startRecording();
    expect(cubit.state.isRecording, isTrue);

    await cubit.stopAndTranscribe();

    expect(chatInputCubit.state.draftText, 'Note: buy milk');
    expect(cubit.state.status, VoiceInputStatus.idle);
    await cubit.close();
  });

  test(
    'transcribe error surfaces a message and keeps the draft intact',
    () async {
      chatInputCubit.setDraftText('keep me');
      final errors = <String>[];
      final cubit = buildCubit(
        recorder: _FakeRecorder(),
        speechToText: _FakeSpeechToText(
          error: const SpeechToTextException('Transcription failed: boom'),
        ),
        errors: errors,
      );

      await cubit.startRecording();
      await cubit.stopAndTranscribe();

      expect(chatInputCubit.state.draftText, 'keep me');
      expect(errors, contains('Transcription failed: boom'));
      expect(cubit.state.status, VoiceInputStatus.idle);
      await cubit.close();
    },
  );

  test(
    'permission denial on start surfaces a message, no draft change',
    () async {
      chatInputCubit.setDraftText('hi');
      final errors = <String>[];
      final cubit = buildCubit(
        recorder: _FakeRecorder(failStart: true),
        speechToText: _FakeSpeechToText(),
        errors: errors,
      );

      await cubit.startRecording();

      expect(cubit.state.status, VoiceInputStatus.idle);
      expect(errors, isNotEmpty);
      expect(chatInputCubit.state.draftText, 'hi');
      await cubit.close();
    },
  );

  test('cancel discards the recording without transcribing', () async {
    chatInputCubit.setDraftText('hi');
    final recorder = _FakeRecorder();
    final cubit = buildCubit(
      recorder: recorder,
      speechToText: _FakeSpeechToText(
        result: const SttResult(text: 'should not append'),
      ),
    );

    await cubit.startRecording();
    await cubit.cancelRecording();

    expect(recorder.cancelled, isTrue);
    expect(chatInputCubit.state.draftText, 'hi');
    expect(cubit.state.status, VoiceInputStatus.idle);
    await cubit.close();
  });
}
