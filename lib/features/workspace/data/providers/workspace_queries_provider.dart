import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/features/chat/data/models/chat_entity.dart';
import 'package:gena/features/workspace/data/models/workspace_chat_group.dart';
import 'package:gena/features/workspace/data/models/workspace_entity.dart';
import 'package:gena/features/workspace/data/providers/selected_workspace_provider.dart';

final workspaceListProvider = StreamProvider<List<WorkspaceEntity>>((ref) {
  final database = ref.watch(genaDatabaseProvider);
  final query = database.select(database.workspaces)
    ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);

  return query.watch().map(
    (rows) => rows
        .map(
          (row) => WorkspaceEntity(
            id: row.id.toString(),
            name: row.name,
            generalInstruction: row.generalInstruction,
            ragEnabled: row.ragEnabled,
            createdAt: row.createdAt,
          ),
        )
        .toList(),
  );
});

final activeWorkspaceProvider = Provider<WorkspaceEntity?>((ref) {
  final selectedWorkspaceId = ref.watch(selectedWorkspaceIdProvider);
  final workspaces = ref.watch(workspaceListProvider).asData?.value;
  if (selectedWorkspaceId == null || workspaces == null) {
    return null;
  }

  for (final workspace in workspaces) {
    if (workspace.id == selectedWorkspaceId) {
      return workspace;
    }
  }
  return null;
});

final workspaceChatGroupsProvider = StreamProvider<List<WorkspaceChatGroup>>((
  ref,
) {
  final database = ref.watch(genaDatabaseProvider);

  final joinQuery =
      database.select(database.workspaces).join([
        leftOuterJoin(
          database.chats,
          database.chats.workspace.equalsExp(database.workspaces.id),
        ),
      ])..orderBy([
        OrderingTerm.asc(database.workspaces.createdAt),
        OrderingTerm.desc(database.chats.createdAt),
      ]);

  return joinQuery.watch().map((rows) {
    final grouped = <int, WorkspaceChatGroup>{};

    for (final row in rows) {
      final workspaceRow = row.readTable(database.workspaces);
      final workspaceId = workspaceRow.id;
      final currentGroup = grouped[workspaceId];

      final workspace = WorkspaceEntity(
        id: workspaceRow.id.toString(),
        name: workspaceRow.name,
        generalInstruction: workspaceRow.generalInstruction,
        ragEnabled: workspaceRow.ragEnabled,
        createdAt: workspaceRow.createdAt,
      );

      if (currentGroup == null) {
        grouped[workspaceId] = WorkspaceChatGroup(
          workspace: workspace,
          chats: <ChatEntity>[],
        );
      }

      final chatRow = row.readTableOrNull(database.chats);
      if (chatRow == null) continue;

      grouped[workspaceId]!.chats.add(
        ChatEntity(
          id: chatRow.id.toString(),
          workspaceId: chatRow.workspace.toString(),
          title: chatRow.title,
          createdAt: chatRow.createdAt,
          updatedAt: chatRow.createdAt,
        ),
      );
    }

    return grouped.values.toList(growable: false);
  });
});
