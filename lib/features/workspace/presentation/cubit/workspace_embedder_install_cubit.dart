import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:gena/features/workspace/data/models/workspace_embedder_install_state.dart';
import 'package:gena/features/workspace/data/services/workspace_embedder_installer.dart';

class WorkspaceEmbedderInstallCubit
    extends Cubit<WorkspaceEmbedderInstallState> {
  WorkspaceEmbedderInstallCubit(this._installer)
    : super(const WorkspaceEmbedderInstallState.idle());

  final WorkspaceEmbedderInstaller _installer;

  Future<void> ensureInstalled() async {
    if (state.phase == WorkspaceEmbedderInstallPhase.downloading ||
        state.phase == WorkspaceEmbedderInstallPhase.checking) {
      return;
    }

    emit(
      state.copyWith(
        phase: WorkspaceEmbedderInstallPhase.checking,
        message: 'Checking embedding model...',
        clearError: true,
      ),
    );

    try {
      await _installer.ensureInstalled(
        onStatus: ({required message, modelProgress, tokenizerProgress}) {
          emit(
            state.copyWith(
              phase: WorkspaceEmbedderInstallPhase.downloading,
              message: message,
              modelProgress: modelProgress,
              tokenizerProgress: tokenizerProgress,
              clearError: true,
            ),
          );
        },
      );
      emit(
        state.copyWith(
          phase: WorkspaceEmbedderInstallPhase.ready,
          message: 'Embedding model is ready',
          modelProgress: 100,
          tokenizerProgress: 100,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          phase: WorkspaceEmbedderInstallPhase.failed,
          message: 'Embedding model install failed',
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
        message: 'Checking embedding model...',
        clearError: true,
      ),
    );

    try {
      if (FlutterGemma.hasActiveEmbedder()) {
        await FlutterGemma.getActiveEmbedder();
        emit(
          state.copyWith(
            phase: WorkspaceEmbedderInstallPhase.ready,
            message: 'Embedding model is ready',
            modelProgress: 100,
            tokenizerProgress: 100,
            clearError: true,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          phase: WorkspaceEmbedderInstallPhase.idle,
          message: 'Embedding model is not installed yet',
          modelProgress: 0,
          tokenizerProgress: 0,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          phase: WorkspaceEmbedderInstallPhase.failed,
          message: 'Failed to check embedding model',
          error: error.toString(),
        ),
      );
    }
  }
}
