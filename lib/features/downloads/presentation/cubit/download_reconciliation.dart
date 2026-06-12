import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/services/model_download_task.dart';
import 'package:gena/features/downloads/presentation/cubit/downloads_state.dart';

DownloadsState reconcileBackgroundDownloads(
  DownloadsState state,
  List<ModelDownloadSnapshot> snapshots,
) {
  final activeInstall = state.activeInstall;
  if (activeInstall != null) {
    final matchingSnapshot = _snapshotForKey(snapshots, activeInstall.key);
    if (matchingSnapshot == null) return state;

    if (!matchingSnapshot.isTerminal) {
      return state.copyWith(
        progressByKey: {
          ...state.progressByKey,
          activeInstall.key: matchingSnapshot.progress.clamp(0.0, 1.0),
        },
      );
    }

    if (matchingSnapshot.status == ModelDownloadStatus.cancelled) {
      final nextProgress = {...state.progressByKey}..remove(activeInstall.key);
      return state.copyWith(
        progressByKey: nextProgress,
        clearActiveInstall: true,
        clearError: true,
      );
    }
    return state;
  }

  for (final snapshot in snapshots) {
    if (snapshot.isTerminal) continue;
    final model = _modelForKey(state.models, snapshot.modelKey);
    if (model == null) continue;

    return state.copyWith(
      progressByKey: {
        ...state.progressByKey,
        snapshot.modelKey: snapshot.progress.clamp(0.0, 1.0),
      },
      activeInstall: ActiveModelInstall(
        key: snapshot.modelKey,
        label: model.name.isEmpty ? snapshot.modelLabel : model.name,
      ),
      clearError: true,
    );
  }

  return state;
}

ModelDownloadSnapshot? _snapshotForKey(
  List<ModelDownloadSnapshot> snapshots,
  String key,
) {
  for (final snapshot in snapshots) {
    if (snapshot.modelKey == key) return snapshot;
  }
  return null;
}

ModelInfo? _modelForKey(List<ModelInfo> models, String key) {
  for (final model in models) {
    if ('model_${model.id}' == key) return model;
  }
  return null;
}
