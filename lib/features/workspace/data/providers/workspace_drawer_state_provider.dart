import 'package:flutter_riverpod/flutter_riverpod.dart';

final workspaceDrawerStateProvider =
    NotifierProvider<WorkspaceDrawerStateNotifier, Map<String, bool>>(
      WorkspaceDrawerStateNotifier.new,
    );

class WorkspaceDrawerStateNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => <String, bool>{};

  bool isExpanded(String workspaceId) => state[workspaceId] ?? false;

  void toggle(String workspaceId) {
    final expanded = isExpanded(workspaceId);
    state = {...state, workspaceId: !expanded};
  }

  void remove(String workspaceId) {
    final next = {...state};
    next.remove(workspaceId);
    state = next;
  }
}
