import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/providers/chat_thread_actions_provider.dart';
import 'package:path_provider/path_provider.dart';

final chatInputControllerProvider =
    NotifierProvider<ChatInputController, ChatInputState>(
      ChatInputController.new,
    );

class ChatInputState {
  final String? selectedImagePath;
  final bool isSending;

  const ChatInputState({this.selectedImagePath, this.isSending = false});

  ChatInputState copyWith({
    String? selectedImagePath,
    bool updateSelectedImagePath = false,
    bool? isSending,
  }) {
    return ChatInputState(
      selectedImagePath: updateSelectedImagePath
          ? selectedImagePath
          : this.selectedImagePath,
      isSending: isSending ?? this.isSending,
    );
  }
}

class ChatInputController extends Notifier<ChatInputState> {
  @override
  ChatInputState build() => const ChatInputState();

  Future<void> pickImageFromDevice() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.image,
        dialogTitle: 'Select image',
      );
      final pickedPath = result?.files.single.path;
      if (pickedPath == null) return;

      final copiedPath = await _copyImageToAppSupport(pickedPath);
      state = state.copyWith(
        selectedImagePath: copiedPath,
        updateSelectedImagePath: true,
      );
      await FilePicker.platform.clearTemporaryFiles();
      await AppToast.show('Image selected', type: AppToastType.success);
    } catch (e) {
      await AppToast.show('Image pick failed: $e', type: AppToastType.error);
    }
  }

  void clearSelectedImage() {
    state = state.copyWith(
      selectedImagePath: null,
      updateSelectedImagePath: true,
    );
  }

  Future<void> sendMessage(String rawText) async {
    final text = rawText.trim();
    final imagePath = state.selectedImagePath;
    if (text.isEmpty && imagePath == null) return;
    if (state.isSending) return;

    state = state.copyWith(isSending: true);
    try {
      state = state.copyWith(
        selectedImagePath: null,
        updateSelectedImagePath: true,
      );
      await ref
          .read(chatThreadActionsProvider)
          .sendMessage(text, imagePath: imagePath);
    } finally {
      state = state.copyWith(isSending: false);
    }
  }

  Future<String> _copyImageToAppSupport(String sourcePath) async {
    final sourceFile = File(sourcePath);
    final appSupportDir = await getApplicationSupportDirectory();
    final imagesDir = Directory('${appSupportDir.path}/chat_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final filename = sourceFile.uri.pathSegments.isNotEmpty
        ? sourceFile.uri.pathSegments.last
        : 'image.jpg';
    final safeFilename = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final target = File(
      '${imagesDir.path}/${DateTime.now().millisecondsSinceEpoch}_$safeFilename',
    );
    await sourceFile.copy(target.path);
    return target.path;
  }
}
