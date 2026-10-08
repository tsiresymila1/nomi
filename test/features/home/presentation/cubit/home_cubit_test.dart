import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/chat/presentation/cubit/selected_chat_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/selected_model_cubit.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/home/presentation/cubit/home_cubit.dart';
import 'package:gena/features/workspace/data/models/workspace_rag_result.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_backend.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_vector_store.dart';
import 'package:gena/features/workspace/presentation/cubit/selected_workspace_cubit.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../../support/in_memory_hydrated_storage.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

const _localCapabilities = AppCapabilities(
  platform: AppPlatform.android,
  supportsRemoteModels: true,
  supportsLocalModels: true,
  supportsWorkspaceRag: true,
  supportsSpeechToText: true,
  supportsTextToSpeech: true,
  supportsMcp: true,
);

const _webCapabilities = AppCapabilities(
  platform: AppPlatform.web,
  supportsRemoteModels: true,
  supportsLocalModels: false,
  supportsWorkspaceRag: false,
  supportsSpeechToText: false,
  supportsTextToSpeech: false,
  supportsMcp: true,
);

/// Records calls and returns a fixed installed-model list.
class _FakeInstaller extends ModelInstallerService {
  _FakeInstaller(super.repository, this.installed);

  List<String> installed;
  int calls = 0;

  @override
  Future<List<String>> listInstalledModels() async {
    calls += 1;
    return installed;
  }
}

class _FakeRagBackend implements WorkspaceRagBackend {
  bool ready = false;
  bool throwOnReady = false;

  @override
  Future<void> ensureReady() async {
    if (throwOnReady) throw StateError('engine boom');
    ready = true;
  }

  @override
  Future<WorkspaceRagIngestResult> addDocument(
    String workspaceId,
    WorkspaceRagDocument document,
  ) async =>
      const WorkspaceRagIngestResult(sourceId: 1, chunkCount: 1);

  @override
  Future<void> removeDocument(String workspaceId, int sourceId) async {}

  @override
  Future<void> rebuildWorkspace(String workspaceId) async {}

  @override
  Future<List<WorkspaceRagResult>> search(
    String workspaceId,
    String query, {
    required int topK,
    required double threshold,
  }) async =>
      const <WorkspaceRagResult>[];
}

void main() {
  late db.GenaDatabase database;
  late ModelRepository modelRepository;
  late ModelRepositoryActions modelRepositoryActions;
  late DefaultModelSeeder seeder;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    HydratedBloc.storage = InMemoryHydratedStorage();
    database = db.GenaDatabase(NativeDatabase.memory());
    modelRepository = ModelRepository(database);
    seeder = DefaultModelSeeder(database);
    modelRepositoryActions = ModelRepositoryActions(
      database: database,
      defaultModelSeeder: seeder,
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> insertRemoteModel({String name = 'Remote GPT'}) {
    return modelRepositoryActions
        .addModel(
          name: name,
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
          maxTokens: 2048,
          tokenBuffer: 256,
          randomSeed: 1,
          preferredBackend: 'gpu',
          sourceType: 'network',
          source: 'https://example.com/api',
        )
        .then((_) async {
      final rows = await database.select(database.models).get();
      return rows.firstWhere((row) => row.name == name).id;
    });
  }

  HomeCubit buildCubit({
    AppCapabilities capabilities = _localCapabilities,
    _FakeInstaller? installer,
    _FakeRagBackend? backend,
    SelectedModelCubit? selectedModelCubit,
    SelectedWorkspaceCubit? selectedWorkspaceCubit,
    SelectedChatCubit? selectedChatCubit,
  }) {
    final modelCubit = selectedModelCubit ?? SelectedModelCubit();
    final workspaceCubit =
        selectedWorkspaceCubit ?? SelectedWorkspaceCubit(database);
    final chatCubit = selectedChatCubit ??
        SelectedChatCubit(
          database: database,
          selectedWorkspaceCubit: workspaceCubit,
        );
    addTearDown(modelCubit.close);
    addTearDown(workspaceCubit.close);
    addTearDown(chatCubit.close);

    return HomeCubit(
      database: database,
      modelRepository: modelRepository,
      modelInstallerService:
          installer ?? _FakeInstaller(modelRepository, const <String>[]),
      modelRepositoryActions: modelRepositoryActions,
      defaultModelSeeder: seeder,
      workspaceRagVectorStore: WorkspaceRagVectorStore(
        capabilities: capabilities,
        backend: backend ?? _FakeRagBackend(),
      ),
      selectedModelCubit: modelCubit,
      selectedWorkspaceCubit: workspaceCubit,
      selectedChatCubit: chatCubit,
      capabilities: capabilities,
    );
  }

  group('initialization', () {
    test('loads models, installed list, and embedder status', () async {
      await insertRemoteModel();
      final installer = _FakeInstaller(modelRepository, const ['model-a']);
      final cubit = buildCubit(installer: installer);
      addTearDown(cubit.close);
      await _settle();
      await _settle();

      expect(cubit.state.loading, isFalse);
      // The seeder also inserts the default catalog, so the inserted remote
      // model is present alongside the seeded defaults.
      expect(
        cubit.state.models.any((model) => model.name == 'Remote GPT'),
        isTrue,
      );
      expect(cubit.state.installedModels, ['model-a']);
      expect(cubit.state.embedderStatus, 'Workspace RAG engine is ready');
      expect(cubit.state.errorMessage, isNull);
    });

    test('surfaces RAG unavailable message on web', () async {
      final cubit = buildCubit(capabilities: _webCapabilities);
      addTearDown(cubit.close);
      await _settle();
      await _settle();

      expect(cubit.state.installedModels, isEmpty);
      expect(
        cubit.state.embedderStatus,
        _webCapabilities.workspaceRagUnavailableMessage,
      );
    });

    test('reports not-ready status when the engine fails to initialize',
        () async {
      final backend = _FakeRagBackend()..throwOnReady = true;
      final cubit = buildCubit(backend: backend);
      addTearDown(cubit.close);
      await _settle();
      await _settle();

      expect(
        cubit.state.embedderStatus,
        'Workspace RAG engine is not ready yet',
      );
    });
  });

  group('setSelectedModel', () {
    test('clears the selection when null is passed', () async {
      final modelCubit = SelectedModelCubit();
      await modelCubit.selectModel(5);
      final cubit = buildCubit(selectedModelCubit: modelCubit);
      addTearDown(cubit.close);
      await _settle();

      await cubit.setSelectedModel(null);
      expect(cubit.state.selectedModelId, isNull);
      expect(modelCubit.state, isNull);
    });

    test('selects a remote model and mirrors it into state', () async {
      final remoteId = await insertRemoteModel();
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _settle();
      await _settle();

      await cubit.setSelectedModel(remoteId);
      expect(cubit.state.selectedModelId, remoteId);
    });

    test('throws when selecting a local model without local support',
        () async {
      // Seed a local default model and run on web (no local support).
      await seeder.ensureSeeded();
      final cubit = buildCubit(capabilities: _webCapabilities);
      addTearDown(cubit.close);
      await _settle();
      await _settle();

      final localModel = cubit.state.models.firstWhere(
        (model) => model.provider == ModelProviderType.local,
      );
      expect(
        () => cubit.setSelectedModel(localModel.id),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('installOrCheckEmbedder', () {
    test('reports ready when the engine initializes', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _settle();

      await cubit.installOrCheckEmbedder();
      expect(cubit.state.embedderStatus, 'Workspace RAG engine is ready');
      expect(cubit.state.errorMessage, isNull);
    });

    test('rethrows and records failure when the engine errors', () async {
      final backend = _FakeRagBackend()..throwOnReady = true;
      final cubit = buildCubit(backend: backend);
      addTearDown(cubit.close);
      await _settle();

      await expectLater(cubit.installOrCheckEmbedder(), throwsA(anything));
      expect(
        cubit.state.embedderStatus,
        'Workspace RAG engine failed to initialize',
      );
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('throws on web where RAG is unsupported', () async {
      final cubit = buildCubit(capabilities: _webCapabilities);
      addTearDown(cubit.close);
      await _settle();

      expect(cubit.installOrCheckEmbedder(), throwsA(isA<StateError>()));
    });
  });

  group('createWorkspace', () {
    test('creates a workspace and an initial chat, returning ids', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _settle();

      final result = await cubit.createWorkspace('  Research  ');
      final parts = result.split(':');
      expect(parts, hasLength(2));

      final workspaces = await database.select(database.workspaces).get();
      expect(
        workspaces.any((workspace) => workspace.name == 'Research'),
        isTrue,
      );
      final chats = await database.select(database.chats).get();
      expect(chats.any((chat) => chat.id.toString() == parts[1]), isTrue);
    });

    test('rejects a blank name', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _settle();

      expect(
        () => cubit.createWorkspace('   '),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ensureWorkspaceChatSelection', () {
    test('returns the latest existing chat for a workspace', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _settle();

      final workspaceId = await database
          .into(database.workspaces)
          .insert(db.WorkspacesCompanion.insert(name: 'WS'));
      await database.into(database.chats).insert(
            db.ChatsCompanion.insert(
              title: 'Old chat',
              workspace: workspaceId,
              createdAt: Value(DateTime(2020)),
            ),
          );
      final newer = await database.into(database.chats).insert(
            db.ChatsCompanion.insert(
              title: 'New chat',
              workspace: workspaceId,
              createdAt: Value(DateTime(2024)),
            ),
          );

      final result =
          await cubit.ensureWorkspaceChatSelection(workspaceId.toString());
      expect(result, newer.toString());
    });

    test('creates a chat when the workspace has none', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _settle();

      final workspaceId = await database
          .into(database.workspaces)
          .insert(db.WorkspacesCompanion.insert(name: 'Empty WS'));

      final result =
          await cubit.ensureWorkspaceChatSelection(workspaceId.toString());
      final chats = await (database.select(database.chats)
            ..where((t) => t.workspace.equals(workspaceId)))
          .get();
      expect(chats, hasLength(1));
      expect(result, chats.single.id.toString());
    });

    test('throws on an invalid workspace id', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _settle();

      expect(
        () => cubit.ensureWorkspaceChatSelection('nope'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('resetSeededModels', () {
    test('reseeds defaults and clears the active selection', () async {
      final modelCubit = SelectedModelCubit();
      await modelCubit.selectModel(123);
      final installer = _FakeInstaller(modelRepository, const ['model-x']);
      final cubit =
          buildCubit(selectedModelCubit: modelCubit, installer: installer);
      addTearDown(cubit.close);
      await _settle();
      await _settle();

      await cubit.resetSeededModels();
      expect(modelCubit.state, isNull);
      expect(cubit.state.selectedModelId, isNull);
      final models = await database.select(database.models).get();
      expect(models, isNotEmpty);
    });
  });

  group('prepareChatEntry', () {
    test('does not silently select a remote model on Android', () async {
      await insertRemoteModel();
      final modelCubit = SelectedModelCubit();
      final cubit = buildCubit(selectedModelCubit: modelCubit);
      addTearDown(cubit.close);
      await _settle();
      await _settle();

      await cubit.prepareChatEntry();
      expect(modelCubit.state, isNull);
      expect(cubit.state.selectedModelId, isNull);
    });
  });
}
