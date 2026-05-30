import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fullscreen_image_viewer/fullscreen_image_viewer.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.kind = 'text',
    this.mediaPath,
    this.isStreaming = false,
  });

  final String message;
  final bool isUser;
  final String kind;
  final String? mediaPath;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final isThinking = kind == 'thinking' && !isUser;
    final isTool = kind == 'tool_trace' || kind == 'tool_waiting';
    final bubbleColor = isUser
        ? Theme.of(context).colorScheme.primary
        : isThinking || isTool
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.transparent;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (kind == 'image' && mediaPath != null) {
      return Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (message.trim().isNotEmpty)
            GptMarkdown(message, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              FullscreenImageViewer.open(
                context: context,
                child: Image.file(File(mediaPath!)),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(mediaPath!),
                fit: BoxFit.cover,
                width: 180,
                errorBuilder: (_, _, _) => const Text('Image unavailable'),
              ),
            ),
          ),
        ],
      );
    }

    if (kind == 'tool_waiting') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(message, style: const TextStyle(fontSize: 12))),
        ],
      );
    }

    return GptMarkdown(message, style: TextStyle(fontSize: isUser ? 14 : 13));
  }
}
