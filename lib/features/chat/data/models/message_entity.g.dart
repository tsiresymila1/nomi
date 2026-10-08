// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessageAttachmentEntity _$MessageAttachmentEntityFromJson(
  Map<String, dynamic> json,
) => MessageAttachmentEntity(
  id: json['id'] as String,
  kind: json['kind'] as String,
  name: json['name'] as String,
  sourceType: json['sourceType'] as String,
  path: json['path'] as String,
  sizeBytes: (json['sizeBytes'] as num).toInt(),
  workspaceDocumentId: (json['workspaceDocumentId'] as num?)?.toInt(),
);

Map<String, dynamic> _$MessageAttachmentEntityToJson(
  MessageAttachmentEntity instance,
) => <String, dynamic>{
  'id': instance.id,
  'kind': instance.kind,
  'name': instance.name,
  'sourceType': instance.sourceType,
  'path': instance.path,
  'sizeBytes': instance.sizeBytes,
  'workspaceDocumentId': instance.workspaceDocumentId,
};

_MessageEntity _$MessageEntityFromJson(Map<String, dynamic> json) =>
    _MessageEntity(
      id: json['id'] as String,
      chatId: json['chatId'] as String,
      role: json['role'] as String,
      kind: json['kind'] as String,
      content: json['content'] as String,
      mediaPath: json['mediaPath'] as String?,
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map(
                (e) =>
                    MessageAttachmentEntity.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <MessageAttachmentEntity>[],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$MessageEntityToJson(_MessageEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'chatId': instance.chatId,
      'role': instance.role,
      'kind': instance.kind,
      'content': instance.content,
      'mediaPath': instance.mediaPath,
      'attachments': instance.attachments,
      'createdAt': instance.createdAt.toIso8601String(),
    };
