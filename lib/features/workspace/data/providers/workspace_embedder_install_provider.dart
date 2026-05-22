import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:gena/features/workspace/data/models/workspace_embedder_install_state.dart';
import 'package:gena/features/workspace/data/services/workspace_embedder_installer.dart';

final workspaceEmbedderInstallerProvider = Provider<WorkspaceEmbedderInstaller>(
  (ref) => WorkspaceEmbedderInstaller(),
);

final workspaceEmbedderInstallStateProvider =
    NotifierProvider<
      WorkspaceEmbedderInstallNotifier,
      WorkspaceEmbedderInstallState
    >(WorkspaceEmbedderInstallNotifier.new);

class WorkspaceEmbedderInstallNotifier
    extends Notifier<WorkspaceEmbedderInstallState> {
  @override
  WorkspaceEmbedderInstallState build() =>
      const WorkspaceEmbedderInstallState.idle();

  Future<void> ensureInstalled() async {
    if (state.phase == WorkspaceEmbedderInstallPhase.downloading ||
        state.phase == WorkspaceEmbedderInstallPhase.checking) {
      return;
    }

    state = state.copyWith(
      phase: WorkspaceEmbedderInstallPhase.checking,
      message: 'Checking embedding model...',
      clearError: true,
    );

    final installer = ref.read(workspaceEmbedderInstallerProvider);
    try {
      await installer.ensureInstalled(
        onStatus: ({required message, modelProgress, tokenizerProgress}) {
          state = state.copyWith(
            phase: WorkspaceEmbedderInstallPhase.downloading,
            message: message,
            modelProgress: modelProgress,
            tokenizerProgress: tokenizerProgress,
            clearError: true,
          );
        },
      );
      state = state.copyWith(
        phase: WorkspaceEmbedderInstallPhase.ready,
        message: 'Embedding model is ready',
        modelProgress: 100,
        tokenizerProgress: 100,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        phase: WorkspaceEmbedderInstallPhase.failed,
        message: 'Embedding model install failed',
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> refreshStatus() async {
    state = state.copyWith(
      phase: WorkspaceEmbedderInstallPhase.checking,
      message: 'Checking embedding model...',
      clearError: true,
    );

    try {
      if (FlutterGemma.hasActiveEmbedder()) {
        await FlutterGemma.getActiveEmbedder();
        state = state.copyWith(
          phase: WorkspaceEmbedderInstallPhase.ready,
          message: 'Embedding model is ready',
          modelProgress: 100,
          tokenizerProgress: 100,
          clearError: true,
        );
        return;
      }

      state = state.copyWith(
        phase: WorkspaceEmbedderInstallPhase.idle,
        message: 'Embedding model is not installed yet',
        modelProgress: 0,
        tokenizerProgress: 0,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        phase: WorkspaceEmbedderInstallPhase.failed,
        message: 'Failed to check embedding model',
        error: e.toString(),
      );
    }
  }
}
