import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/data/services/image_generation_actions.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_model_selection_cubit.dart';

enum ImageGenerationUiPhase {
  initial,
  checking,
  needsInstall,
  downloading,
  verifying,
  ready,
  loadingModel,
  generating,
  completed,
  cancelled,
  removing,
  unsupported,
  failed,
}

class ImageGenerationState {
  const ImageGenerationState({
    this.phase = ImageGenerationUiPhase.initial,
    this.support,
    this.isInstalled = false,
    this.downloadProgress = 0,
    this.progress,
    this.artifact,
    this.errorMessage,
    this.profile = ImageModelProfile.sdxs,
    this.activePrompt,
    this.activeChatId,
  });

  final ImageGenerationUiPhase phase;
  final ImageRuntimeSupport? support;
  final bool isInstalled;
  final double downloadProgress;
  final LocalImageGenerationProgress? progress;
  final GeneratedImageArtifact? artifact;
  final String? errorMessage;
  final ImageModelProfile profile;
  final String? activePrompt;
  final String? activeChatId;

  bool get isBusy => switch (phase) {
    ImageGenerationUiPhase.checking ||
    ImageGenerationUiPhase.downloading ||
    ImageGenerationUiPhase.verifying ||
    ImageGenerationUiPhase.loadingModel ||
    ImageGenerationUiPhase.generating ||
    ImageGenerationUiPhase.removing => true,
    _ => false,
  };

  ImageGenerationState copyWith({
    ImageGenerationUiPhase? phase,
    ImageRuntimeSupport? support,
    bool? isInstalled,
    double? downloadProgress,
    LocalImageGenerationProgress? progress,
    GeneratedImageArtifact? artifact,
    String? errorMessage,
    bool clearProgress = false,
    bool clearArtifact = false,
    bool clearError = false,
    ImageModelProfile? profile,
    String? activePrompt,
    String? activeChatId,
    bool updateActiveTurn = false,
  }) => ImageGenerationState(
    phase: phase ?? this.phase,
    support: support ?? this.support,
    isInstalled: isInstalled ?? this.isInstalled,
    downloadProgress: downloadProgress ?? this.downloadProgress,
    progress: clearProgress ? null : progress ?? this.progress,
    artifact: clearArtifact ? null : artifact ?? this.artifact,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    profile: profile ?? this.profile,
    activePrompt: updateActiveTurn ? activePrompt : this.activePrompt,
    activeChatId: updateActiveTurn ? activeChatId : this.activeChatId,
  );
}

class ImageGenerationCubit extends Cubit<ImageGenerationState> {
  ImageGenerationCubit(
    this._actions, {
    required ImageModelSelectionCubit selection,
  }) : _selection = selection,
       super(ImageGenerationState(profile: selection.state.selectedProfile));

  final ImageGenerationActionsApi _actions;
  final ImageModelSelectionCubit _selection;

  Future<void> initialize() async {
    if (state.phase == ImageGenerationUiPhase.checking) return;
    emit(
      state.copyWith(
        phase: ImageGenerationUiPhase.checking,
        profile: _selection.state.selectedProfile,
        clearError: true,
        activePrompt: null,
        activeChatId: null,
        updateActiveTurn: true,
      ),
    );
    try {
      final support = await _actions.checkSupport();
      if (!support.isSupported) {
        emit(
          state.copyWith(
            phase: ImageGenerationUiPhase.unsupported,
            support: support,
            errorMessage:
                support.unsupportedReason ?? 'Image generation is unavailable.',
          ),
        );
        return;
      }
      final installed = await _actions.resolveModel();
      if (installed != null) {
        emit(
          state.copyWith(
            phase: ImageGenerationUiPhase.loadingModel,
            support: support,
            isInstalled: true,
            downloadProgress: 1,
            clearError: true,
          ),
        );
        await _actions.prepareModel();
      }
      emit(
        state.copyWith(
          phase: installed == null
              ? ImageGenerationUiPhase.needsInstall
              : ImageGenerationUiPhase.ready,
          support: support,
          isInstalled: installed != null,
          downloadProgress: installed == null ? 0 : 1,
          clearError: true,
        ),
      );
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> installModel() async {
    if (state.isBusy || state.phase == ImageGenerationUiPhase.unsupported) {
      return;
    }
    emit(
      state.copyWith(
        phase: ImageGenerationUiPhase.downloading,
        downloadProgress: 0,
        clearError: true,
      ),
    );
    try {
      await _actions.installModel(
        onProgress: (progress) {
          if (isClosed) return;
          emit(
            state.copyWith(
              phase: ImageGenerationUiPhase.downloading,
              downloadProgress: progress.clamp(0, 1),
            ),
          );
        },
        onVerifying: () {
          if (isClosed) return;
          emit(state.copyWith(phase: ImageGenerationUiPhase.verifying));
        },
      );
      emit(
        state.copyWith(
          phase: ImageGenerationUiPhase.loadingModel,
          isInstalled: true,
          downloadProgress: 1,
          clearError: true,
        ),
      );
      await _actions.prepareModel();
      emit(
        state.copyWith(
          phase: ImageGenerationUiPhase.ready,
          isInstalled: true,
          downloadProgress: 1,
          clearError: true,
        ),
      );
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> cancelInstall() async {
    await _actions.cancelInstall();
    if (!isClosed) {
      emit(
        state.copyWith(
          phase: ImageGenerationUiPhase.needsInstall,
          downloadProgress: 0,
        ),
      );
    }
  }

  Future<GeneratedImageArtifact?> generate(
    String prompt, {
    int? seed,
    String? chatId,
  }) {
    final normalized = prompt.trim();
    if (normalized.isEmpty || !state.isInstalled || state.isBusy) {
      return Future.value();
    }
    return _generateTurn(
      normalized,
      seed: seed,
      chatId: chatId,
      persistPrompt: true,
    );
  }

  Future<GeneratedImageArtifact?> retryGeneration() {
    final prompt = state.activePrompt;
    final canRetry =
        state.phase == ImageGenerationUiPhase.failed ||
        state.phase == ImageGenerationUiPhase.cancelled;
    if (!canRetry || prompt == null || prompt.isEmpty || !state.isInstalled) {
      return Future.value();
    }
    return _generateTurn(
      prompt,
      chatId: state.activeChatId,
      persistPrompt: false,
    );
  }

  Future<GeneratedImageArtifact?> _generateTurn(
    String prompt, {
    int? seed,
    required String? chatId,
    required bool persistPrompt,
  }) async {
    emit(
      state.copyWith(
        phase: ImageGenerationUiPhase.generating,
        clearProgress: true,
        clearArtifact: true,
        clearError: true,
        activePrompt: prompt,
        activeChatId: chatId,
        updateActiveTurn: true,
      ),
    );
    try {
      final artifact = await _actions.generateAndPersist(
        prompt: prompt,
        seed: seed,
        persistPrompt: persistPrompt,
        onProgress: (progress) {
          if (isClosed) return;
          emit(
            state.copyWith(
              phase: ImageGenerationUiPhase.generating,
              progress: progress,
            ),
          );
        },
      );
      emit(
        state.copyWith(
          phase: ImageGenerationUiPhase.completed,
          artifact: artifact,
          clearError: true,
        ),
      );
      return artifact;
    } on ImageGenerationCancelledException {
      emit(state.copyWith(phase: ImageGenerationUiPhase.cancelled));
      return null;
    } catch (error) {
      _fail(error);
      return null;
    }
  }

  void cancelGeneration() => _actions.cancelGeneration();

  Future<void> refreshForSelectedModel() async {
    _actions.cancelGeneration();
    await _actions.releaseEngine();
    if (isClosed) return;
    emit(ImageGenerationState(profile: _selection.state.selectedProfile));
    await initialize();
  }

  Future<void> removeModel() async {
    if (state.isBusy) return;
    emit(state.copyWith(phase: ImageGenerationUiPhase.removing));
    try {
      await _actions.removeModel();
      emit(
        state.copyWith(
          phase: ImageGenerationUiPhase.needsInstall,
          isInstalled: false,
          downloadProgress: 0,
          clearArtifact: true,
          clearProgress: true,
          clearError: true,
        ),
      );
    } catch (error) {
      _fail(error);
    }
  }

  void _fail(Object error) {
    if (isClosed) return;
    emit(
      state.copyWith(
        phase: ImageGenerationUiPhase.failed,
        errorMessage: error.toString(),
      ),
    );
  }
}
