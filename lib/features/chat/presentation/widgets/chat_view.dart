import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/chat_provider.dart';
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
  bool _forceScrollScheduled = false;
  bool _isGeneratingNow = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _autoScrollToEndIfNeeded({
    required int messageCount,
    required String draft,
  }) {
    final changed =
        messageCount != _lastMessageCount ||
        (draft.isNotEmpty && draft != _lastDraft);
    _lastMessageCount = messageCount;
    _lastDraft = draft;
    if (!changed) return;

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

  void _scheduleForceScroll() {
    if (_forceScrollScheduled) return;
    _forceScrollScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceScrollScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;

      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });

      if (_isGeneratingNow) {
        Future<void>.delayed(const Duration(milliseconds: 16), () {
          if (!mounted) return;
          _scheduleForceScroll();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final draft = ref.watch(chatDraftResponseProvider);
    final isGenerating = ref.watch(chatGeneratingProvider);
    _isGeneratingNow = isGenerating;

    return messagesAsync.when(
      data: (messages) {
        final totalCount =
            messages.length + (draft == null || draft.isEmpty ? 0 : 1);
        _autoScrollToEndIfNeeded(
          messageCount: messages.length,
          draft: draft ?? '',
        );
        if (isGenerating) {
          _scheduleForceScroll();
        }

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
