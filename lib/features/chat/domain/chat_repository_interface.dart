import 'package:gena/features/chat/data/models/chat_entity.dart';
import 'package:gena/features/chat/data/models/message_entity.dart';

abstract class ChatRepository {
  Future<List<ChatEntity>> getChats();
  Future<void> insertChat(ChatEntity chat);
  Future<void> updateChat(ChatEntity chat);
  Future<void> deleteChat(String chatId);
  Future<List<MessageEntity>> getMessages(String chatId);
  Future<void> insertMessage(MessageEntity message);
}
