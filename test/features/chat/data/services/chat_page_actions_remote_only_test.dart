import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/chat/data/services/active_model_info_service.dart';
import 'package:gena/features/chat/data/services/chat_page_actions_service.dart';
import 'package:gena/features/chat/data/services/chat_thread_actions_service.dart';
import 'package:gena/features/chat/data/services/unsupported_local_model_runtime.dart';
import 'package:gena/features/chat/presentation/cubit/chat_ui_cubits.dart';
import 'package:gena/features/chat/presentation/cubit/selected_chat_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/selected_model_cubit.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/presentation/cubit/downloads_cubit.dart';
import 'package:gena/features/downloads/presentation/cubit/downloads_state.dart';
import 'package:gena/features/workspace/presentation/cubit/selected_workspace_cubit.dart';

void main() {
  test(
    'remote-only chat entry selects remote model without local registry',
    () async {
      final selectedModelCubit = _SelectedModelCubitFake();
      final switchingCubit = ChatModelSwitchingCubit();
      addTearDown(switchingCubit.close);
      final actions = ChatPageActions(
        selectedChatCubit: _SelectedChatCubitFake(),
        selectedWorkspaceCubit: _SelectedWorkspaceCubitFake(),
        chatThreadActions: _ChatThreadActionsFake(),
        downloadsCubit: _DownloadsCubitFake(),
        chatModelSwitchingCubit: switchingCubit,
        selectedModelCubit: selectedModelCubit,
        activeModelInfoResolver: _ActiveModelInfoResolverFake(),
        modelRepository: _ModelRepositoryFake([_remoteModel]),
        modelInstallerService: _ThrowingModelInstallerService(),
        localModelRuntime: UnsupportedLocalModelRuntime(),
        capabilities: AppCapabilities.forPlatform(AppPlatform.web),
      );

      await actions.selectChat('42');

      expect(selectedModelCubit.state, _remoteModel.id);
    },
  );
}

final ModelInfo _remoteModel = ModelInfo(
  id: 7,
  name: 'Remote model',
  description: '',
  provider: ModelProviderType.remote,
  modelType: 'gemmaIt',
  supportImage: false,
  supportAudio: false,
  supportsFunctionCalls: false,
  isThinking: false,
  temperature: 0.7,
  topK: 40,
  topP: 0.95,
  maxTokens: 4096,
  tokenBuffer: 256,
  randomSeed: 1,
  preferredBackend: 'cpu',
  sourceType: 'remote',
  source: 'remote-server://server/model',
);

class _ModelRepositoryFake extends Fake implements ModelRepository {
  _ModelRepositoryFake(this.models);

  final List<ModelInfo> models;

  @override
  Stream<List<ModelInfo>> watchModels() => Stream.value(models);
}

class _ThrowingModelInstallerService extends Fake
    implements ModelInstallerService {
  @override
  Future<List<String>> listInstalledModels() {
    throw StateError('local registry must not be called');
  }
}

class _SelectedModelCubitFake extends Fake implements SelectedModelCubit {
  int? _state;

  @override
  int? get state => _state;

  @override
  Future<void> selectModel(int modelId) async {
    _state = modelId;
  }
}

class _SelectedChatCubitFake extends Fake implements SelectedChatCubit {
  @override
  void selectChat(String? chatId) {}
}

class _SelectedWorkspaceCubitFake extends Fake
    implements SelectedWorkspaceCubit {}

class _ChatThreadActionsFake extends Fake implements ChatThreadActions {
  @override
  Future<void> stopGeneration({
    bool triggerLocalModelCancel = true,
    bool waitForLocalModelCancel = true,
  }) async {}
}

class _DownloadsCubitFake extends Fake implements DownloadsCubit {
  @override
  DownloadsState get state => const DownloadsState(loading: false);
}

class _ActiveModelInfoResolverFake extends Fake
    implements ActiveModelInfoResolver {
  @override
  Future<ModelInfo?> getActiveModelInfo() async => _remoteModel;
}
