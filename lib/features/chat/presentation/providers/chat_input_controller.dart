import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/providers/chat_thread_actions_provider.dart';

final chatInputControllerProvider =
    NotifierProvider<ChatInputController, ChatInputState>(
      ChatInputController.new,
    );

class ChatInputState {
  final File? selectedFile;
  final bool isSending;

  const ChatInputState({this.selectedFile, this.isSending = false});

  ChatInputState copyWith({
    File? selectedFile,
    bool updateSelectedFile = false,
    bool? isSending,
  }) {
    return ChatInputState(
      selectedFile: updateSelectedFile ? selectedFile : this.selectedFile,
      isSending: isSending ?? this.isSending,
    );
  }
}

class ChatInputController extends Notifier<ChatInputState> {
  @override
  ChatInputState build() => const ChatInputState();

  void selectFile(File? file) {
    state = state.copyWith(selectedFile: file, updateSelectedFile: true);
  }

  Future<void> sendMessage(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || state.isSending) return;

    state = state.copyWith(isSending: true);
    try {
      await ref.read(chatThreadActionsProvider).sendMessage(text);
      state = state.copyWith(selectedFile: null, updateSelectedFile: true);
    } finally {
      state = state.copyWith(isSending: false);
    }
  }
}
