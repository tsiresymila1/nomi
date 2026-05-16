import 'package:freezed_annotation/freezed_annotation.dart';
part 'chat_message.g.dart';
part 'chat_message.freezed.dart';


@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required String chatId,
    required String role,
    required String content,
    required DateTime createdAt,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}
