import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/chat/data/models/chat_attachment.dart';
import 'package:gena/features/chat/data/services/chat_thread_actions_service.dart';
import 'package:gena/features/chat/presentation/cubit/chat_attachments_cubit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

enum ChatAttachmentSource { camera, gallery, files }

class ChatInputState {
  const ChatInputState({
    this.selectedImagePath,
    this.isSending = false,
    this.draftText = '',
  });

  final String? selectedImagePath;
  final bool isSending;

  /// Current draft message text. Kept in sync with the input field so flows
  /// like voice transcription can append to it without losing what the user
  /// already typed.
  final String draftText;

  ChatInputState copyWith({
    String? selectedImagePath,
    bool updateSelectedImagePath = false,
    bool? isSending,
    String? draftText,
  }) {
    return ChatInputState(
      selectedImagePath: updateSelectedImagePath
          ? selectedImagePath
          : this.selectedImagePath,
      isSending: isSending ?? this.isSending,
      draftText: draftText ?? this.draftText,
    );
  }
}

class ChatInputCubit extends Cubit<ChatInputState> {
  ChatInputCubit({
    required ChatThreadActionsApi chatThreadActions,
    ChatAttachmentsCubit? attachmentsCubit,
  }) : _chatThreadActions = chatThreadActions,
       _attachmentsCubit = attachmentsCubit,
       super(const ChatInputState());

  final ChatThreadActionsApi _chatThreadActions;
  final ChatAttachmentsCubit? _attachmentsCubit;
  final ImagePicker _imagePicker = ImagePicker();
  int _sendSerial = 0;
  int? _activeSendSerial;

  Future<void> pickImage({required ChatAttachmentSource source}) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: switch (source) {
          ChatAttachmentSource.camera => ImageSource.camera,
          ChatAttachmentSource.gallery => ImageSource.gallery,
          ChatAttachmentSource.files => throw ArgumentError.value(source),
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
        ChatAttachmentSource.files => 'Files selected',
      };
      await AppToast.show(message, type: AppToastType.success);
    } catch (error) {
      await AppToast.show(
        'Image pick failed: $error',
        type: AppToastType.error,
      );
    }
  }

  Future<void> pickFiles({required bool allowImages}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          if (allowImages) ...['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
          'wav',
          'mp3',
          'm4a',
          'aac',
          'flac',
          'ogg',
          'opus',
          'pdf',
          'doc',
          'docx',
          'md',
          'markdown',
          'txt',
          'text',
          'csv',
          'tsv',
          'json',
          'yaml',
          'yml',
          'dart',
          'js',
          'ts',
          'py',
          'java',
          'kt',
          'swift',
          'c',
          'cpp',
          'h',
          'hpp',
          'go',
          'rs',
          'sql',
        ],
      );
      final paths =
          result?.files
              .map((file) => file.path)
              .whereType<String>()
              .toList(growable: false) ??
          const <String>[];
      if (paths.isEmpty) return;
      final attachmentsCubit = _attachmentsCubit;
      if (attachmentsCubit == null) return;
      await Future.wait(paths.map(attachmentsCubit.addPath));
    } catch (error) {
      await AppToast.show(
        'File selection failed: $error',
        type: AppToastType.error,
      );
    }
  }

  /// Replaces the tracked draft text (called as the input field changes).
  void setDraftText(String text) {
    if (text == state.draftText) return;
    emit(state.copyWith(draftText: text));
  }

  /// Appends [text] to the current draft, inserting a single space separator
  /// when the existing draft does not already end with whitespace. Used by the
  /// voice-input flow so a transcript is added to — not replacing — what the
  /// user already typed.
  void appendText(String text) {
    final addition = text.trim();
    if (addition.isEmpty) return;

    final current = state.draftText;
    final endsWithWhitespace =
        current.isNotEmpty &&
        current.substring(current.length - 1).trim().isEmpty;
    final combined = current.isEmpty
        ? addition
        : '$current${endsWithWhitespace ? '' : ' '}$addition';
    emit(state.copyWith(draftText: combined));
  }

  void clearSelectedImage() {
    emit(
      state.copyWith(selectedImagePath: null, updateSelectedImagePath: true),
    );
  }

  Future<void> sendMessage(String rawText) async {
    final text = rawText.trim();
    final imagePath = state.selectedImagePath;
    final attachments =
        _attachmentsCubit?.readyAttachments ?? const <PreparedChatAttachment>[];
    if (text.isEmpty && imagePath == null && attachments.isEmpty) return;
    if (_attachmentsCubit?.isPreparing ?? false) return;
    if (state.isSending) return;

    final sendSerial = ++_sendSerial;
    _activeSendSerial = sendSerial;
    emit(state.copyWith(isSending: true));
    try {
      emit(
        state.copyWith(
          selectedImagePath: null,
          updateSelectedImagePath: true,
          draftText: '',
        ),
      );
      await _chatThreadActions.sendMessage(
        text,
        imagePath: imagePath,
        attachments: attachments,
      );
      _attachmentsCubit?.consumeReadyAttachments();
    } finally {
      if (_activeSendSerial == sendSerial) {
        _activeSendSerial = null;
        emit(state.copyWith(isSending: false));
      }
    }
  }

  Future<void> stopGeneration() async {
    await _chatThreadActions.stopGeneration();
    if (!state.isSending) return;

    // The native/remote stream may need a little longer to unwind after its
    // cancellation signal. Release the composer now and invalidate the old
    // send so its eventual `finally` cannot clear a newer send's busy state.
    _activeSendSerial = null;
    _sendSerial += 1;
    emit(state.copyWith(isSending: false));
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
