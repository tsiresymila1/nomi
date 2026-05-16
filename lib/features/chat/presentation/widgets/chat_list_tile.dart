import 'package:flutter/material.dart';
import 'package:gena/features/chat/domain/entities/chat_entity.dart';

class ChatListTile extends StatelessWidget {
  final ChatEntity chat;
  final VoidCallback? onTap;

  const ChatListTile({
    super.key,
    required this.chat,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(chat.title),
      subtitle: Text(
        chat.createdAt.toString(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
