import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/features/workspace/data/models/workspace_embedder_install_state.dart';
import 'package:gena/features/workspace/data/services/workspace_rag_vector_store.dart';

/// Tracks workspace RAG engine readiness.
///
/// Replaces the former local embedder install flow. The embedding model
/// is now bundled with the app and provisioned by `mobile_rag_engine`, so there
/// is nothing to download — this cubit only reports whether the engine
/// initialized successfully.
class WorkspaceEmbedderInstallCubit
    extends Cubit<WorkspaceEmbedderInstallState> {
  WorkspaceEmbedderInstallCubit(this._vectorStore)
    : super(const WorkspaceEmbedderInstallState.idle());

  final WorkspaceRagVectorStore _vectorStore;

  Future<void> ensureInstalled() async {
    if (state.phase == WorkspaceEmbedderInstallPhase.checking) {
      return;
    }

    emit(
      state.copyWith(
        phase: WorkspaceEmbedderInstallPhase.checking,
        message: 'Preparing workspace RAG engine...',
        clearError: true,
      ),
    );

    try {
      await _vectorStore.ensureReady();
      emit(
        state.copyWith(
          phase: WorkspaceEmbedderInstallPhase.ready,
          message: 'Workspace RAG engine is ready',
          modelProgress: 100,
          tokenizerProgress: 100,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          phase: WorkspaceEmbedderInstallPhase.failed,
          message: 'Workspace RAG engine failed to initialize',
          error: error.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> refreshStatus() async {
    emit(
      state.copyWith(
        phase: WorkspaceEmbedderInstallPhase.checking,
        message: 'Checking workspace RAG engine...',
        clearError: true,
      ),
    );

    try {
      await _vectorStore.ensureReady();
      emit(
        state.copyWith(
          phase: WorkspaceEmbedderInstallPhase.ready,
          message: 'Workspace RAG engine is ready',
          modelProgress: 100,
          tokenizerProgress: 100,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          phase: WorkspaceEmbedderInstallPhase.idle,
          message: 'Workspace RAG engine is not ready yet',
          modelProgress: 0,
          tokenizerProgress: 0,
          error: error.toString(),
        ),
      );
    }
  }
}
