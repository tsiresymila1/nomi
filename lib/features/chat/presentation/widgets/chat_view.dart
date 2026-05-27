import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
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
                        final hasThinkingDraft = (thinkingDraft ?? '').isNotEmpty;
                        final hasToolWaitingName = (waitingToolName ?? '').trim().isNotEmpty;

                        final totalCount =
                            messages.length +
                            (hasToolWaitingName ? 1 : 0) +
                            (hasThinkingDraft ? 1 : 0) +
                            (hasDraft ? 1 : 0);

                        if (totalCount == 0) {
                          return const Center(child: Text('Start a conversation'));
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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

                            if (hasToolWaitingName && index == messages.length) {
                              return ChatBubble(
                                key: const ValueKey('chat-waiting-tool'),
                                message: 'Waiting for function tool: $waitingToolName',
                                isUser: false,
                                kind: 'tool_waiting',
                                isStreaming: true,
                              );
                            }

                            if (hasThinkingDraft &&
                                index == messages.length + (hasToolWaitingName ? 1 : 0)) {
                              return ChatBubble(
                                key: const ValueKey('chat-draft-thinking'),
                                message: thinkingDraft ?? '',
                                isUser: false,
                                kind: 'thinking',
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
