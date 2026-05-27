import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/prompt.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

const defaultWorkspaceName = 'My workspace';

class SelectedWorkspaceCubit extends HydratedCubit<String?> {
  SelectedWorkspaceCubit(this._database) : super(null) {
    _hydrateInitialSelection();
  }

  final db.GenaDatabase _database;
  bool _initialized = false;

  Future<void> _hydrateInitialSelection() async {
    if (_initialized) return;
    _initialized = true;
    if (state != null) return;

    final firstWorkspace =
        await (_database.select(_database.workspaces)
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();

    if (state != null) return;
    if (firstWorkspace != null) {
      emit(firstWorkspace.id.toString());
      return;
    }

    final createdWorkspaceId = await _createDefaultWorkspace();
    if (state == null) {
      emit(createdWorkspaceId);
    }
  }

  Future<String> ensureWorkspace() async {
    if (state != null) return state!;
    final createdWorkspaceId = await _createDefaultWorkspace();
    emit(createdWorkspaceId);
    return createdWorkspaceId;
  }

  void selectWorkspace(String? workspaceId) {
    if (workspaceId == state) return;
    emit(workspaceId);
  }

  Future<String> _createDefaultWorkspace() async {
    final id = await _database
        .into(_database.workspaces)
        .insert(
          db.WorkspacesCompanion.insert(
            name: defaultWorkspaceName,
            generalInstruction: const Value(systemPrompt),
            nativeToolsEnabled: const Value(true),
            nativeOpenUrlEnabled: const Value(true),
            nativeOpenAppEnabled: const Value(true),
            nativeSendEmailEnabled: const Value(true),
            nativeFlashlightEnabled: const Value(true),
          ),
        );
    return id.toString();
  }

  @override
  String? fromJson(Map<String, dynamic> json) {
    final workspaceId = json['workspaceId'] as String?;
    if (workspaceId == null || workspaceId.trim().isEmpty) {
      return null;
    }
    return workspaceId;
  }

  @override
  Map<String, dynamic>? toJson(String? state) {
    if (state == null || state.trim().isEmpty) {
      return const <String, dynamic>{};
    }
    return <String, dynamic>{'workspaceId': state};
  }
}
