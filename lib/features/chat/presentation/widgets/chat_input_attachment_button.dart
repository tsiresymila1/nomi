import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class ChatInputAttachmentButton extends StatelessWidget {
  final bool isGenerating;
  final bool hasSelectedImage;
  final VoidCallback onPressed;

  const ChatInputAttachmentButton({
    super.key,
    required this.isGenerating,
    required this.hasSelectedImage,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainerHigh,
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      ),
      onPressed: isGenerating ? null : onPressed,
      icon: HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
    );
  }
}
