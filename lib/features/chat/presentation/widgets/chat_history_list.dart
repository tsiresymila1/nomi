import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/chat/data/models/chat_entity.dart';
import 'package:gena/features/chat/data/repositories/chat_queries_repository.dart';
import 'package:gena/features/chat/presentation/widgets/chat_history_tile.dart';

class ChatHistoryList extends StatelessWidget {
  const ChatHistoryList({super.key});

  @override
  Widget build(BuildContext context) {
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

    final chatQueries = sl<ChatQueriesRepository>();

    return StreamBuilder<List<ChatEntity>>(
      stream: chatQueries.watchChatList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return reveal(
            Center(
              child: SpinKitThreeBounce(
                size: 30,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return reveal(Center(child: Text('Error: ${snapshot.error}')));
        }
        final chats = snapshot.data ?? [];
        if (chats.isEmpty) {
          return reveal(
            const Center(
              child: Text(
                'No chat history',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) => ChatHistoryTile(chat: chats[index])
              .animate()
              .fadeIn(duration: 220.ms, delay: (index * 40).ms)
              .slideX(begin: -0.08, end: 0),
        );
      },
    );
  }
}
