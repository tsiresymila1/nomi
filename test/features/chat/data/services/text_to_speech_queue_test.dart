import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/chat/data/services/text_to_speech.dart';

/// Hand-written fake over the concrete [FlutterTts] plugin. Overriding the
/// methods the wrapper calls keeps the platform method channel out of the test.
/// `speak` records the text and fires the start handler; the test drives the
/// completion handler via [completeCurrent] to simulate an utterance finishing.
class _FakeFlutterTts extends FlutterTts {
  final List<String> spoken = <String>[];
  int stopCount = 0;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spoken.add(text);
    startHandler?.call();
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    stopCount++;
    return 1;
  }

  /// Simulates the engine reporting that the current utterance finished.
  void completeCurrent() => completionHandler?.call();

  /// Simulates the engine cancelling playback.
  void cancelCurrent() => cancelHandler?.call();

  // Defaults applied by the wrapper hit the channel otherwise; no-op them.
  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;
  @override
  Future<dynamic> setPitch(double pitch) async => 1;
  @override
  Future<dynamic> setVolume(double volume) async => 1;
}

const _availableCaps = AppCapabilities(
  platform: AppPlatform.android,
  supportsRemoteModels: true,
  supportsLocalModels: true,
  supportsWorkspaceRag: true,
  supportsSpeechToText: true,
  supportsTextToSpeech: true,
  supportsMcp: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeFlutterTts fake;
  late FlutterTextToSpeech tts;

  setUp(() {
    fake = _FakeFlutterTts();
    tts = FlutterTextToSpeech(tts: fake, capabilities: _availableCaps);
  });

  tearDown(() async {
    await tts.dispose();
  });

  test('enqueue preserves order and speaks the next on completion', () async {
    await tts.enqueue('one');
    await tts.enqueue('two');
    await tts.enqueue('three');

    // Only the first starts immediately; the rest wait in the queue.
    expect(fake.spoken, ['one']);

    fake.completeCurrent();
    await Future<void>.delayed(Duration.zero);
    expect(fake.spoken, ['one', 'two']);

    fake.completeCurrent();
    await Future<void>.delayed(Duration.zero);
    expect(fake.spoken, ['one', 'two', 'three']);
  });

  test('speaking stays true across queued items, idle when drained', () async {
    final states = <bool>[];
    final sub = tts.speakingChanges.listen(states.add);

    await tts.enqueue('a');
    await tts.enqueue('b');
    fake.completeCurrent(); // a -> b
    await Future<void>.delayed(Duration.zero);
    fake.completeCurrent(); // b -> drained
    await Future<void>.delayed(Duration.zero);

    // start(a) -> true, start(b) -> true, drained -> false. No idle between.
    expect(states.last, isFalse);
    expect(states.where((s) => s == false), hasLength(1));

    await sub.cancel();
  });

  test('clear empties the queue and stops the engine', () async {
    await tts.enqueue('one');
    await tts.enqueue('two');
    await tts.enqueue('three');

    await tts.clear();
    expect(fake.stopCount, greaterThanOrEqualTo(1));

    // Completion after clear must not resume a stale queued item.
    fake.completeCurrent();
    await Future<void>.delayed(Duration.zero);
    expect(fake.spoken, ['one']);
  });

  test('stop (barge-in) empties the queue', () async {
    await tts.enqueue('one');
    await tts.enqueue('two');

    await tts.stop();
    fake.completeCurrent();
    await Future<void>.delayed(Duration.zero);

    expect(fake.spoken, ['one']);
    expect(fake.stopCount, greaterThanOrEqualTo(1));
  });

  test('speak clears any pending queue before the one-shot', () async {
    await tts.enqueue('queued one');
    await tts.enqueue('queued two');

    await tts.speak('fresh');
    // The one-shot replaces the queue.
    fake.completeCurrent();
    await Future<void>.delayed(Duration.zero);

    expect(fake.spoken, ['queued one', 'fresh']);
  });

  test('a cancel from the engine clears the queue', () async {
    await tts.enqueue('one');
    await tts.enqueue('two');

    fake.cancelCurrent();
    await Future<void>.delayed(Duration.zero);
    // Cancel should not advance to the queued item.
    expect(fake.spoken, ['one']);
  });

  test('blank text is ignored by enqueue', () async {
    await tts.enqueue('   ');
    expect(fake.spoken, isEmpty);
  });
}
