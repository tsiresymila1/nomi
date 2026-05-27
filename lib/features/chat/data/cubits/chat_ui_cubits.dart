import 'package:flutter_bloc/flutter_bloc.dart';

class ChatContextWindowState {
  const ChatContextWindowState({
    required this.maxTokens,
    required this.reservedOutputTokens,
    required this.estimatedPromptTokens,
    required this.remainingTokens,
    required this.compactedMessages,
  });

  final int maxTokens;
  final int reservedOutputTokens;
  final int estimatedPromptTokens;
  final int remainingTokens;
  final int compactedMessages;
}

class ChatContextWindowCubit extends Cubit<ChatContextWindowState?> {
  ChatContextWindowCubit() : super(null);

  void update(ChatContextWindowState next) {
    emit(next);
  }

  void clear() {
    emit(null);
  }
}

class ChatDraftResponseCubit extends Cubit<String?> {
  ChatDraftResponseCubit() : super(null);

  void setDraft(String value) {
    emit(value);
  }

  void clear() {
    emit(null);
  }
}

class ChatDraftThinkingCubit extends Cubit<String?> {
  ChatDraftThinkingCubit() : super(null);

  void setDraft(String value) {
    emit(value);
  }

  void clear() {
    emit(null);
  }
}

class ChatGeneratingCubit extends Cubit<bool> {
  ChatGeneratingCubit() : super(false);

  void setGenerating(bool value) {
    emit(value);
  }
}

class ChatToolWaitingCubit extends Cubit<String?> {
  ChatToolWaitingCubit() : super(null);

  void setWaitingTool(String toolName) {
    emit(toolName);
  }

  void clear() {
    emit(null);
  }
}

class ChatModelSwitchingCubit extends Cubit<bool> {
  ChatModelSwitchingCubit() : super(false);

  void start() {
    emit(true);
  }

  void stop() {
    emit(false);
  }
}
