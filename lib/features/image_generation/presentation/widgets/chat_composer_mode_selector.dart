import 'package:flutter/material.dart';
import 'package:gena/features/image_generation/presentation/cubit/chat_composer_mode_cubit.dart';

class ChatComposerModeSelector extends StatelessWidget {
  const ChatComposerModeSelector({
    super.key,
    required this.mode,
    required this.onSelected,
    this.enabled = true,
  });

  final ChatComposerMode mode;
  final ValueChanged<ChatComposerMode> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ChatComposerMode>(
      key: const ValueKey('chat-composer-mode-selector'),
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.labelSmall,
        ),
      ),
      segments: const <ButtonSegment<ChatComposerMode>>[
        ButtonSegment(
          value: ChatComposerMode.text,
          icon: Icon(Icons.chat_bubble_outline_rounded, size: 16),
          label: Text('Chat'),
        ),
        ButtonSegment(
          value: ChatComposerMode.image,
          icon: Icon(Icons.auto_awesome_rounded, size: 16),
          label: Text('Image'),
        ),
      ],
      selected: <ChatComposerMode>{mode},
      onSelectionChanged: enabled
          ? (selection) => onSelected(selection.first)
          : null,
    );
  }
}
