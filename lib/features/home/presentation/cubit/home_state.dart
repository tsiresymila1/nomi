import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/workspace/data/models/workspace_chat_group.dart';

class HomeState {
  const HomeState({
    this.groups = const [],
    this.models = const [],
    this.installedModels = const [],
    this.selectedModelId,
    this.embedderStatus = 'Workspace RAG engine status unknown',
    this.loading = true,
    this.errorMessage,
  });

  final List<WorkspaceChatGroup> groups;
  final List<ModelInfo> models;
  final List<String> installedModels;
  final int? selectedModelId;
  final String embedderStatus;
  final bool loading;
  final String? errorMessage;

  HomeState copyWith({
    List<WorkspaceChatGroup>? groups,
    List<ModelInfo>? models,
    List<String>? installedModels,
    int? selectedModelId,
    bool clearSelectedModel = false,
    String? embedderStatus,
    bool? loading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HomeState(
      groups: groups ?? this.groups,
      models: models ?? this.models,
      installedModels: installedModels ?? this.installedModels,
      selectedModelId: clearSelectedModel
          ? null
          : (selectedModelId ?? this.selectedModelId),
      embedderStatus: embedderStatus ?? this.embedderStatus,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
