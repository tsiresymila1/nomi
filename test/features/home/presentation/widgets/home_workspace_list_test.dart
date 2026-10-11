import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/models/chat_entity.dart';
import 'package:gena/features/home/presentation/widgets/home_workspace_list.dart';
import 'package:gena/features/workspace/data/models/workspace_chat_group.dart';
import 'package:gena/features/workspace/data/models/workspace_entity.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  WorkspaceEntity workspace(String id) => WorkspaceEntity(
    id: id,
    name: 'Workspace $id',
    generalInstruction: '',
    ragEnabled: false,
    nativeToolsEnabled: false,
    nativeOpenUrlEnabled: false,
    nativeOpenAppEnabled: false,
    nativeSendEmailEnabled: false,
    nativeFlashlightEnabled: false,
    mcpEnabled: false,
    memoryEnabled: false,
    createdAt: now,
  );

  ChatEntity chat(String id, String workspaceId) => ChatEntity(
    id: id,
    workspaceId: workspaceId,
    title: 'Chat $id',
    createdAt: now,
    updatedAt: now,
  );

  Widget subject({
    required List<WorkspaceChatGroup> groups,
    required void Function(String, String) onOpenChat,
    required ValueChanged<String> onOpenWorkspaceChat,
    required ValueChanged<String> onOpenWorkspaceSettings,
  }) => MaterialApp(
    home: Scaffold(
      body: HomeWorkspaceList(
        groups: groups,
        onOpenChat: onOpenChat,
        onOpenWorkspaceChat: onOpenWorkspaceChat,
        onOpenWorkspaceSettings: onOpenWorkspaceSettings,
      ),
    ),
  );

  testWidgets('opens a chat directly and exposes workspace settings', (
    tester,
  ) async {
    String? openedWorkspaceId;
    String? openedChatId;
    String? settingsWorkspaceId;
    final group = WorkspaceChatGroup(
      workspace: workspace('7'),
      chats: [chat('42', '7')],
    );

    await tester.pumpWidget(
      subject(
        groups: [group],
        onOpenChat: (workspaceId, chatId) {
          openedWorkspaceId = workspaceId;
          openedChatId = chatId;
        },
        onOpenWorkspaceChat: (_) {},
        onOpenWorkspaceSettings: (workspaceId) {
          settingsWorkspaceId = workspaceId;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('workspace-settings-7')));
    expect(settingsWorkspaceId, '7');

    await tester.tap(find.text('Workspace 7'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-chat-42')));

    expect(openedWorkspaceId, '7');
    expect(openedChatId, '42');
  });

  testWidgets('starts a chat from an empty workspace', (tester) async {
    String? openedWorkspaceId;
    final group = WorkspaceChatGroup(
      workspace: workspace('9'),
      chats: const [],
    );

    await tester.pumpWidget(
      subject(
        groups: [group],
        onOpenChat: (_, _) {},
        onOpenWorkspaceChat: (workspaceId) {
          openedWorkspaceId = workspaceId;
        },
        onOpenWorkspaceSettings: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workspace 9'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workspace-start-chat-9')));

    expect(openedWorkspaceId, '9');
  });
}
