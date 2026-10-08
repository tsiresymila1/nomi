enum ChatAttachmentKind { image, document }

enum ChatAttachmentFailureCode {
  missingFile,
  unsupportedType,
  tooLarge,
  extractionFailed,
}

class ChatAttachmentException implements Exception {
  const ChatAttachmentException({
    required this.code,
    required this.userMessage,
  });

  final ChatAttachmentFailureCode code;
  final String userMessage;

  @override
  String toString() => userMessage;
}

class PreparedChatAttachment {
  const PreparedChatAttachment({
    required this.id,
    required this.name,
    required this.kind,
    required this.sourceType,
    required this.appPath,
    required this.sizeBytes,
    this.extractedText,
  });

  final String id;
  final String name;
  final ChatAttachmentKind kind;
  final String sourceType;
  final String appPath;
  final int sizeBytes;
  final String? extractedText;
}

enum ChatAttachmentDraftStatus { preparing, ready, failed }

class ChatAttachmentDraft {
  const ChatAttachmentDraft({
    required this.id,
    required this.originalPath,
    required this.displayName,
    required this.status,
    this.attachment,
    this.errorMessage,
  });

  final String id;
  final String originalPath;
  final String displayName;
  final ChatAttachmentDraftStatus status;
  final PreparedChatAttachment? attachment;
  final String? errorMessage;

  ChatAttachmentDraft copyWith({
    ChatAttachmentDraftStatus? status,
    PreparedChatAttachment? attachment,
    String? errorMessage,
  }) {
    return ChatAttachmentDraft(
      id: id,
      originalPath: originalPath,
      displayName: displayName,
      status: status ?? this.status,
      attachment: attachment ?? this.attachment,
      errorMessage: errorMessage,
    );
  }
}
