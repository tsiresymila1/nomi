import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/providers/chat_thread_actions_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

enum ChatAttachmentSource { camera, gallery }

class ChatInputState {
  const ChatInputState({this.selectedImagePath, this.isSending = false});

  final String? selectedImagePath;
  final bool isSending;

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

class ChatInputCubit extends Cubit<ChatInputState> {
  ChatInputCubit({required ChatThreadActions chatThreadActions})
    : _chatThreadActions = chatThreadActions,
      super(const ChatInputState());

  final ChatThreadActions _chatThreadActions;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> pickImage({required ChatAttachmentSource source}) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: switch (source) {
          ChatAttachmentSource.camera => ImageSource.camera,
          ChatAttachmentSource.gallery => ImageSource.gallery,
        },
        imageQuality: 95,
      );
      final pickedPath = pickedFile?.path;
      if (pickedPath == null) return;

      final copiedPath = await _copyImageToAppSupport(pickedPath);
      emit(
        state.copyWith(
          selectedImagePath: copiedPath,
          updateSelectedImagePath: true,
        ),
      );
      final message = switch (source) {
        ChatAttachmentSource.camera => 'Photo captured',
        ChatAttachmentSource.gallery => 'Image selected',
      };
      await AppToast.show(message, type: AppToastType.success);
    } catch (error) {
      await AppToast.show('Image pick failed: $error', type: AppToastType.error);
    }
  }

  void clearSelectedImage() {
    emit(state.copyWith(selectedImagePath: null, updateSelectedImagePath: true));
  }

  Future<void> sendMessage(String rawText) async {
    final text = rawText.trim();
    final imagePath = state.selectedImagePath;
    if (text.isEmpty && imagePath == null) return;
    if (state.isSending) return;

    emit(state.copyWith(isSending: true));
    try {
      emit(state.copyWith(selectedImagePath: null, updateSelectedImagePath: true));
      await _chatThreadActions.sendMessage(text, imagePath: imagePath);
    } finally {
      emit(state.copyWith(isSending: false));
    }
  }

  Future<void> stopGeneration() {
    return _chatThreadActions.stopGeneration();
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
