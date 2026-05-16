import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatDraftResponseProvider =
    NotifierProvider<ChatDraftResponseNotifier, String?>(
      ChatDraftResponseNotifier.new,
    );

class ChatDraftResponseNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setDraft(String value) {
    state = value;
  }

  void clear() {
    state = null;
  }
}

final chatGeneratingProvider = NotifierProvider<ChatGeneratingNotifier, bool>(
  ChatGeneratingNotifier.new,
);

class ChatGeneratingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setGenerating(bool value) {
    state = value;
  }
}
