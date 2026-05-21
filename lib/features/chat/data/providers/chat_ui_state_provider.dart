import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatDraftResponseProvider =
    NotifierProvider<ChatDraftResponseNotifier, String?>(
      ChatDraftResponseNotifier.new,
    );

final chatContextWindowProvider =
    NotifierProvider<ChatContextWindowNotifier, ChatContextWindowState?>(
      ChatContextWindowNotifier.new,
    );

final chatDraftThinkingProvider =
    NotifierProvider<ChatDraftThinkingNotifier, String?>(
      ChatDraftThinkingNotifier.new,
    );

class ChatContextWindowState {
  final int maxTokens;
  final int reservedOutputTokens;
  final int estimatedPromptTokens;
  final int remainingTokens;
  final int compactedMessages;

  const ChatContextWindowState({
    required this.maxTokens,
    required this.reservedOutputTokens,
    required this.estimatedPromptTokens,
    required this.remainingTokens,
    required this.compactedMessages,
  });
}

class ChatContextWindowNotifier extends Notifier<ChatContextWindowState?> {
  @override
  ChatContextWindowState? build() => null;

  void update(ChatContextWindowState next) {
    state = next;
  }

  void clear() {
    state = null;
  }
}

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

class ChatDraftThinkingNotifier extends Notifier<String?> {
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

final chatToolWaitingProvider =
    NotifierProvider<ChatToolWaitingNotifier, String?>(
      ChatToolWaitingNotifier.new,
    );

class ChatToolWaitingNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setWaitingTool(String toolName) {
    state = toolName;
  }

  void clear() {
    state = null;
  }
}
