import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/services/local_neural_text_to_speech.dart';
import 'package:gena/features/chat/data/services/routing_text_to_speech.dart';
import 'package:gena/features/chat/data/services/text_to_speech.dart';

void main() {
  test(
    'routes speech to the selected backend and stops the inactive one',
    () async {
      final native = _FakeTextToSpeech();
      final local = _FakeLocalTextToSpeech();
      var backend = TextToSpeechBackend.native;
      final routing = RoutingTextToSpeech(
        native: native,
        local: local,
        selectedBackend: () => backend,
      );
      addTearDown(routing.dispose);

      await routing.speak('native');
      expect(native.spoken, ['native']);
      expect(local.stopCount, 1);

      backend = TextToSpeechBackend.llamaDart;
      await routing.speak('local');
      expect(local.spoken, ['local']);
      expect(native.stopCount, 1);
    },
  );
}

class _FakeTextToSpeech implements TextToSpeech {
  final spoken = <String>[];
  final controller = StreamController<bool>.broadcast();
  int stopCount = 0;

  @override
  bool get isAvailable => true;

  @override
  Stream<bool> get speakingChanges => controller.stream;

  @override
  Future<void> clear() async => stopCount++;

  @override
  Future<void> dispose() => controller.close();

  @override
  Future<void> enqueue(String text) async => spoken.add(text);

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stopCount++;
}

class _FakeLocalTextToSpeech extends _FakeTextToSpeech
    implements LocalNeuralTextToSpeech {
  @override
  Future<void> prepare() async {}

  @override
  Future<void> unload() async {}
}
