// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MessageEntity _$MessageEntityFromJson(Map<String, dynamic> json) =>
    _MessageEntity(
      id: json['id'] as String,
      chatId: json['chatId'] as String,
      role: json['role'] as String,
      kind: json['kind'] as String,
      content: json['content'] as String,
      mediaPath: json['mediaPath'] as String?,
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
      'createdAt': instance.createdAt.toIso8601String(),
    };
