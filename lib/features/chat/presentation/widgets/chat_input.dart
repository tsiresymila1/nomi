import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/services/chat_thread_actions_service.dart';
import 'package:gena/features/chat/data/models/chat_attachment.dart';
import 'package:gena/features/chat/presentation/cubit/chat_attachments_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/chat_input_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/chat_ui_cubits.dart';
import 'package:gena/features/chat/presentation/cubit/selected_chat_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/voice_input_cubit.dart';
import 'package:gena/features/chat/data/services/active_model_info_service.dart';
import 'package:gena/features/chat/presentation/widgets/chat_input_attachment_button.dart';
import 'package:gena/features/chat/presentation/widgets/chat_input_attachment_preview_list.dart';
import 'package:gena/features/chat/presentation/widgets/chat_input_image_preview.dart';
import 'package:gena/features/chat/presentation/widgets/chat_input_send_button.dart';
import 'package:gena/features/chat/presentation/widgets/chat_input_voice_button.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/image_generation/presentation/cubit/chat_composer_mode_cubit.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_generation_cubit.dart';
import 'package:gena/features/image_generation/presentation/widgets/chat_composer_mode_selector.dart';
import 'package:gena/features/image_generation/presentation/widgets/image_generation_status_panel.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_actions.dart';
import 'package:gena/features/workspace/presentation/cubit/selected_workspace_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

String takeImageGenerationPrompt(TextEditingController controller) {
  final prompt = controller.text.trim();
  if (prompt.isEmpty) return '';
  controller.clear();
  return prompt;
}

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
  Timer? _draftBudgetDebounce;
  LocalMessageBudgetPlan? _draftBudget;
  bool _isEstimatingDraftBudget = false;
  int _draftBudgetRequestId = 0;
  String? _lastSelectedImagePath;
  String? _lastSelectedChatId;
  int? _lastBudgetModelId;
  StreamSubscription<List<ChatAttachmentDraft>>? _attachmentsSubscription;
  List<ChatAttachmentDraft> _attachmentDrafts = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onInputChanged);
    final attachmentsCubit = sl<ChatAttachmentsCubit>();
    _attachmentDrafts = attachmentsCubit.state;
    _attachmentsSubscription = attachmentsCubit.stream.listen((drafts) {
      if (!mounted) return;
      setState(() => _attachmentDrafts = drafts);
      _scheduleDraftBudgetRefresh();
    });
    _focusNode.addListener(() {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    });
  }

  void _onInputChanged() {
    final hasTyped = _controller.text.trim().isNotEmpty;
    if (hasTyped != _hasTypedContent) {
      setState(() => _hasTypedContent = hasTyped);
    }
    // Mirror typed text into the cubit so flows like voice transcription can
    // append to the current draft.
    sl<ChatInputCubit>().setDraftText(_controller.text);
    _scheduleDraftBudgetRefresh();
  }

  /// Syncs the text field with the cubit draft when it changes from outside the
  /// field (e.g. a voice transcript appended via [ChatInputCubit.appendText]).
  void _syncControllerWithDraft(String draftText) {
    if (_controller.text == draftText) return;
    _controller.value = TextEditingValue(
      text: draftText,
      selection: TextSelection.collapsed(offset: draftText.length),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onInputChanged);
    unawaited(_attachmentsSubscription?.cancel());
    _draftBudgetDebounce?.cancel();
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

  Future<void> _generateImage() async {
    final chatId = sl<SelectedChatCubit>().state;
    if (chatId == null) return;
    final prompt = takeImageGenerationPrompt(_controller);
    if (prompt.isEmpty) return;
    await sl<ImageGenerationCubit>().generate(prompt, chatId: chatId);
  }

  Future<void> _confirmRemoveImageModel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove SDXS-512?'),
        content: const Text(
          'This frees about 683 MB. You can download the local image model '
          'again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) await sl<ImageGenerationCubit>().removeModel();
  }

  Future<void> _addAttachmentToWorkspace(
    PreparedChatAttachment attachment,
  ) async {
    final workspaceId = sl<SelectedWorkspaceCubit>().state;
    if (workspaceId == null) {
      await AppToast.show('Select a workspace first.', type: AppToastType.info);
      return;
    }
    try {
      await sl<WorkspaceRagActions>().importDocument(
        workspaceId: workspaceId,
        rawPath: attachment.appPath,
      );
      await AppToast.show(
        'Document added to workspace knowledge.',
        type: AppToastType.success,
      );
    } catch (error) {
      await AppToast.show(
        'Could not add document to workspace: $error',
        type: AppToastType.error,
      );
    }
  }

  void _scheduleDraftBudgetRefresh({
    Duration delay = const Duration(milliseconds: 180),
  }) {
    _draftBudgetDebounce?.cancel();
    _draftBudgetDebounce = Timer(delay, _refreshDraftBudget);
  }

  Future<void> _refreshDraftBudget() async {
    final requestId = ++_draftBudgetRequestId;
    final text = _controller.text.trim();
    final imagePath = sl<ChatInputCubit>().state.selectedImagePath;
    final attachments = sl<ChatAttachmentsCubit>().readyAttachments;
    final activeModel = await sl<ActiveModelInfoResolver>()
        .getActiveModelInfo();

    if (!mounted) return;

    final hasImage =
        (imagePath != null && imagePath.isNotEmpty) ||
        attachments.any(
          (attachment) => attachment.kind == ChatAttachmentKind.image,
        );
    final shouldHideBudget =
        activeModel == null ||
        activeModel.provider != 'local' ||
        (text.isEmpty && !hasImage && attachments.isEmpty);
    if (shouldHideBudget) {
      if (_draftBudget != null || _isEstimatingDraftBudget) {
        setState(() {
          _draftBudget = null;
          _isEstimatingDraftBudget = false;
        });
      }
      return;
    }

    setState(() => _isEstimatingDraftBudget = true);

    final budget = await sl<ChatThreadActions>().estimateLocalMessageBudget(
      text: text,
      imagePath: imagePath,
      attachments: attachments,
    );

    if (!mounted || requestId != _draftBudgetRequestId) return;
    setState(() {
      _draftBudget = budget;
      _isEstimatingDraftBudget = false;
    });
  }

  Future<void> _openAttachmentMenu({
    required BuildContext context,
    required bool canAttachImage,
    required bool hasSelectedImage,
  }) async {
    final options = _buildAttachmentOptions(canAttachImage: canAttachImage);
    if (options.isEmpty) {
      await AppToast.show('No attachments available for this model.');
      return;
    }

    final selectedSource = await showModalBottomSheet<ChatAttachmentSource>(
      context: context,
      showDragHandle: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 400),
        reverseDuration: Duration(milliseconds: 200),
      ),
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
    if (selectedSource == ChatAttachmentSource.files) {
      await sl<ChatInputCubit>().pickFiles(allowImages: canAttachImage);
    } else {
      await sl<ChatInputCubit>().pickImage(source: selectedSource);
    }
  }

  List<_AttachmentOption> _buildAttachmentOptions({
    required bool canAttachImage,
  }) {
    final options = <_AttachmentOption>[
      const _AttachmentOption(
        source: ChatAttachmentSource.files,
        label: 'Files and documents',
        icon: Icons.attach_file_rounded,
      ),
    ];
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
        return BlocConsumer<ChatInputCubit, ChatInputState>(
          listenWhen: (previous, current) =>
              previous.draftText != current.draftText,
          listener: (context, inputState) {
            _syncControllerWithDraft(inputState.draftText);
          },
          builder: (context, inputState) {
            return BlocBuilder<SelectedChatCubit, String?>(
              builder: (context, selectedChatId) {
                return StreamBuilder<ModelInfo?>(
                  stream: sl<ActiveModelInfoResolver>().watchActiveModelInfo(),
                  builder: (context, activeModelSnapshot) {
                    final activeModel = activeModelSnapshot.data;
                    final canAttachImage = activeModel?.supportImage ?? false;
                    final hasSelectedImage =
                        inputState.selectedImagePath != null;
                    final hasTypedAttachments = _attachmentDrafts.any(
                      (draft) =>
                          draft.status == ChatAttachmentDraftStatus.ready,
                    );
                    final isPreparingAttachment = _attachmentDrafts.any(
                      (draft) =>
                          draft.status == ChatAttachmentDraftStatus.preparing,
                    );
                    final hasSendableContent =
                        (_hasTypedContent ||
                            hasSelectedImage ||
                            hasTypedAttachments) &&
                        !isPreparingAttachment;
                    final keyboardVisible =
                        MediaQuery.viewInsetsOf(context).bottom > 0;
                    if (_wasKeyboardVisible &&
                        !keyboardVisible &&
                        _focusNode.hasFocus) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _focusNode.unfocus();
                      });
                    }
                    _wasKeyboardVisible = keyboardVisible;

                    if (_lastSelectedImagePath !=
                            inputState.selectedImagePath ||
                        _lastSelectedChatId != selectedChatId ||
                        _lastBudgetModelId != activeModel?.id) {
                      _lastSelectedImagePath = inputState.selectedImagePath;
                      _lastSelectedChatId = selectedChatId;
                      _lastBudgetModelId = activeModel?.id;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _scheduleDraftBudgetRefresh(delay: Duration.zero);
                      });
                    }

                    return BlocBuilder<ChatComposerModeCubit, ChatComposerMode>(
                      bloc: sl<ChatComposerModeCubit>(),
                      builder: (context, composerMode) {
                        return BlocBuilder<
                          ImageGenerationCubit,
                          ImageGenerationState
                        >(
                          bloc: sl<ImageGenerationCubit>(),
                          builder: (context, imageState) {
                            return _buildInputField(
                              context: context,
                              colorScheme: colorScheme,
                              activeModel: activeModel,
                              isGenerating: isGenerating,
                              inputState: inputState,
                              canAttachImage: canAttachImage,
                              hasSelectedImage: hasSelectedImage,
                              hasSendableContent: hasSendableContent,
                              attachmentDrafts: _attachmentDrafts,
                              isPreparingAttachment: isPreparingAttachment,
                              composerMode: composerMode,
                              imageState: imageState,
                            );
                          },
                        );
                      },
                    );
                  },
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
    required ModelInfo? activeModel,
    required bool isGenerating,
    required ChatInputState inputState,
    required bool canAttachImage,
    required bool hasSelectedImage,
    required bool hasSendableContent,
    required List<ChatAttachmentDraft> attachmentDrafts,
    required bool isPreparingAttachment,
    required ChatComposerMode composerMode,
    required ImageGenerationState imageState,
  }) {
    final isImageMode = composerMode == ChatComposerMode.image;
    final imageIsGenerating =
        imageState.phase == ImageGenerationUiPhase.loadingModel ||
        imageState.phase == ImageGenerationUiPhase.generating;
    final effectiveGenerating = isImageMode ? imageIsGenerating : isGenerating;
    final effectiveSendable = isImageMode
        ? _hasTypedContent && imageState.isInstalled && !imageState.isBusy
        : activeModel != null && hasSendableContent;
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
          ChatComposerModeSelector(
            mode: composerMode,
            enabled: !isGenerating && !imageState.isBusy,
            onSelected: (mode) {
              sl<ChatComposerModeCubit>().select(mode);
              if (mode == ChatComposerMode.image &&
                  (imageState.phase == ImageGenerationUiPhase.initial ||
                      imageState.phase == ImageGenerationUiPhase.failed)) {
                unawaited(sl<ImageGenerationCubit>().initialize());
              }
            },
          ),
          if (isImageMode)
            ImageGenerationStatusPanel(
              state: imageState,
              onInstall: () =>
                  unawaited(sl<ImageGenerationCubit>().installModel()),
              onCancelInstall: () =>
                  unawaited(sl<ImageGenerationCubit>().cancelInstall()),
              onCancelGeneration: () =>
                  sl<ImageGenerationCubit>().cancelGeneration(),
              onRetry: () => unawaited(sl<ImageGenerationCubit>().initialize()),
              onRemove: () => unawaited(_confirmRemoveImageModel()),
            )
          else ...[
            _buildVisionPromptChips(
              context: context,
              colorScheme: colorScheme,
              activeModel: activeModel,
              hasSelectedImage: hasSelectedImage,
              isGenerating: isGenerating,
            ),
            _buildTokenBudgetIndicator(
              context: context,
              colorScheme: colorScheme,
              activeModel: activeModel,
              hasDraftContent: hasSendableContent,
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isImageMode &&
                    (!_hasFocus ||
                        hasSelectedImage ||
                        attachmentDrafts.isNotEmpty))
                  ChatInputAttachmentButton(
                    isGenerating: effectiveGenerating,
                    hasSelectedImage:
                        hasSelectedImage || attachmentDrafts.isNotEmpty,
                    onPressed: () => _openAttachmentMenu(
                      context: context,
                      canAttachImage: canAttachImage,
                      hasSelectedImage: hasSelectedImage,
                    ),
                  ),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: colorScheme.surfaceContainerHigh,
                    ),
                    child: Column(
                      children: [
                        if (!isImageMode)
                          ChatInputAttachmentPreviewList(
                            attachments: attachmentDrafts,
                            onRemove: (id) => unawaited(
                              sl<ChatAttachmentsCubit>().remove(id),
                            ),
                            onAddToWorkspace: (attachment) => unawaited(
                              _addAttachmentToWorkspace(attachment),
                            ),
                          ),
                        if (!isImageMode && hasSelectedImage)
                          ChatInputImagePreview(
                            imagePath: inputState.selectedImagePath!,
                            onRemove: () {
                              sl<ChatInputCubit>().clearSelectedImage();
                            },
                          ),
                        TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: TextStyle(fontSize: 14),
                          onTapOutside: (_) => _focusNode.unfocus(),
                          decoration: InputDecoration(
                            hintStyle: TextStyle(fontSize: 14),
                            hintText: isImageMode
                                ? 'Describe the image to create…'
                                : 'Type a message...',
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
                                !isImageMode && _hasFocus && !hasSelectedImage
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
                                          onPressed: effectiveGenerating
                                              ? null
                                              : () => _openAttachmentMenu(
                                                  context: context,
                                                  canAttachImage:
                                                      canAttachImage,
                                                  hasSelectedImage:
                                                      hasSelectedImage,
                                                ),
                                          tooltip: 'Add files',
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
                                  if (!isImageMode &&
                                      !isGenerating &&
                                      !hasSendableContent &&
                                      AppCapabilities
                                          .current
                                          .supportsSpeechToText) ...[
                                    ChatInputVoiceButton(
                                      cubit: sl<VoiceInputCubit>(),
                                      enabled: !isGenerating,
                                    ),
                                    suffixActionButton(
                                      icon: HugeIcons.strokeRoundedVoice,
                                      color: colorScheme.primary,
                                      tooltip: 'Hands-free voice conversation',
                                      onPressed: () => context.pushNamed(
                                        'voice-conversation',
                                      ),
                                    ),
                                  ],
                                  if (!isImageMode && isPreparingAttachment)
                                    const Padding(
                                      padding: EdgeInsets.all(5),
                                      child: SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  else if (effectiveGenerating ||
                                      effectiveSendable)
                                    ChatInputSendButton(
                                      isGenerating: effectiveGenerating,
                                      hasSendableContent: effectiveSendable,
                                      isSending: isImageMode
                                          ? imageState.isBusy
                                          : inputState.isSending,
                                      onPressed: effectiveGenerating
                                          ? isImageMode
                                                ? () =>
                                                      sl<ImageGenerationCubit>()
                                                          .cancelGeneration()
                                                : _stopGeneration
                                          : isImageMode
                                          ? _generateImage
                                          : _sendMessage,
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

  /// Preset analyze-image prompts shown when a vision model has an image
  /// attached. Gated behind local-model support (vision is native-only).
  Widget _buildVisionPromptChips({
    required BuildContext context,
    required ColorScheme colorScheme,
    required ModelInfo? activeModel,
    required bool hasSelectedImage,
    required bool isGenerating,
  }) {
    if (!AppCapabilities.current.supportsLocalModels) {
      return const SizedBox.shrink();
    }
    if (!hasSelectedImage || !(activeModel?.supportImage ?? false)) {
      return const SizedBox.shrink();
    }

    const presets = <String>[
      'Describe this image',
      'Extract the text',
      "What's on this receipt?",
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets
              .map(
                (prompt) => ActionChip(
                  label: Text(prompt),
                  visualDensity: VisualDensity.compact,
                  onPressed: isGenerating
                      ? null
                      : () => sl<ChatInputCubit>().setDraftText(prompt),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildTokenBudgetIndicator({
    required BuildContext context,
    required ColorScheme colorScheme,
    required ModelInfo? activeModel,
    required bool hasDraftContent,
  }) {
    if (activeModel?.provider != 'local') {
      return const SizedBox.shrink();
    }
    if (!hasDraftContent && _draftBudget == null && !_isEstimatingDraftBudget) {
      return const SizedBox.shrink();
    }

    final budget = _draftBudget;
    final isOverflow = budget != null && !budget.fits;
    final isTight =
        budget != null &&
        budget.fits &&
        budget.remainingTokensAfterMessage <= budget.reservedOutputTokens;
    final accent = isOverflow
        ? colorScheme.error
        : isTight
        ? colorScheme.tertiary
        : colorScheme.primary;
    final background = isOverflow
        ? colorScheme.errorContainer
        : colorScheme.surfaceContainerHigh;

    final title = switch ((budget, _isEstimatingDraftBudget)) {
      (null, true) => 'Estimating token budget...',
      (null, false) => 'Token budget unavailable right now.',
      (final LocalMessageBudgetPlan value?, _) when !value.fits =>
        'Draft is too large by about ${value.overflowTokens} token(s).',
      (final LocalMessageBudgetPlan value?, _) =>
        '${value.remainingTokensAfterMessage} token(s) left after this message.',
    };

    final chips = <Widget>[];
    if (budget != null) {
      chips.add(_buildBudgetChip(label: 'Draft', value: budget.messageTokens));
      chips.add(_buildBudgetChip(label: 'Prompt', value: budget.promptTokens));
      chips.add(
        _buildBudgetChip(label: 'Reserve', value: budget.reservedOutputTokens),
      );
      if (budget.compactedMessages > 0) {
        chips.add(
          _buildBudgetChip(label: 'Compacted', value: budget.compactedMessages),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withAlpha(70)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Row(
              children: [
                Icon(
                  isOverflow ? Icons.warning_amber_rounded : Icons.tune_rounded,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (chips.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetChip({required String label, required int value}) {
    return Builder(
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$label $value',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        );
      },
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
