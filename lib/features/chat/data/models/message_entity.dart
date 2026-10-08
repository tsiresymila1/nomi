import 'package:freezed_annotation/freezed_annotation.dart';
part 'message_entity.g.dart';
part 'message_entity.freezed.dart';

@JsonSerializable()
class MessageAttachmentEntity {
  const MessageAttachmentEntity({
    required this.id,
    required this.kind,
    required this.name,
    required this.sourceType,
    required this.path,
    required this.sizeBytes,
    this.workspaceDocumentId,
  });

  final String id;
  final String kind;
  final String name;
  final String sourceType;
  final String path;
  final int sizeBytes;
  final int? workspaceDocumentId;

  factory MessageAttachmentEntity.fromJson(Map<String, dynamic> json) =>
      _$MessageAttachmentEntityFromJson(json);

  Map<String, dynamic> toJson() => _$MessageAttachmentEntityToJson(this);
}

@freezed
abstract class MessageEntity with _$MessageEntity {
  const factory MessageEntity({
    required String id,
    required String chatId,
    required String role,
    required String kind,
    required String content,
    String? mediaPath,
    @Default(<MessageAttachmentEntity>[])
    List<MessageAttachmentEntity> attachments,
    required DateTime createdAt,
  }) = _MessageEntity;

  factory MessageEntity.fromJson(Map<String, dynamic> json) =>
      _$MessageEntityFromJson(json);
}
