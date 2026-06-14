import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/core/prompt.dart';
import 'package:gena/features/workspace/presentation/cubit/workspace_embedder_install_cubit.dart';
import 'package:gena/features/workspace/data/models/workspace_document_entity.dart';
import 'package:gena/features/workspace/data/models/workspace_document_ingestion_status.dart';
import 'package:gena/features/workspace/data/models/workspace_embedder_install_state.dart';
import 'package:gena/features/workspace/data/models/workspace_entity.dart';
import 'package:gena/features/workspace/data/models/workspace_memory_entity.dart';
import 'package:gena/features/workspace/data/services/workspace_document_parser.dart';
import 'package:gena/features/workspace/data/workspace_memory_repository.dart';
import 'package:gena/features/workspace/presentation/cubit/workspace_config_state.dart';
import 'package:gena/features/workspace/presentation/services/workspace_rag_ingestion_controller.dart';

class WorkspaceConfigValidationException implements Exception {
  const WorkspaceConfigValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WorkspaceConfigCubit extends Cubit<WorkspaceConfigState> {
  WorkspaceConfigCubit({
    required this.workspaceId,
    required db.GenaDatabase database,
    required WorkspaceDocumentParser parser,
    required WorkspaceRagIngestionController ingestionController,
    required WorkspaceEmbedderInstallCubit embedderCubit,
    required WorkspaceMemoryRepository memoryRepository,
    AppCapabilities? capabilities,
  }) : _database = database,
       _parser = parser,
       _ingestionController = ingestionController,
       _embedderCubit = embedderCubit,
       _memoryRepository = memoryRepository,
       _capabilities = capabilities ?? AppCapabilities.current,
       super(WorkspaceConfigState.initial());

  final String workspaceId;
  final db.GenaDatabase _database;
  final WorkspaceDocumentParser _parser;
  final WorkspaceRagIngestionController _ingestionController;
  final WorkspaceEmbedderInstallCubit _embedderCubit;
  final WorkspaceMemoryRepository _memoryRepository;
  final AppCapabilities _capabilities;

  AppCapabilities get capabilities => _capabilities;

  StreamSubscription<db.Workspace?>? _workspaceSubscription;
  StreamSubscription<List<WorkspaceDocumentEntity>>? _documentsSubscription;
  StreamSubscription<List<WorkspaceMemoryEntity>>? _memoriesSubscription;
  StreamSubscription<WorkspaceEmbedderInstallState>? _embedderSubscription;
  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _watchWorkspace();
    _bindEmbedder();
    if (_capabilities.supportsWorkspaceRag) {
      unawaited(_ingestionController.resumePending());
      unawaited(_embedderCubit.refreshStatus());
    }
  }

  void setInstruction(String value) {
    emit(state.copyWith(instruction: value));
  }

  void setRagEnabled(bool value) {
    if (value && !_capabilities.supportsWorkspaceRag) return;
    emit(state.copyWith(ragEnabled: value));
    if (value) {
      unawaited(_embedderCubit.refreshStatus());
    }
  }

  void setNativeToolsEnabled(bool value) {
    emit(state.copyWith(nativeToolsEnabled: value));
  }

  void setNativeOpenUrlEnabled(bool value) {
    emit(state.copyWith(nativeOpenUrlEnabled: value));
  }

  void setNativeOpenAppEnabled(bool value) {
    emit(state.copyWith(nativeOpenAppEnabled: value));
  }

  void setNativeSendEmailEnabled(bool value) {
    emit(state.copyWith(nativeSendEmailEnabled: value));
  }

  void setNativeFlashlightEnabled(bool value) {
    emit(state.copyWith(nativeFlashlightEnabled: value));
  }

  void setMcpEnabled(bool value) {
    if (value && !_capabilities.supportsMcp) return;
    emit(state.copyWith(mcpEnabled: value));
  }

  void setMemoryEnabled(bool value) {
    emit(state.copyWith(memoryEnabled: value));
  }

  Future<void> addMemory(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    final targetWorkspaceId = state.workspace?.id ?? workspaceId;
    if (targetWorkspaceId.trim().isEmpty) return;
    await _memoryRepository.addMemory(targetWorkspaceId, trimmed);
  }

  Future<void> deleteMemory(int memoryId) async {
    await _memoryRepository.deleteMemory(memoryId);
  }

  Future<void> save() async {
    if (state.isSaving) return;
    if (workspaceId.trim().isEmpty) {
      throw const WorkspaceConfigValidationException('No workspace selected');
    }

    emit(state.copyWith(isSaving: true));
    try {
      if (state.ragEnabled && _capabilities.supportsWorkspaceRag) {
        await _embedderCubit.ensureInstalled();
      }

      final parsedId = int.tryParse(workspaceId);
      if (parsedId == null) return;

      await (_database.update(
        _database.workspaces,
      )..where((t) => t.id.equals(parsedId))).write(
        db.WorkspacesCompanion(
          generalInstruction: Value(
            state.instruction.trim().isEmpty
                ? systemPrompt
                : state.instruction.trim(),
          ),
          ragEnabled: Value(
            _capabilities.supportsWorkspaceRag && state.ragEnabled,
          ),
          nativeToolsEnabled: Value(state.nativeToolsEnabled),
          nativeOpenUrlEnabled: Value(state.nativeOpenUrlEnabled),
          nativeOpenAppEnabled: Value(state.nativeOpenAppEnabled),
          nativeSendEmailEnabled: Value(state.nativeSendEmailEnabled),
          nativeFlashlightEnabled: Value(state.nativeFlashlightEnabled),
          mcpEnabled: Value(_capabilities.supportsMcp && state.mcpEnabled),
          memoryEnabled: Value(state.memoryEnabled),
        ),
      );
    } finally {
      emit(state.copyWith(isSaving: false));
    }
  }

  Future<void> ensureEmbedderInstalled() {
    if (!_capabilities.supportsWorkspaceRag) {
      throw WorkspaceConfigValidationException(
        _capabilities.workspaceRagUnavailableMessage,
      );
    }
    return _embedderCubit.ensureInstalled();
  }

  Future<void> importDocument(String rawPath) async {
    if (!_capabilities.supportsWorkspaceRag) {
      throw WorkspaceConfigValidationException(
        _capabilities.workspaceRagUnavailableMessage,
      );
    }
    if (state.isImporting) return;
    final targetWorkspaceId = state.workspace?.id ?? workspaceId;
    if (targetWorkspaceId.trim().isEmpty) return;
    final parsedWorkspaceId = int.tryParse(targetWorkspaceId);
    if (parsedWorkspaceId == null) return;

    emit(state.copyWith(isImporting: true));
    try {
      final prepared = await _parser.prepareSource(
        workspaceId: targetWorkspaceId,
        rawPath: rawPath,
      );

      final insertedId = await _database
          .into(_database.workspaceDocuments)
          .insert(
            db.WorkspaceDocumentsCompanion.insert(
              workspace: parsedWorkspaceId,
              name: prepared.name,
              sourceType: prepared.sourceType,
              sourcePath: prepared.sourcePath,
              content: '',
              ingestionStatus: Value(
                WorkspaceDocumentIngestionStatus.queued.value,
              ),
              ingestionError: const Value(null),
              chunkCount: const Value(0),
            ),
          );

      await _ingestionController.enqueue(insertedId);
    } finally {
      emit(state.copyWith(isImporting: false));
    }
  }

  Future<void> deleteDocument(int documentId) {
    return _ingestionController.deleteDocument(documentId);
  }

  Future<void> retryDocumentIngestion(int documentId) {
    if (!_capabilities.supportsWorkspaceRag) {
      throw WorkspaceConfigValidationException(
        _capabilities.workspaceRagUnavailableMessage,
      );
    }
    return _ingestionController.retryDocumentIngestion(documentId);
  }

  void _watchWorkspace() {
    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) {
      emit(state.copyWith(workspaceLoading: false, clearWorkspace: true));
      return;
    }

    _workspaceSubscription =
        (_database.select(_database.workspaces)
              ..where((t) => t.id.equals(parsedWorkspaceId))
              ..limit(1))
            .watchSingleOrNull()
            .listen((row) {
              if (row == null) {
                emit(
                  state.copyWith(
                    workspaceLoading: false,
                    clearWorkspace: true,
                    clearHydratedWorkspaceId: true,
                  ),
                );
                return;
              }

              final workspace = WorkspaceEntity(
                id: row.id.toString(),
                name: row.name,
                generalInstruction: row.generalInstruction,
                ragEnabled: row.ragEnabled,
                nativeToolsEnabled: row.nativeToolsEnabled,
                nativeOpenUrlEnabled: row.nativeOpenUrlEnabled,
                nativeOpenAppEnabled: row.nativeOpenAppEnabled,
                nativeSendEmailEnabled: row.nativeSendEmailEnabled,
                nativeFlashlightEnabled: row.nativeFlashlightEnabled,
                mcpEnabled: row.mcpEnabled,
                memoryEnabled: row.memoryEnabled,
                createdAt: row.createdAt,
              );

              _hydrateFromWorkspace(workspace);
              _watchDocuments(row.id);
              _watchMemories(workspace.id);
            });
  }

  void _hydrateFromWorkspace(WorkspaceEntity workspace) {
    final shouldHydrate = state.hydratedWorkspaceId != workspace.id;
    emit(
      state.copyWith(
        workspaceLoading: false,
        workspace: workspace,
        hydratedWorkspaceId: workspace.id,
        instruction: shouldHydrate
            ? workspace.generalInstruction
            : state.instruction,
        ragEnabled: _capabilities.supportsWorkspaceRag
            ? (shouldHydrate ? workspace.ragEnabled : state.ragEnabled)
            : false,
        nativeToolsEnabled: shouldHydrate
            ? workspace.nativeToolsEnabled
            : state.nativeToolsEnabled,
        nativeOpenUrlEnabled: shouldHydrate
            ? workspace.nativeOpenUrlEnabled
            : state.nativeOpenUrlEnabled,
        nativeOpenAppEnabled: shouldHydrate
            ? workspace.nativeOpenAppEnabled
            : state.nativeOpenAppEnabled,
        nativeSendEmailEnabled: shouldHydrate
            ? workspace.nativeSendEmailEnabled
            : state.nativeSendEmailEnabled,
        nativeFlashlightEnabled: shouldHydrate
            ? workspace.nativeFlashlightEnabled
            : state.nativeFlashlightEnabled,
        mcpEnabled: _capabilities.supportsMcp
            ? (shouldHydrate ? workspace.mcpEnabled : state.mcpEnabled)
            : false,
        memoryEnabled: shouldHydrate
            ? workspace.memoryEnabled
            : state.memoryEnabled,
      ),
    );
  }

  void _watchMemories(String workspaceId) {
    _memoriesSubscription?.cancel();
    _memoriesSubscription = _memoryRepository.watchMemories(workspaceId).listen(
      (memories) {
        emit(state.copyWith(memories: memories));
      },
    );
  }

  void _watchDocuments(int parsedWorkspaceId) {
    _documentsSubscription?.cancel();
    emit(state.copyWith(documents: null));
    _documentsSubscription =
        (_database.select(_database.workspaceDocuments)
              ..where((t) => t.workspace.equals(parsedWorkspaceId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .watch()
            .map(
              (rows) => rows
                  .map(
                    (row) => WorkspaceDocumentEntity(
                      id: row.id,
                      workspaceId: row.workspace.toString(),
                      name: row.name,
                      sourceType: row.sourceType,
                      sourcePath: row.sourcePath,
                      content: row.content,
                      ingestionStatus: WorkspaceDocumentIngestionStatus.fromDb(
                        row.ingestionStatus,
                      ),
                      ingestionError: row.ingestionError,
                      chunkCount: row.chunkCount,
                      createdAt: row.createdAt,
                    ),
                  )
                  .toList(growable: false),
            )
            .listen((docs) {
              emit(state.copyWith(documents: docs));
            });
  }

  void _bindEmbedder() {
    emit(state.copyWith(embedderState: _embedderCubit.state));
    _embedderSubscription = _embedderCubit.stream.listen((embedderState) {
      emit(state.copyWith(embedderState: embedderState));
    });
  }

  @override
  Future<void> close() async {
    await _workspaceSubscription?.cancel();
    await _documentsSubscription?.cancel();
    await _memoriesSubscription?.cancel();
    await _embedderSubscription?.cancel();
    return super.close();
  }
}
