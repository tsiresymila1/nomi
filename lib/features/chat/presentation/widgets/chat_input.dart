import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/cubits/chat_input_cubit.dart';
import 'package:gena/features/chat/data/cubits/chat_ui_cubits.dart';
import 'package:gena/features/chat/data/providers/active_model_info_provider.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:hugeicons/hugeicons.dart';

class ChatInput extends StatefulWidget {
  const ChatInput({super.key});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
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
    await sl<ChatInputCubit>().sendMessage(text);
  }

  Future<void> _stopGeneration() async {
    await sl<ChatInputCubit>().stopGeneration();
  }

  Future<void> _openAttachmentMenu({
    required BuildContext context,
    required bool canAttachImage,
    required bool hasSelectedImage,
  }) async {
    if (hasSelectedImage) {
      sl<ChatInputCubit>().clearSelectedImage();
      return;
    }

    final options = _buildAttachmentOptions(canAttachImage: canAttachImage);
    if (options.isEmpty) {
      await AppToast.show('No attachments available for this model.');
      return;
    }

    final selectedSource = await showModalBottomSheet<ChatAttachmentSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map(
                  (option) => ListTile(
                    leading: Icon(option.icon),
                    title: Text(option.label),
                    onTap: () => Navigator.of(sheetContext).pop(option.source),
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );

    if (selectedSource == null) return;
    await sl<ChatInputCubit>().pickImage(source: selectedSource);
  }

  List<_AttachmentOption> _buildAttachmentOptions({
    required bool canAttachImage,
  }) {
    final options = <_AttachmentOption>[];
    if (canAttachImage) {
      options.addAll(const <_AttachmentOption>[
        _AttachmentOption(
          source: ChatAttachmentSource.camera,
          label: 'Camera',
          icon: Icons.camera_alt_outlined,
        ),
        _AttachmentOption(
          source: ChatAttachmentSource.gallery,
          label: 'Gallery',
          icon: Icons.photo_library_outlined,
        ),
      ]);
    }
    return options;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocBuilder<ChatGeneratingCubit, bool>(
      builder: (context, isGenerating) {
        return BlocBuilder<ChatInputCubit, ChatInputState>(
          builder: (context, inputState) {
            return StreamBuilder<ModelInfo?>(
              stream: sl<ActiveModelInfoResolver>().watchActiveModelInfo(),
              builder: (context, activeModelSnapshot) {
                final activeModel = activeModelSnapshot.data;
                final canAttachImage = activeModel?.supportImage ?? false;
                final canRecordAudio = activeModel?.supportAudio ?? false;
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

                return _buildInputField(
                  context: context,
                  colorScheme: colorScheme,
                  isGenerating: isGenerating,
                  inputState: inputState,
                  canAttachImage: canAttachImage,
                  canRecordAudio: canRecordAudio,
                  hasSelectedImage: hasSelectedImage,
                  hasSendableContent: hasSendableContent,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInputField({
    required BuildContext context,
    required ColorScheme colorScheme,
    required bool isGenerating,
    required ChatInputState inputState,
    required bool canAttachImage,
    required bool canRecordAudio,
    required bool hasSelectedImage,
    required bool hasSendableContent,
  }) {
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(color: Colors.transparent),
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
                        : () => _openAttachmentMenu(
                            context: context,
                            canAttachImage: canAttachImage,
                            hasSelectedImage: hasSelectedImage,
                          ),
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
                  ),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: colorScheme.surfaceContainerHigh,
                    ),
                    child: Column(
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
                                        height: 100,
                                        width: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      child: InkWell(
                                        child: HugeIcon(
                                          icon: HugeIcons.strokeRoundedAdd01,
                                          size: 22,
                                          color:
                                              colorScheme.surfaceContainerHigh,
                                        ),
                                        onTap: () {
                                          sl<ChatInputCubit>().clearSelectedImage();
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
                              borderSide: BorderSide.none,
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
                            prefixIcon:
                                _hasFocus && canAttachImage && !hasSelectedImage
                                ? Padding(
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
                                              : () => _openAttachmentMenu(
                                                  context: context,
                                                  canAttachImage:
                                                      canAttachImage,
                                                  hasSelectedImage:
                                                      hasSelectedImage,
                                                ),
                                          tooltip: hasSelectedImage
                                              ? 'Remove selected image'
                                              : 'Add image',
                                        ),
                                      ],
                                    ),
                                  )
                                : null,
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
                                      onPressed: () {
                                        AppToast.show("Coming soon ...");
                                      },
                                      tooltip: 'Voice input',
                                      color: colorScheme.primary,
                                    ),
                                  if (isGenerating || hasSendableContent)
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                        color: !isGenerating
                                            ? Colors.green[900]
                                            : null,
                                      ),
                                      child: suffixActionButton(
                                        icon: isGenerating
                                            ? HugeIcons.strokeRoundedStop
                                            : HugeIcons.strokeRoundedArrowUp02,
                                        color: isGenerating
                                            ? Colors.red
                                            : Colors.white,
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

class _AttachmentOption {
  final ChatAttachmentSource source;
  final String label;
  final IconData icon;

  const _AttachmentOption({
    required this.source,
    required this.label,
    required this.icon,
  });
}
