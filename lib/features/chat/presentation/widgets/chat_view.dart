import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gena/features/chat/presentation/widgets/chat_bubble.dart';

class ChatView extends ConsumerStatefulWidget {
  final String chatId;
  final InferenceChat chat;

  const ChatView({super.key, required this.chatId, required this.chat});

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  String _lastDraft = '';
  bool _lastWaitingIndicator = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _autoScrollToEndIfNeeded({
    required int messageCount,
    required String draft,
    required bool waitingIndicator,
    bool forceAutoScroll = false,
  }) {
    final shouldAutoScroll = forceAutoScroll || _isNearBottom();
    final changed =
        messageCount != _lastMessageCount ||
        (draft.isNotEmpty && draft != _lastDraft) ||
        waitingIndicator != _lastWaitingIndicator;
    _lastMessageCount = messageCount;
    _lastDraft = draft;
    _lastWaitingIndicator = waitingIndicator;
    if (!changed || !shouldAutoScroll) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (target <= 0) return;
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return (position.maxScrollExtent - position.pixels) <= 96;
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final draft = ref.watch(chatDraftResponseProvider);
    final isGenerating = ref.watch(chatGeneratingProvider);

    return messagesAsync.when(
      data: (messages) {
        final hasDraft = draft != null && draft.isNotEmpty;
        final waitingIndicator = isGenerating && !hasDraft;
        final forceAutoScrollOnUserSend =
            messages.length > _lastMessageCount &&
            messages.isNotEmpty &&
            messages.last.role == 'user';
        final totalCount =
            messages.length + (hasDraft ? 1 : 0) + (waitingIndicator ? 1 : 0);
        _autoScrollToEndIfNeeded(
          messageCount: messages.length,
          draft: draft ?? '',
          waitingIndicator: waitingIndicator,
          forceAutoScroll: forceAutoScrollOnUserSend,
        );

        if (totalCount == 0) {
          return const Center(child: Text('No messages yet'));
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: totalCount,
          itemBuilder: (context, index) {
            if (index < messages.length) {
              final message = messages[index];
              return ChatBubble(
                message: message.content,
                isUser: message.role == 'user',
                kind: message.kind,
                mediaPath: message.mediaPath,
              );
            }

            if (waitingIndicator) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      16,
                    ).copyWith(bottomLeft: const Radius.circular(4)),
                  ),
                  child: SizedBox(
                    height: 18,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: SpinKitThreeBounce(
                          size: 18,
                          color: Theme.of(context).colorScheme.primaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            return ChatBubble(message: draft ?? '', isUser: false);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
