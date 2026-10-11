import 'dart:async';

import 'package:gena/features/chat/data/services/local_neural_text_to_speech.dart';
import 'package:gena/features/chat/data/services/text_to_speech.dart';

class RoutingTextToSpeech implements TextToSpeech {
  RoutingTextToSpeech({
    required TextToSpeech native,
    required LocalNeuralTextToSpeech local,
    required TextToSpeechBackend Function() selectedBackend,
  }) : _native = native,
       _local = local,
       _selectedBackend = selectedBackend {
    _nativeSubscription = _native.speakingChanges.listen(_speaking.add);
    _localSubscription = _local.speakingChanges.listen(_speaking.add);
  }

  final TextToSpeech _native;
  final LocalNeuralTextToSpeech _local;
  final TextToSpeechBackend Function() _selectedBackend;
  final StreamController<bool> _speaking = StreamController<bool>.broadcast();
  late final StreamSubscription<bool> _nativeSubscription;
  late final StreamSubscription<bool> _localSubscription;

  TextToSpeech get _selected =>
      _selectedBackend() == TextToSpeechBackend.llamaDart ? _local : _native;

  @override
  bool get isAvailable => _selected.isAvailable;

  @override
  Stream<bool> get speakingChanges => _speaking.stream;

  @override
  Future<void> speak(String text) async {
    await _stopInactive();
    await _selected.speak(text);
  }

  @override
  Future<void> enqueue(String text) async {
    await _stopInactive();
    await _selected.enqueue(text);
  }

  Future<void> _stopInactive() =>
      _selectedBackend() == TextToSpeechBackend.llamaDart
      ? _native.stop()
      : _local.stop();

  @override
  Future<void> clear() async {
    await Future.wait([_native.clear(), _local.clear()]);
  }

  @override
  Future<void> stop() async {
    await Future.wait([_native.stop(), _local.stop()]);
  }

  @override
  Future<void> dispose() async {
    await _nativeSubscription.cancel();
    await _localSubscription.cancel();
    await Future.wait([_native.dispose(), _local.dispose()]);
    await _speaking.close();
  }
}
