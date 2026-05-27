import 'package:hydrated_bloc/hydrated_bloc.dart';

class WorkspaceDrawerCubit extends HydratedCubit<Map<String, bool>> {
  WorkspaceDrawerCubit() : super(const <String, bool>{});

  bool isExpanded(String workspaceId) => state[workspaceId] ?? false;

  void toggle(String workspaceId) {
    final expanded = isExpanded(workspaceId);
    emit(<String, bool>{...state, workspaceId: !expanded});
  }

  void remove(String workspaceId) {
    final next = <String, bool>{...state};
    next.remove(workspaceId);
    emit(next);
  }

  @override
  Map<String, bool>? fromJson(Map<String, dynamic> json) {
    final raw = json['expanded'] as Map<dynamic, dynamic>?;
    if (raw == null) return const <String, bool>{};

    return raw.map((key, value) => MapEntry(key.toString(), value == true));
  }

  @override
  Map<String, dynamic>? toJson(Map<String, bool> state) {
    return <String, dynamic>{'expanded': state};
  }
}
