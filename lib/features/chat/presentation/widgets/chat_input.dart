import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';

class ChatInput extends ConsumerStatefulWidget {
  const ChatInput({super.key});

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text;
    _controller.clear();
    await ref.read(chatInputControllerProvider.notifier).sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final isGenerating = ref.watch(chatGeneratingProvider);
    final inputState = ref.watch(chatInputControllerProvider);
    final activeGemmaChat = ref.watch(activeGemmaChatProvider);
    final canAttachImage = activeGemmaChat.maybeWhen(
      data: (session) => session?.chat.supportImage ?? false,
      orElse: () => false,
    );
    final canRecordAudio = activeGemmaChat.maybeWhen(
      data: (session) => session?.chat.supportAudio ?? false,
      orElse: () => false,
    );
    final hasSelectedImage = inputState.selectedImagePath != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (canAttachImage)
            IconButton(
              icon: Icon(
                hasSelectedImage ? Icons.image : Icons.add_circle_outline,
              ),
              onPressed: () {
                if (hasSelectedImage) {
                  ref
                      .read(chatInputControllerProvider.notifier)
                      .clearSelectedImage();
                } else {
                  ref
                      .read(chatInputControllerProvider.notifier)
                      .pickImageFromDevice();
                }
              },
              tooltip: hasSelectedImage ? 'Remove selected image' : 'Add image',
            ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  if (hasSelectedImage)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                      ).copyWith(top: 8),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.file(
                                  File(inputState.selectedImagePath!),
                                  height: 30,
                                  width: 30,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                child: InkWell(
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.red,
                                  ),
                                  onTap: () {
                                    if (hasSelectedImage) {
                                      ref
                                          .read(
                                            chatInputControllerProvider
                                                .notifier,
                                          )
                                          .clearSelectedImage();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: (inputState.isSending || isGenerating)
                ? null
                : _sendMessage,
          ),
          if (canRecordAudio)
            IconButton(
              icon: const Icon(Icons.mic),
              onPressed: () {},
              tooltip: 'Voice input',
            ),
        ],
      ),
    );
  }
}
