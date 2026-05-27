import 'package:gena/features/downloads/data/models/model_info.dart';

class ActiveModelInstall {
  const ActiveModelInstall({required this.key, required this.label});

  final String key;
  final String label;
}

class DownloadsState {
  const DownloadsState({
    this.models = const [],
    this.installedModels = const [],
    this.progressByKey = const {},
    this.activeInstall,
    this.loading = true,
    this.errorMessage,
  });

  final List<ModelInfo> models;
  final List<String> installedModels;
  final Map<String, double> progressByKey;
  final ActiveModelInstall? activeInstall;
  final bool loading;
  final String? errorMessage;

  DownloadsState copyWith({
    List<ModelInfo>? models,
    List<String>? installedModels,
    Map<String, double>? progressByKey,
    ActiveModelInstall? activeInstall,
    bool clearActiveInstall = false,
    bool? loading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DownloadsState(
      models: models ?? this.models,
      installedModels: installedModels ?? this.installedModels,
      progressByKey: progressByKey ?? this.progressByKey,
      activeInstall: clearActiveInstall
          ? null
          : (activeInstall ?? this.activeInstall),
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
