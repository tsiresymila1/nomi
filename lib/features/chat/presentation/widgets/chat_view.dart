import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
          const quickPrompts = <String>[
            'Help me get started with this app',
            'Summarize our previous context',
            'Give me 3 ideas I can work on now',
          ];
          return reveal(
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [
                    Text(
                          'Start with a quick prompt',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        )
                        .animate(key: const ValueKey('quick-prompt-title'))
                        .fade(duration: 320.ms, delay: 80.ms),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final entry in quickPrompts.asMap().entries)
                          Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHigh,
                                  ),
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHigh,
                                ),
                                child: InkWell(
                                  onTap: isGenerating
                                      ? null
                                      : () async {
                                          await ref
                                              .read(chatThreadActionsProvider)
                                              .sendMessage(entry.value);
                                        },
                                  child: Text(
                                    entry.value,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              )
                              .animate(
                                key: ValueKey('quick-prompt-${entry.key}'),
                              )
                              .fade(
                                duration: 360.ms,
                                delay: (180 + (entry.key * 100)).ms,
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
          padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
            top: MediaQuery.of(context).padding.top,
            bottom: MediaQuery.of(context).padding.bottom,
          ),
          itemCount: totalCount,
          itemBuilder: (context, index) {
            if (index < messages.length) {
              final message = messages[index];
              final delayMs = (index * 45).clamp(0, 360);
              return ChatBubble(
                    key: ValueKey('chat-message-${message.id}'),
                    message: message.content,
                    isUser: message.role == 'user',
                    kind: message.kind,
                    mediaPath: message.mediaPath,
                  )
                  .animate(key: ValueKey('chat-message-anim-${message.id}'))
                  .fadeIn(duration: 220.ms, delay: delayMs.ms)
                  .slideY(
                    begin: 0.06,
                    end: 0,
                    duration: 220.ms,
                    delay: delayMs.ms,
                  );
            }

            if (waitingIndicator) {
              return reveal(
                Align(
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
                          width: 40,
                          height: 18,
                          child: SpinKitThreeBounce(
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            return reveal(
              ChatBubble(
                key: const ValueKey('chat-draft-response'),
                message: draft ?? '',
                isUser: false,
              ),
            );
          },
        );
      },
      loading: () => reveal(const Center(child: CircularProgressIndicator())),
      error: (err, stack) => reveal(Center(child: Text('Error: $err'))),
    );
  }
}
