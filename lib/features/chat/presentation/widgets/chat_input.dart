import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:hugeicons/hugeicons.dart';

class ChatInput extends ConsumerStatefulWidget {
  const ChatInput({super.key});

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _wasKeyboardVisible = false;
  bool _hasTypedContent = false;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onInputChanged);
    _focusNode.addListener(() {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    });
  }

  void _onInputChanged() {
    final hasTyped = _controller.text.trim().isNotEmpty;
    if (hasTyped == _hasTypedContent) return;
    setState(() => _hasTypedContent = hasTyped);
  }

  @override
  void dispose() {
    _controller.removeListener(_onInputChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text;
    _controller.clear();
    await ref.read(chatInputControllerProvider.notifier).sendMessage(text);
  }

  Future<void> _stopGeneration() async {
    await ref.read(chatInputControllerProvider.notifier).stopGeneration();
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
    final hasSendableContent = _hasTypedContent || hasSelectedImage;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (_wasKeyboardVisible && !keyboardVisible && _focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNode.unfocus();
      });
    }
    _wasKeyboardVisible = keyboardVisible;

    Widget suffixActionButton({
      required dynamic icon,
      required VoidCallback? onPressed,
      Color? color,
      String? tooltip,
    }) {
      return IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        tooltip: tooltip,
        icon: HugeIcon(icon: icon, size: 25, color: color),
        splashRadius: 16,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!_hasFocus || hasSelectedImage)
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      side: BorderSide(color: colorScheme.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    onPressed: isGenerating
                        ? null
                        : () {
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
                    icon: HugeIcon(icon:HugeIcons.strokeRoundedAdd01),
                  ),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      // border: Border.all(color: colorScheme.outline)
                      color: colorScheme.surfaceContainerHigh,
                    ),
                    child: Column(
                      children: [
                        if (hasSelectedImage)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20).copyWith(top: 8),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.file(
                                        File(inputState.selectedImagePath!),
                                        height: 100,
                                        width: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      child: InkWell(
                                        child:  HugeIcon(
                                          icon: HugeIcons.strokeRoundedAdd01,
                                          size: 22,
                                          color: colorScheme.surfaceContainerHigh,
                                        ),
                                        onTap: () {
                                          ref
                                              .read(chatInputControllerProvider.notifier)
                                              .clearSelectedImage();
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
                          focusNode: _focusNode,
                          style: TextStyle(fontSize: 14),
                          onTapOutside: (_) => _focusNode.unfocus(),
                          decoration: InputDecoration(
                            hintStyle: TextStyle(fontSize: 14),
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none
                            ),
                            filled: true,
                            fillColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            suffixIconConstraints: const BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                            prefixIcon: _hasFocus && canAttachImage && !hasSelectedImage ? Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    suffixActionButton(
                                      icon: HugeIcons.strokeRoundedAdd01,
                                      color: hasSelectedImage
                                          ? colorScheme.primary
                                          : null,
                                      onPressed: isGenerating
                                          ? null
                                          : () {
                                              if (hasSelectedImage) {
                                                ref
                                                    .read(
                                                      chatInputControllerProvider
                                                          .notifier,
                                                    )
                                                    .clearSelectedImage();
                                              } else {
                                                ref
                                                    .read(
                                                      chatInputControllerProvider
                                                          .notifier,
                                                    )
                                                    .pickImageFromDevice();
                                              }
                                            },
                                      tooltip: hasSelectedImage
                                          ? 'Remove selected image'
                                          : 'Add image',
                                    ),
                                ],
                              ),
                            ): null,
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isGenerating &&
                                      !hasSendableContent &&
                                      canRecordAudio)
                                    suffixActionButton(
                                      icon: HugeIcons.strokeRoundedMic02,
                                      onPressed: () {},
                                      tooltip: 'Voice input',
                                      color: colorScheme.primary,
                                    ),
                                  if (isGenerating || hasSendableContent)
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(100),
                                        color: !isGenerating ? Colors.green[900]: null,
                                      ),
                                      child: suffixActionButton(
                                        icon: isGenerating
                                            ? HugeIcons.strokeRoundedStop
                                            : HugeIcons.strokeRoundedArrowUp02,
                                        color: isGenerating ? Colors.red : Colors.white,
                                        onPressed: isGenerating
                                            ? _stopGeneration
                                            : (inputState.isSending
                                                  ? null
                                                  : _sendMessage),
                                        tooltip: isGenerating
                                            ? 'Stop generation'
                                            : 'Send',
                                      ),
                                    ),
                                ],
                              ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
