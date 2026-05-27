import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class ChatInputImagePreview extends StatelessWidget {
  final String imagePath;
  final VoidCallback onRemove;

  const ChatInputImagePreview({
    super.key,
    required this.imagePath,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20).copyWith(top: 8),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(
                  File(imagePath),
                  height: 100,
                  width: 80,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 0,
                child: InkWell(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedAdd01,
                    size: 22,
                    color: colorScheme.surfaceContainerHigh,
                  ),
                  onTap: onRemove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
