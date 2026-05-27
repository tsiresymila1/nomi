import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class ChatInputSendButton extends StatelessWidget {
  final bool isGenerating;
  final bool hasSendableContent;
  final bool isSending;
  final VoidCallback onPressed;

  const ChatInputSendButton({
    super.key,
    required this.isGenerating,
    required this.hasSendableContent,
    required this.isSending,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        color: !isGenerating ? Colors.green[900] : null,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
        onPressed: isGenerating ? onPressed : (isSending ? null : onPressed),
        tooltip: isGenerating ? 'Stop generation' : 'Send',
        icon: HugeIcon(
          icon: isGenerating
              ? HugeIcons.strokeRoundedStop
              : HugeIcons.strokeRoundedArrowUp02,
          size: 25,
          color: isGenerating ? Colors.red : Colors.white,
        ),
        splashRadius: 16,
      ),
    );
  }
}
