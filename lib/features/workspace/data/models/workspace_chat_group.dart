import 'package:gena/features/chat/data/models/chat_entity.dart';
import 'package:gena/features/workspace/data/models/workspace_entity.dart';

class WorkspaceChatGroup {
  final WorkspaceEntity workspace;
  final List<ChatEntity> chats;

  const WorkspaceChatGroup({required this.workspace, required this.chats});
}
