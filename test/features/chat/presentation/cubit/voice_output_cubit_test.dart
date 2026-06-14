import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/services/text_to_speech.dart';
import 'package:gena/features/chat/presentation/cubit/voice_output_cubit.dart';

/// Records what was spoken and exposes a controllable [speakingChanges] stream
/// so tests can simulate the engine's start/completion callbacks.
class _FakeTextToSpeech implements TextToSpeech {
  _FakeTextToSpeech({this.speakError});

  final Object? speakError;

  final List<String> spokenTexts = <String>[];
  final List<String> queuedTexts = <String>[];
  int stopCount = 0;
  int clearCount = 0;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  bool get isAvailable => true;

  @override
  Stream<bool> get speakingChanges => _controller.stream;

  @override
  Future<void> speak(String text) async {
    if (speakError != null) throw speakError!;
    spokenTexts.add(text);
    _controller.add(true);
  }

  @override
  Future<void> enqueue(String text) async {
    if (speakError != null) throw speakError!;
    queuedTexts.add(text);
  }

  @override
  Future<void> clear() async {
    clearCount++;
    queuedTexts.clear();
    _controller.add(false);
  }

  @override
  Future<void> stop() async {
    stopCount++;
    queuedTexts.clear();
    _controller.add(false);
  }

  /// Simulates the engine finishing an utterance on its own.
  void completeSpeaking() => _controller.add(false);

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  late _FakeTextToSpeech tts;

  setUp(() {
    tts = _FakeTextToSpeech();
  });

  tearDown(() async {
    await tts.dispose();
  });

  VoiceOutputCubit buildCubit({List<String>? errors}) {
    return VoiceOutputCubit(textToSpeech: tts, onError: errors?.add);
  }

  test('toggle starts speaking and sets the speaking message id', () async {
    final cubit = buildCubit();

    await cubit.toggle('m1', 'Hello world');

    expect(cubit.state.isSpeaking, isTrue);
    expect(cubit.state.speakingMessageId, 'm1');
    expect(cubit.state.isSpeakingMessage('m1'), isTrue);
    expect(tts.spokenTexts, ['Hello world']);

    await cubit.close();
  });

  test('toggling the same speaking message stops it', () async {
    final cubit = buildCubit();

    await cubit.toggle('m1', 'Hello');
    expect(cubit.state.isSpeakingMessage('m1'), isTrue);

    await cubit.toggle('m1', 'Hello');

    expect(cubit.state.isSpeaking, isFalse);
    expect(cubit.state.speakingMessageId, isNull);
    expect(tts.stopCount, 1);

    await cubit.close();
  });

  test('toggling a different message switches the speaking target', () async {
    final cubit = buildCubit();

    await cubit.toggle('m1', 'First');
    expect(cubit.state.speakingMessageId, 'm1');

    await cubit.toggle('m2', 'Second');

    expect(cubit.state.isSpeakingMessage('m2'), isTrue);
    expect(cubit.state.speakingMessageId, 'm2');
    expect(tts.spokenTexts, ['First', 'Second']);

    await cubit.close();
  });

  test('speakingChanges=false clears the speaking state', () async {
    final cubit = buildCubit();

    await cubit.toggle('m1', 'Hello');
    expect(cubit.state.isSpeaking, isTrue);

    tts.completeSpeaking();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.isSpeaking, isFalse);
    expect(cubit.state.speakingMessageId, isNull);

    await cubit.close();
  });

  test('markdown is stripped to plain text before speak is called', () async {
    final cubit = buildCubit();

    const markdown =
        '# Heading\n'
        '**Bold** and *italic* and `code` words.\n'
        '- bullet item\n'
        '> quoted line\n'
        'See [the docs](https://example.com) for more.\n'
        '```dart\nprint("hi");\n```';

    await cubit.toggle('m1', markdown);

    // The message is chunked into sentences: the first plays via speak(), the
    // rest are queued. The combined spoken text must be markdown-free.
    expect(tts.spokenTexts, isNotEmpty);
    final spoken = [...tts.spokenTexts, ...tts.queuedTexts].join(' ');

    expect(spoken, isNot(contains('**')));
    expect(spoken, isNot(contains('`')));
    expect(spoken, isNot(contains('#')));
    expect(spoken, isNot(contains('](')));
    expect(spoken, isNot(contains('```')));
    expect(spoken, isNot(contains('https://example.com')));
    expect(spoken, contains('Bold'));
    expect(spoken, contains('the docs'));
    expect(spoken, contains('bullet item'));
    expect(spoken, contains('quoted line'));

    await cubit.close();
  });

  test('a multi-sentence message is chunked: first spoken, rest queued', () {
    final cubit = buildCubit();

    return cubit
        .toggle('m1', 'First sentence. Second sentence. Third sentence.')
        .then((_) async {
          expect(tts.spokenTexts, ['First sentence.']);
          expect(tts.queuedTexts, ['Second sentence.', 'Third sentence.']);
          await cubit.close();
        });
  });

  test('a speak failure surfaces an error and clears state', () async {
    final failingTts = _FakeTextToSpeech(
      speakError: const TextToSpeechException('engine down'),
    );
    final errors = <String>[];
    final cubit = VoiceOutputCubit(
      textToSpeech: failingTts,
      onError: errors.add,
    );

    await cubit.toggle('m1', 'Hello');

    expect(cubit.state.isSpeaking, isFalse);
    expect(cubit.state.speakingMessageId, isNull);
    expect(errors, contains('engine down'));

    await cubit.close();
    await failingTts.dispose();
  });
}
