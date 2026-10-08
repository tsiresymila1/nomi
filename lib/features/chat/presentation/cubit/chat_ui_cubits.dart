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

class ChatGenerationFailureState {
  const ChatGenerationFailureState({
    required this.chatId,
    required this.userMessageId,
    required this.displayMessage,
    required this.canRetry,
    this.remoteFallback,
  });

  final int chatId;
  final int userMessageId;
  final String displayMessage;
  final bool canRetry;
  final RemoteFallbackProposal? remoteFallback;
}

class RemoteFallbackProposal {
  const RemoteFallbackProposal({
    required this.modelId,
    required this.modelName,
    required this.providerLabel,
  });

  final int modelId;
  final String modelName;
  final String providerLabel;
}

class ChatGenerationFailureCubit extends Cubit<ChatGenerationFailureState?> {
  ChatGenerationFailureCubit() : super(null);

  void fail({
    required int chatId,
    required int userMessageId,
    required String displayMessage,
    required bool canRetry,
    RemoteFallbackProposal? remoteFallback,
  }) {
    emit(
      ChatGenerationFailureState(
        chatId: chatId,
        userMessageId: userMessageId,
        displayMessage: displayMessage,
        canRetry: canRetry,
        remoteFallback: remoteFallback,
      ),
    );
  }

  void clear() {
    if (state != null) emit(null);
  }
}

enum ChatModelSwitchPhase {
  idle,
  stoppingGeneration,
  unloading,
  loading,
  ready,
  failed,
}

enum ChatModelSwitchOrigin {
  backgroundWarmup,
  selection,
  installation,
  automaticSelection,
}

class ChatModelSwitchState {
  const ChatModelSwitchState({
    required this.phase,
    required this.operationId,
    this.modelId,
    this.modelName,
    this.origin,
    this.errorMessage,
  });

  const ChatModelSwitchState.idle()
    : phase = ChatModelSwitchPhase.idle,
      operationId = 0,
      modelId = null,
      modelName = null,
      origin = null,
      errorMessage = null;

  final ChatModelSwitchPhase phase;
  final int operationId;
  final int? modelId;
  final String? modelName;
  final ChatModelSwitchOrigin? origin;
  final String? errorMessage;

  bool get isBusy => switch (phase) {
    ChatModelSwitchPhase.stoppingGeneration ||
    ChatModelSwitchPhase.unloading ||
    ChatModelSwitchPhase.loading => true,
    _ => false,
  };
}

class ChatModelSwitchingCubit extends Cubit<ChatModelSwitchState> {
  ChatModelSwitchingCubit() : super(const ChatModelSwitchState.idle());

  int _nextOperationId = 0;

  int begin({
    required int modelId,
    required String modelName,
    required ChatModelSwitchOrigin origin,
    ChatModelSwitchPhase initialPhase = ChatModelSwitchPhase.stoppingGeneration,
  }) {
    final operationId = ++_nextOperationId;
    emit(
      ChatModelSwitchState(
        phase: initialPhase,
        operationId: operationId,
        modelId: modelId,
        modelName: modelName,
        origin: origin,
      ),
    );
    return operationId;
  }

  void advance(int operationId, ChatModelSwitchPhase phase) {
    if (!_owns(operationId)) return;
    emit(
      ChatModelSwitchState(
        phase: phase,
        operationId: state.operationId,
        modelId: state.modelId,
        modelName: state.modelName,
        origin: state.origin,
      ),
    );
  }

  void complete(int operationId) {
    advance(operationId, ChatModelSwitchPhase.ready);
  }

  void fail(int operationId, String message) {
    if (!_owns(operationId)) return;
    emit(
      ChatModelSwitchState(
        phase: ChatModelSwitchPhase.failed,
        operationId: state.operationId,
        modelId: state.modelId,
        modelName: state.modelName,
        origin: state.origin,
        errorMessage: message,
      ),
    );
  }

  bool _owns(int operationId) => state.operationId == operationId;
}
