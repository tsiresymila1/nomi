import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/chat/data/cubits/chat_input_cubit.dart';
import 'package:gena/features/chat/data/cubits/chat_ui_cubits.dart';
import 'package:gena/features/chat/data/providers/chat_queries_provider.dart';
import 'package:gena/features/chat/presentation/widgets/chat_bubble.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: sl<ChatQueriesRepository>().watchChatMessages(widget.chatId),
      builder: (context, messagesSnapshot) {
        final messages = messagesSnapshot.data ?? const [];

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
                            (hasStreamingPlaceholder ? 1 : 0);

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

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16)
                              .copyWith(
                                top: MediaQuery.of(context).padding.top,
                                bottom: MediaQuery.of(context).padding.bottom,
                              ),
                          itemCount: totalCount,
                          itemBuilder: (context, index) {
                            if (index < messages.length) {
                              final message = messages[index];
                              return ChatBubble(
                                key: ValueKey('chat-message-${message.id}'),
                                message: message.content,
                                isUser: message.role == 'user',
                                kind: message.kind,
                                mediaPath: message.mediaPath,
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
                                key: const ValueKey('chat-draft-thinking'),
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

                            return ChatBubble(
                              key: const ValueKey('chat-draft-response'),
                              message: draft ?? '',
                              isUser: false,
                              isStreaming: isGenerating,
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
}
