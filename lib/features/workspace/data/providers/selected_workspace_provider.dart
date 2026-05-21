import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/database/gena_provider.dart';
import 'package:gena/core/prompt.dart';

const defaultWorkspaceName = 'My workspace';

final selectedWorkspaceIdProvider =
    NotifierProvider<SelectedWorkspaceIdNotifier, String?>(
      SelectedWorkspaceIdNotifier.new,
    );

class SelectedWorkspaceIdNotifier extends Notifier<String?> {
  bool _initialized = false;

  @override
  String? build() {
    _hydrateInitialSelection();
    return null;
  }

  Future<void> _hydrateInitialSelection() async {
    if (_initialized) return;
    _initialized = true;

    final database = ref.read(genaDatabaseProvider);
    final firstWorkspace =
        await (database.select(database.workspaces)
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();

    if (firstWorkspace != null) {
      state = firstWorkspace.id.toString();
      return;
    }

    final createdWorkspaceId = await _createDefaultWorkspace();
    state = createdWorkspaceId;
  }

  Future<String> ensureWorkspace() async {
    if (state != null) return state!;
    final createdWorkspaceId = await _createDefaultWorkspace();
    state = createdWorkspaceId;
    return createdWorkspaceId;
  }

  Future<String> _createDefaultWorkspace() async {
    final database = ref.read(genaDatabaseProvider);
    final id = await database
        .into(database.workspaces)
        .insert(
          db.WorkspacesCompanion.insert(
            name: defaultWorkspaceName,
            generalInstruction: const Value(systemPrompt),
          ),
        );
    return id.toString();
  }

  void selectWorkspace(String? workspaceId) {
    if (workspaceId == state) return;
    state = workspaceId;
  }
}
