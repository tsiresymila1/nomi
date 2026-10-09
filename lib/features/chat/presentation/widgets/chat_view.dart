import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/chat/presentation/cubit/chat_input_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/chat_ui_cubits.dart';
import 'package:gena/features/chat/data/services/chat_queries_service.dart';
import 'package:gena/features/chat/data/services/chat_page_actions_service.dart';
import 'package:gena/features/chat/data/services/chat_thread_actions_service.dart';
import 'package:gena/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:gena/features/chat/presentation/widgets/remote_model_confirmation_dialog.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_generation_cubit.dart';
import 'package:gena/features/image_generation/presentation/widgets/image_generation_chat_activity.dart';

const double _chatAutoFollowThreshold = 120;

bool isNearChatBottom({
  required double pixels,
  required double maxScrollExtent,
  double threshold = _chatAutoFollowThreshold,
}) {
  return maxScrollExtent - pixels <= threshold;
}

class ChatView extends StatefulWidget {
  const ChatView({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final ScrollController _scrollController = ScrollController();
  String? _lastScrollSignature;
  bool _isNearBottom = true;
  bool _scrollScheduled = false;
  StreamSubscription<ChatGenerationFailureState?>? _failureSubscription;
  StreamSubscription<ImageGenerationState>? _imageGenerationSubscription;
  ChatGenerationFailureState? _generationFailure;
  late ImageGenerationState _imageGenerationState;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScrollPosition);
    final failureCubit = sl<ChatGenerationFailureCubit>();
    _generationFailure = failureCubit.state;
    _failureSubscription = failureCubit.stream.listen((failure) {
      if (!mounted) return;
      setState(() => _generationFailure = failure);
    });
    final imageGenerationCubit = sl<ImageGenerationCubit>();
    _imageGenerationState = imageGenerationCubit.state;
    _imageGenerationSubscription = imageGenerationCubit.stream.listen((state) {
      if (!mounted) return;
      setState(() => _imageGenerationState = state);
    });
  }

  @override
  void dispose() {
    unawaited(_failureSubscription?.cancel());
    unawaited(_imageGenerationSubscription?.cancel());
    _scrollController.dispose();
    super.dispose();
  }

  Widget reveal(Widget child, {int delayMs = 0}) {
    return child
        .animate()
        .fade(duration: 500.ms, delay: delayMs.ms)
        .scale(
          delay: (delayMs + 10).ms,
          duration: 260.ms,
          begin: const Offset(0.98, 0.98),
          end: const Offset(1, 1),
          curve: Curves.easeOutCubic,
        );
  }

  void _handleScrollPosition() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final nextIsNearBottom = isNearChatBottom(
      pixels: position.pixels,
      maxScrollExtent: position.maxScrollExtent,
    );
    if (nextIsNearBottom == _isNearBottom || !mounted) return;
    setState(() => _isNearBottom = nextIsNearBottom);
  }

  void _scheduleScrollToEnd() {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;
      if (!_isNearBottom) return;
      final position = _scrollController.position;
      if (!position.hasContentDimensions) return;
      final target = position.maxScrollExtent;
      if ((position.pixels - target).abs() < 1) return;
      _scrollController.jumpTo(target);
    });
  }

  Future<void> _jumpToLatest() async {
    if (!_scrollController.hasClients) return;
    setState(() => _isNearBottom = true);
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _useRemoteFallback(RemoteFallbackProposal proposal) async {
    final confirmed = await showRemoteDataConfirmationDialog(
      context: context,
      modelName: proposal.modelName,
      providerLabel: proposal.providerLabel,
    );
    if (!confirmed || !mounted) return;
    await sl<ChatPageActions>().useConfirmedRemoteFallback(proposal);
  }

  @override
  Widget build(BuildContext context) {
    final parsedChatId = int.tryParse(widget.chatId);
    final failure = _generationFailure?.chatId == parsedChatId
        ? _generationFailure
        : null;
    final imageState = _imageGenerationState;
    return StreamBuilder(
      stream: sl<ChatQueriesRepository>().watchChatMessages(widget.chatId),
      builder: (context, messagesSnapshot) {
        final messages = messagesSnapshot.data ?? const [];
        final hasImageActivity = shouldShowImageGenerationActivity(
          imageState,
          widget.chatId,
        );

        return BlocBuilder<ChatDraftResponseCubit, String?>(
          bloc: sl<ChatDraftResponseCubit>(),
          builder: (context, draft) {
            return BlocBuilder<ChatDraftThinkingCubit, String?>(
              bloc: sl<ChatDraftThinkingCubit>(),
              builder: (context, thinkingDraft) {
                return BlocBuilder<ChatGeneratingCubit, bool>(
                  bloc: sl<ChatGeneratingCubit>(),
                  builder: (context, isGenerating) {
                    return BlocBuilder<ChatToolWaitingCubit, String?>(
                      bloc: sl<ChatToolWaitingCubit>(),
                      builder: (context, waitingToolName) {
                        final hasDraft = (draft ?? '').isNotEmpty;
                        final hasThinkingDraft =
                            (thinkingDraft ?? '').isNotEmpty;
                        final hasToolWaitingName = (waitingToolName ?? '')
                            .trim()
                            .isNotEmpty;
                        final hasStreamingPlaceholder =
                            isGenerating &&
                            !hasDraft &&
                            !hasThinkingDraft &&
                            !hasToolWaitingName;

                        final totalCount =
                            messages.length +
                            (hasToolWaitingName ? 1 : 0) +
                            (hasThinkingDraft ? 1 : 0) +
                            (hasDraft ? 1 : 0) +
                            (hasStreamingPlaceholder ? 1 : 0) +
                            (failure != null ? 1 : 0) +
                            (hasImageActivity ? 1 : 0);
                        final scrollSignature = [
                          widget.chatId,
                          messages.length,
                          messages.isNotEmpty ? messages.last.id : 'none',
                          draft ?? '',
                          thinkingDraft ?? '',
                          waitingToolName ?? '',
                          isGenerating,
                          failure?.userMessageId ?? '',
                          failure?.displayMessage ?? '',
                          imageState.activeChatId ?? '',
                          imageState.phase,
                          imageState.progress?.step ?? '',
                          imageState.errorMessage ?? '',
                        ].join('|');
                        if (_lastScrollSignature != scrollSignature) {
                          _lastScrollSignature = scrollSignature;
                          _scheduleScrollToEnd();
                        }

                        if (totalCount == 0) {
                          const quickPrompts = <String>[
                            'Who are you ?',
                            'What can you help me with?',
                            'Help me write something',
                            'Give me ideas to try',
                          ];
                          return reveal(
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 24,
                                  children: [
                                    Text(
                                          'Quick prompt',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                          textAlign: TextAlign.center,
                                        )
                                        .animate(
                                          key: const ValueKey(
                                            'quick-prompt-title',
                                          ),
                                        )
                                        .fade(duration: 320.ms, delay: 80.ms),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        for (final entry
                                            in quickPrompts.asMap().entries)
                                          InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(50),
                                                onTap: isGenerating
                                                    ? null
                                                    : () async {
                                                        await sl<
                                                              ChatInputCubit
                                                            >()
                                                            .sendMessage(
                                                              entry.value,
                                                            );
                                                      },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          50,
                                                        ),
                                                    border: Border.all(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .surfaceContainerHigh,
                                                    ),
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHigh,
                                                  ),
                                                  child: Text(
                                                    entry.value,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .animate(
                                                key: ValueKey(
                                                  'quick-prompt-${entry.key}',
                                                ),
                                              )
                                              .fade(
                                                duration: 360.ms,
                                                delay: (180 + (entry.key * 100))
                                                    .ms,
                                              ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return Stack(
                          children: [
                            Positioned.fill(
                              child: ListView.builder(
                                controller: _scrollController,
                                padding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ).copyWith(
                                      top: MediaQuery.of(context).padding.top,
                                      bottom:
                                          MediaQuery.of(
                                            context,
                                          ).padding.bottom +
                                          56,
                                    ),
                                itemCount: totalCount,
                                itemBuilder: (context, index) {
                                  if (index < messages.length) {
                                    final message = messages[index];
                                    return ChatBubble(
                                      key: ValueKey(
                                        'chat-message-${message.id}',
                                      ),
                                      messageId: message.id.toString(),
                                      message: message.content,
                                      isUser: message.role == 'user',
                                      kind: message.kind,
                                      mediaPath: message.mediaPath,
                                      attachments: message.attachments,
                                      isStreaming: false,
                                    );
                                  }

                                  if (hasToolWaitingName &&
                                      index == messages.length) {
                                    return ChatBubble(
                                      key: const ValueKey('chat-waiting-tool'),
                                      message:
                                          'Waiting for function tool: $waitingToolName',
                                      isUser: false,
                                      kind: 'tool_waiting',
                                      isStreaming: true,
                                    );
                                  }

                                  if (hasThinkingDraft &&
                                      index ==
                                          messages.length +
                                              (hasToolWaitingName ? 1 : 0)) {
                                    return ChatBubble(
                                      key: const ValueKey(
                                        'chat-draft-thinking',
                                      ),
                                      message: thinkingDraft ?? '',
                                      isUser: false,
                                      kind: 'thinking',
                                      isStreaming: true,
                                    );
                                  }

                                  if (hasStreamingPlaceholder &&
                                      index ==
                                          messages.length +
                                              (hasToolWaitingName ? 1 : 0) +
                                              (hasThinkingDraft ? 1 : 0)) {
                                    return const ChatBubble(
                                      key: ValueKey('chat-draft-placeholder'),
                                      message: '',
                                      isUser: false,
                                      isStreaming: true,
                                    );
                                  }

                                  if (hasImageActivity &&
                                      index == totalCount - 1) {
                                    return ImageGenerationChatActivity(
                                      key: const ValueKey(
                                        'chat-image-generation-activity',
                                      ),
                                      state: imageState,
                                      onCancel: sl<ImageGenerationCubit>()
                                          .cancelGeneration,
                                      onRetry: () => unawaited(
                                        sl<ImageGenerationCubit>()
                                            .retryGeneration(),
                                      ),
                                    );
                                  }

                                  if (failure != null &&
                                      index ==
                                          totalCount -
                                              (hasImageActivity ? 1 : 0) -
                                              1) {
                                    return ChatGenerationFailureCard(
                                      key: const ValueKey(
                                        'chat-generation-failure',
                                      ),
                                      failure: failure,
                                      onRetry: sl<ChatThreadActions>()
                                          .retryLastFailedGeneration,
                                      onRemoteFallback: _useRemoteFallback,
                                    );
                                  }

                                  return ChatBubble(
                                    key: const ValueKey('chat-draft-response'),
                                    message: draft ?? '',
                                    isUser: false,
                                    isStreaming: isGenerating,
                                  );
                                },
                              ),
                            ),
                            if (!_isNearBottom)
                              Positioned(
                                right: 20,
                                bottom: 12,
                                child: FloatingActionButton.small(
                                  heroTag: 'chat-jump-to-latest',
                                  tooltip: 'Jump to latest',
                                  onPressed: _jumpToLatest,
                                  child: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                ),
                              ),
                          ],
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
}

class ChatGenerationFailureCard extends StatelessWidget {
  const ChatGenerationFailureCard({
    super.key,
    required this.failure,
    required this.onRetry,
    this.onRemoteFallback,
  });

  final ChatGenerationFailureState failure;
  final VoidCallback onRetry;
  final Future<void> Function(RemoteFallbackProposal proposal)?
  onRemoteFallback;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.error.withAlpha(80)),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 20,
              color: colorScheme.onErrorContainer,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  failure.displayMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
            if (failure.canRetry)
              TextButton(
                key: const ValueKey('retry-generation-button'),
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            if (failure.remoteFallback case final proposal?)
              TextButton.icon(
                key: const ValueKey('remote-generation-fallback-button'),
                onPressed: onRemoteFallback == null
                    ? null
                    : () => onRemoteFallback!(proposal),
                icon: const Icon(Icons.cloud_outlined, size: 18),
                label: Text('Try ${proposal.modelName}'),
              ),
          ],
        ),
      ),
    );
  }
}
