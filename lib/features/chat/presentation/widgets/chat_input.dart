import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/chat_provider.dart';
import 'package:gena/features/chat/presentation/providers/chat_input_controller.dart';

class ChatInput extends ConsumerStatefulWidget {
  const ChatInput({super.key});

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    // Placeholder for file picker - using basic file implementation
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Document'),
              onTap: () {
                ref.read(chatInputControllerProvider.notifier).selectFile(null);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Image'),
              onTap: () {
                ref.read(chatInputControllerProvider.notifier).selectFile(null);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.audio_file),
              title: const Text('Audio'),
              onTap: () {
                ref.read(chatInputControllerProvider.notifier).selectFile(null);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ref.read(chatInputControllerProvider.notifier).sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final isGenerating = ref.watch(chatGeneratingProvider);
    final inputState = ref.watch(chatInputControllerProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              inputState.selectedFile != null
                  ? Icons.attach_file
                  : Icons.add_circle_outline,
            ),
            onPressed: _pickFile,
            tooltip: 'Attach file',
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: (inputState.isSending || isGenerating)
                ? null
                : _sendMessage,
          ),
          IconButton(
            icon: const Icon(Icons.mic),
            onPressed: () {}, // TODO: Audio recording
            tooltip: 'Voice input',
          ),
        ],
      ),
    );
  }
}
