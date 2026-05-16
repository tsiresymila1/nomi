import 'package:freezed_annotation/freezed_annotation.dart';
part 'chat_entity.g.dart';
part 'chat_entity.freezed.dart';


@freezed
abstract class ChatEntity with _$ChatEntity {
  const factory ChatEntity({
    required String id,
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ChatEntity;

  factory ChatEntity.fromJson(Map<String, dynamic> json) =>
      _$ChatEntityFromJson(json);
}
