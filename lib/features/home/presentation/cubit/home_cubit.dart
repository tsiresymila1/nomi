import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/logger.dart';
import 'package:gena/core/prompt.dart';
import 'package:gena/features/chat/data/models/chat_entity.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/home/presentation/cubit/home_state.dart';
import 'package:gena/features/workspace/data/models/workspace_chat_group.dart';
import 'package:gena/features/workspace/data/models/workspace_entity.dart';
import 'package:gena/features/workspace/data/services/workspace_embedder_installer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required db.GenaDatabase database,
    required ModelRepository modelRepository,
    required ModelInstallerService modelInstallerService,
    required ModelRepositoryActions modelRepositoryActions,
    required DefaultModelSeeder defaultModelSeeder,
    required WorkspaceEmbedderInstaller workspaceEmbedderInstaller,
  }) : _database = database,
       _modelRepository = modelRepository,
       _modelInstallerService = modelInstallerService,
       _modelRepositoryActions = modelRepositoryActions,
       _defaultModelSeeder = defaultModelSeeder,
       _workspaceEmbedderInstaller = workspaceEmbedderInstaller,
       super(const HomeState()) {
    _init();
  }

  static const selectedModelPrefsKey = 'chat_selected_model_id';

  final db.GenaDatabase _database;
  final ModelRepository _modelRepository;
  final ModelInstallerService _modelInstallerService;
  final ModelRepositoryActions _modelRepositoryActions;
  final DefaultModelSeeder _defaultModelSeeder;
  final WorkspaceEmbedderInstaller _workspaceEmbedderInstaller;

  StreamSubscription<List<WorkspaceChatGroup>>? _workspaceGroupsSubscription;
  StreamSubscription<List<ModelInfo>>? _modelsSubscription;

  Future<void> _init() async {
    try {
      await _defaultModelSeeder.ensureSeeded();
      final prefs = await SharedPreferences.getInstance();
      final selectedModelId = prefs.getInt(selectedModelPrefsKey);
      emit(state.copyWith(selectedModelId: selectedModelId));

      _modelsSubscription = _modelRepository.watchModels().listen((models) {
        emit(state.copyWith(models: models, loading: false, clearError: true));
      });

      _workspaceGroupsSubscription = _watchWorkspaceChatGroups().listen((
        groups,
      ) {
        emit(state.copyWith(groups: groups, loading: false, clearError: true));
      });

      final installed = await _modelInstallerService.listInstalledModels();
      emit(
        state.copyWith(
          installedModels: installed,
          loading: false,
          embedderStatus: await _resolveEmbedderStatus(),
        ),
      );
    } catch (error, stackTrace) {
      logger.e(error, error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          loading: false,
          errorMessage: 'Failed to load home data: $error',
        ),
      );
    }
  }

  Future<void> setSelectedModel(int? modelId) async {
    final prefs = await SharedPreferences.getInstance();
    if (modelId == null) {
      await prefs.remove(selectedModelPrefsKey);
      emit(state.copyWith(clearSelectedModel: true));
      return;
    }
    await prefs.setInt(selectedModelPrefsKey, modelId);
    emit(state.copyWith(selectedModelId: modelId));
  }

  void setSelectedEmbedderModel(String model) {
    emit(state.copyWith(selectedEmbedderModel: model));
  }

  Future<void> installOrCheckEmbedder() async {
    emit(
      state.copyWith(
        embedderStatus: 'Checking embedding model...',
        clearError: true,
      ),
    );
    try {
      await _workspaceEmbedderInstaller.ensureInstalled(
        onStatus: ({required message, modelProgress, tokenizerProgress}) {
          emit(state.copyWith(embedderStatus: message));
        },
      );
      emit(state.copyWith(embedderStatus: 'Embedding model is ready'));
    } catch (error, stackTrace) {
      logger.e(error, error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          embedderStatus: 'Embedding model install failed',
          errorMessage: '$error',
        ),
      );
      rethrow;
    }
  }

  Future<void> resetSeededModels() async {
    await _modelRepositoryActions.clearAndReseedDefaultModels();
    await setSelectedModel(null);
    final installed = await _modelInstallerService.listInstalledModels();
    emit(state.copyWith(installedModels: installed, clearError: true));
  }

  Future<String> createWorkspace(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      throw const FormatException('Workspace name is required');
    }
    final id = await _database
        .into(_database.workspaces)
        .insert(
          db.WorkspacesCompanion.insert(
            name: name,
            generalInstruction: const Value(systemPrompt),
            nativeToolsEnabled: const Value(true),
            nativeOpenUrlEnabled: const Value(true),
            nativeOpenAppEnabled: const Value(true),
            nativeSendEmailEnabled: const Value(true),
            nativeFlashlightEnabled: const Value(true),
          ),
        );

    final chatId = await _database
        .into(_database.chats)
        .insert(db.ChatsCompanion.insert(title: 'New chat', workspace: id));
    return '$id:$chatId';
  }

  Future<String> ensureWorkspaceChatSelection(String workspaceId) async {
    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) {
      throw StateError('Invalid workspace id: $workspaceId');
    }
    final firstChat =
        await (_database.select(_database.chats)
              ..where((t) => t.workspace.equals(parsedWorkspaceId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (firstChat != null) return firstChat.id.toString();
    final createdId = await _database
        .into(_database.chats)
        .insert(
          db.ChatsCompanion.insert(
            title: 'New chat',
            workspace: parsedWorkspaceId,
          ),
        );
    return createdId.toString();
  }

  Stream<List<WorkspaceChatGroup>> _watchWorkspaceChatGroups() {
    final joinQuery =
        _database.select(_database.workspaces).join([
          leftOuterJoin(
            _database.chats,
            _database.chats.workspace.equalsExp(_database.workspaces.id),
          ),
        ])..orderBy([
          OrderingTerm.asc(_database.workspaces.createdAt),
          OrderingTerm.desc(_database.chats.createdAt),
        ]);

    return joinQuery.watch().map((rows) {
      final grouped = <int, WorkspaceChatGroup>{};

      for (final row in rows) {
        final workspaceRow = row.readTable(_database.workspaces);
        final workspaceId = workspaceRow.id;
        final workspace = WorkspaceEntity(
          id: workspaceRow.id.toString(),
          name: workspaceRow.name,
          generalInstruction: workspaceRow.generalInstruction,
          ragEnabled: workspaceRow.ragEnabled,
          nativeToolsEnabled: workspaceRow.nativeToolsEnabled,
          nativeOpenUrlEnabled: workspaceRow.nativeOpenUrlEnabled,
          nativeOpenAppEnabled: workspaceRow.nativeOpenAppEnabled,
          nativeSendEmailEnabled: workspaceRow.nativeSendEmailEnabled,
          nativeFlashlightEnabled: workspaceRow.nativeFlashlightEnabled,
          createdAt: workspaceRow.createdAt,
        );
        grouped.putIfAbsent(
          workspaceId,
          () => WorkspaceChatGroup(workspace: workspace, chats: <ChatEntity>[]),
        );

        final chatRow = row.readTableOrNull(_database.chats);
        if (chatRow == null) continue;
        grouped[workspaceId]!.chats.add(
          ChatEntity(
            id: chatRow.id.toString(),
            workspaceId: chatRow.workspace.toString(),
            title: chatRow.title,
            createdAt: chatRow.createdAt,
            updatedAt: chatRow.createdAt,
          ),
        );
      }

      return grouped.values.toList(growable: false);
    });
  }

  Future<String> _resolveEmbedderStatus() async {
    try {
      if (FlutterGemma.hasActiveEmbedder()) {
        await FlutterGemma.getActiveEmbedder();
        return 'Embedding model is ready';
      }
      return 'Embedding model is not installed yet';
    } catch (_) {
      return 'Embedder status unknown';
    }
  }

  @override
  Future<void> close() async {
    await _workspaceGroupsSubscription?.cancel();
    await _modelsSubscription?.cancel();
    return super.close();
  }
}
