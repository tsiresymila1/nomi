import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatModelSwitchingProvider =
    NotifierProvider<ChatModelSwitchingNotifier, bool>(
      ChatModelSwitchingNotifier.new,
    );

class ChatModelSwitchingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void start() {
    state = true;
  }

  void stop() {
    state = false;
  }
}
