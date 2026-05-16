import 'package:freezed_annotation/freezed_annotation.dart';
part 'message_entity.g.dart';
part 'message_entity.freezed.dart';

@freezed
abstract class MessageEntity with _$MessageEntity {
  const factory MessageEntity({
    required String id,
    required String chatId,
    required String role,
    required String kind,
    required String content,
    String? mediaPath,
    required DateTime createdAt,
  }) = _MessageEntity;

  factory MessageEntity.fromJson(Map<String, dynamic> json) =>
      _$MessageEntityFromJson(json);
}
