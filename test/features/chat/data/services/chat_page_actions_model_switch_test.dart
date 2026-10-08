import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:genkit/genkit.dart' hide ModelInfo;
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/chat/data/services/active_model_info_service.dart';
import 'package:gena/features/chat/data/services/chat_page_actions_service.dart';
import 'package:gena/features/chat/data/services/chat_thread_actions_service.dart';
import 'package:gena/features/chat/data/services/local_model_runtime.dart';
import 'package:gena/features/chat/presentation/cubit/chat_ui_cubits.dart';
import 'package:gena/features/chat/presentation/cubit/selected_chat_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/selected_model_cubit.dart';
import 'package:gena/features/downloads/data/model_readiness.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/presentation/cubit/downloads_cubit.dart';
import 'package:gena/features/downloads/presentation/cubit/downloads_state.dart';
import 'package:gena/features/workspace/presentation/cubit/selected_workspace_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, (_) async => true);
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, null);
  });

  group('ChatPageActions model switching', () {
    test('prepares a local target before persisting its selection', () async {
      final events = <String>[];
      final switchingCubit = ChatModelSwitchingCubit();
      addTearDown(switchingCubit.close);
      final selectedModelCubit = _SelectedModelCubitFake(1, events);
      final runtime = _LocalModelRuntimeFake(events);
      final actions = _actions(
        events: events,
        switchingCubit: switchingCubit,
        selectedModelCubit: selectedModelCubit,
        runtime: runtime,
        previousModel: _localModel(1, 'Previous'),
      );

      await actions.selectModel(_localModel(2, 'Target'));

      expect(events, ['stop', 'reset', 'prepare:2', 'select:2']);
      expect(selectedModelCubit.state, 2);
      expect(switchingCubit.state.phase, ChatModelSwitchPhase.ready);
      expect(switchingCubit.state.modelId, 2);
    });

    test(
      'failed local preparation keeps and restores the previous model',
      () async {
        final events = <String>[];
        final switchingCubit = ChatModelSwitchingCubit();
        addTearDown(switchingCubit.close);
        final selectedModelCubit = _SelectedModelCubitFake(1, events);
        final runtime = _LocalModelRuntimeFake(events)..failModelId = 2;
        final actions = _actions(
          events: events,
          switchingCubit: switchingCubit,
          selectedModelCubit: selectedModelCubit,
          runtime: runtime,
          previousModel: _localModel(1, 'Previous'),
        );

        await expectLater(
          actions.selectModel(_localModel(2, 'Broken target')),
          throwsStateError,
        );

        expect(selectedModelCubit.state, 1);
        expect(events, ['stop', 'reset', 'prepare:2', 'prepare:1']);
        expect(switchingCubit.state.phase, ChatModelSwitchPhase.failed);
        expect(switchingCubit.state.modelId, 2);
        expect(switchingCubit.state.errorMessage, isNotEmpty);
      },
    );

    test(
      'remote selection releases local runtime without preparing target',
      () async {
        final events = <String>[];
        final switchingCubit = ChatModelSwitchingCubit();
        addTearDown(switchingCubit.close);
        final selectedModelCubit = _SelectedModelCubitFake(1, events);
        final runtime = _LocalModelRuntimeFake(events);
        final actions = _actions(
          events: events,
          switchingCubit: switchingCubit,
          selectedModelCubit: selectedModelCubit,
          runtime: runtime,
          previousModel: _localModel(1, 'Previous'),
        );

        await actions.selectModel(_remoteModel(3, 'Remote'));

        expect(events, ['stop', 'reset', 'select:3']);
        expect(runtime.preparedModelIds, isEmpty);
        expect(selectedModelCubit.state, 3);
        expect(switchingCubit.state.phase, ChatModelSwitchPhase.ready);
      },
    );

    test('background warm-up exposes a recoverable failure state', () async {
      final events = <String>[];
      final switchingCubit = ChatModelSwitchingCubit();
      addTearDown(switchingCubit.close);
      final selectedModelCubit = _SelectedModelCubitFake(1, events);
      final runtime = _LocalModelRuntimeFake(events)..failModelId = 1;
      final actions = _actions(
        events: events,
        switchingCubit: switchingCubit,
        selectedModelCubit: selectedModelCubit,
        runtime: runtime,
        previousModel: _localModel(1, 'Previous'),
      );

      await actions.selectChat('42');
      await Future<void>.delayed(Duration.zero);

      expect(switchingCubit.state.phase, ChatModelSwitchPhase.failed);
      expect(switchingCubit.state.modelId, 1);
      expect(switchingCubit.state.errorMessage, isNotEmpty);
    });
  });
}

ChatPageActions _actions({
  required List<String> events,
  required ChatModelSwitchingCubit switchingCubit,
  required _SelectedModelCubitFake selectedModelCubit,
  required _LocalModelRuntimeFake runtime,
  required ModelInfo previousModel,
}) {
  final models = [
    previousModel,
    _localModel(2, 'Target'),
    _remoteModel(3, 'Remote'),
  ];
  return ChatPageActions(
    selectedChatCubit: _SelectedChatCubitFake(),
    selectedWorkspaceCubit: _SelectedWorkspaceCubitFake(),
    chatThreadActions: _ChatThreadActionsFake(events),
    downloadsCubit: _DownloadsCubitFake(),
    chatModelSwitchingCubit: switchingCubit,
    selectedModelCubit: selectedModelCubit,
    activeModelInfoResolver: _ActiveModelInfoResolverFake(previousModel),
    modelRepository: _ModelRepositoryFake(models),
    modelInstallerService: _ModelInstallerServiceFake(models),
    localModelRuntime: runtime,
    capabilities: AppCapabilities.forPlatform(AppPlatform.android),
  );
}

ModelInfo _localModel(int id, String name) => ModelInfo(
  id: id,
  name: name,
  description: '',
  provider: ModelProviderType.local,
  modelType: 'general',
  supportImage: false,
  supportAudio: false,
  supportsFunctionCalls: false,
  isThinking: false,
  temperature: 0.7,
  topK: 40,
  topP: 0.95,
  maxTokens: 2048,
  tokenBuffer: 256,
  randomSeed: 1,
  preferredBackend: 'cpu',
  sourceType: 'file',
  source: '/models/model-$id.gguf',
);

ModelInfo _remoteModel(int id, String name) => ModelInfo(
  id: id,
  name: name,
  description: '',
  provider: ModelProviderType.remote,
  modelType: 'general',
  supportImage: false,
  supportAudio: false,
  supportsFunctionCalls: false,
  isThinking: false,
  temperature: 0.7,
  topK: 40,
  topP: 0.95,
  maxTokens: 2048,
  tokenBuffer: 256,
  randomSeed: 1,
  preferredBackend: 'cpu',
  sourceType: 'remote',
  source: 'remote-server://server/model-$id',
);

class _ChatThreadActionsFake extends Fake implements ChatThreadActions {
  _ChatThreadActionsFake(this.events);
  final List<String> events;

  @override
  Future<void> stopGeneration({
    bool triggerLocalModelCancel = true,
    bool waitForLocalModelCancel = true,
  }) async {
    events.add('stop');
  }
}

class _SelectedModelCubitFake extends Fake implements SelectedModelCubit {
  _SelectedModelCubitFake(this._state, this.events);
  int? _state;
  final List<String> events;

  @override
  int? get state => _state;

  @override
  Future<void> selectModel(int modelId) async {
    events.add('select:$modelId');
    _state = modelId;
  }
}

class _LocalModelRuntimeFake extends Fake implements LocalModelRuntime {
  _LocalModelRuntimeFake(this.events);
  final List<String> events;
  final List<int> preparedModelIds = [];
  int? failModelId;

  @override
  Future<void> reset() async => events.add('reset');

  @override
  Future<PreparedLocalModel> prepare(ModelInfo model) async {
    events.add('prepare:${model.id}');
    preparedModelIds.add(model.id);
    if (model.id == failModelId) {
      throw StateError('prepare failed for ${model.id}');
    }
    return PreparedLocalModel(
      ai: Genkit(),
      modelRef: modelRef<dynamic>('fake-${model.id}'),
      modelId: 'fake-${model.id}',
    );
  }
}

class _ActiveModelInfoResolverFake extends Fake
    implements ActiveModelInfoResolver {
  _ActiveModelInfoResolverFake(this.model);
  final ModelInfo model;

  @override
  Future<ModelInfo?> getActiveModelInfo() async => model;
}

class _ModelRepositoryFake extends Fake implements ModelRepository {
  _ModelRepositoryFake(this.models);
  final List<ModelInfo> models;

  @override
  Stream<List<ModelInfo>> watchModels() => Stream.value(models);
}

class _ModelInstallerServiceFake extends Fake implements ModelInstallerService {
  _ModelInstallerServiceFake(this.models);
  final List<ModelInfo> models;

  @override
  Future<List<String>> listInstalledModels() async => models
      .where((model) => model.provider == ModelProviderType.local)
      .map((model) => installedModelIdFromSource(model.source))
      .toList();
}

class _SelectedChatCubitFake extends Fake implements SelectedChatCubit {
  @override
  void selectChat(String? chatId) {}
}

class _SelectedWorkspaceCubitFake extends Fake
    implements SelectedWorkspaceCubit {}

class _DownloadsCubitFake extends Fake implements DownloadsCubit {
  @override
  DownloadsState get state => const DownloadsState(loading: false);
}
