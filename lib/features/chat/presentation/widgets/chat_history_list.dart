import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/providers/chat_provider.dart';
import 'package:gena/features/chat/presentation/widgets/chat_history_tile.dart';

class ChatHistoryList extends ConsumerWidget {
  const ChatHistoryList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget reveal(Widget child, {int delayMs = 0}) {
      return child
          .animate()
          .fade(duration: 500.ms, delay: delayMs.ms)
          .scale(
            delay: (delayMs + 120).ms,
            duration: 260.ms,
            begin: const Offset(0.98, 0.98),
            end: const Offset(1, 1),
            curve: Curves.easeOutCubic,
          );
    }

    final chatsAsync = ref.watch(chatListProvider);

    return chatsAsync.when(
      data: (chats) => chats.isEmpty
          ? reveal(
              const Center(
                child: Text(
                  'No chat history',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          : ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) =>
                  ChatHistoryTile(chat: chats[index])
                      .animate()
                      .fadeIn(duration: 220.ms, delay: (index * 40).ms)
                      .slideX(begin: -0.08, end: 0),
            ),
      loading: () => reveal(const Center(child: CircularProgressIndicator())),
      error: (err, stack) => reveal(Center(child: Text('Error: $err'))),
    );
  }
}
