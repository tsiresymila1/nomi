import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/features/chat/data/models/llamadart_tts_model_profile.dart';
import 'package:gena/features/chat/data/services/llamadart_tts_model_store.dart';
import 'package:gena/features/chat/data/services/local_neural_text_to_speech.dart';

enum LlamaDartTtsModelPhase {
  idle,
  checking,
  downloading,
  verifying,
  loading,
  ready,
  cancelled,
  failed,
}

class LlamaDartTtsModelState {
  const LlamaDartTtsModelState({
    this.phase = LlamaDartTtsModelPhase.idle,
    this.progress = 0,
    this.message,
  });

  final LlamaDartTtsModelPhase phase;
  final double progress;
  final String? message;

  bool get installed =>
      phase == LlamaDartTtsModelPhase.loading ||
      phase == LlamaDartTtsModelPhase.ready;
  bool get isBusy =>
      phase == LlamaDartTtsModelPhase.checking ||
      phase == LlamaDartTtsModelPhase.downloading ||
      phase == LlamaDartTtsModelPhase.verifying ||
      phase == LlamaDartTtsModelPhase.loading;
}

class LlamaDartTtsModelCubit extends Cubit<LlamaDartTtsModelState> {
  LlamaDartTtsModelCubit({
    required LlamaDartTtsModelStore store,
    required LocalNeuralTextToSpeech textToSpeech,
  }) : _store = store,
       _textToSpeech = textToSpeech,
       super(const LlamaDartTtsModelState());

  final LlamaDartTtsModelStore _store;
  final LocalNeuralTextToSpeech _textToSpeech;
  int _operationSerial = 0;

  Future<void> initialize() async {
    if (state.isBusy) return;
    final operation = ++_operationSerial;
    emit(
      const LlamaDartTtsModelState(
        phase: LlamaDartTtsModelPhase.checking,
        message: 'Checking local neural voice…',
      ),
    );
    try {
      final installed = await _store.resolve(qwen3Tts17bQ4);
      if (operation != _operationSerial) return;
      emit(
        LlamaDartTtsModelState(
          phase: installed == null
              ? LlamaDartTtsModelPhase.idle
              : LlamaDartTtsModelPhase.ready,
          progress: installed == null ? 0 : 1,
          message: installed == null
              ? 'Model not installed'
              : 'Model installed',
        ),
      );
    } catch (error) {
      if (operation != _operationSerial) return;
      emit(
        LlamaDartTtsModelState(
          phase: LlamaDartTtsModelPhase.failed,
          message: '$error',
        ),
      );
    }
  }

  Future<void> install() async {
    if (state.isBusy) return;
    final operation = ++_operationSerial;
    emit(
      const LlamaDartTtsModelState(
        phase: LlamaDartTtsModelPhase.downloading,
        message: 'Preparing neural voice download…',
      ),
    );
    try {
      await _store.install(
        qwen3Tts17bQ4,
        onProgress: (progress, message) {
          if (operation != _operationSerial) return;
          emit(
            LlamaDartTtsModelState(
              phase: LlamaDartTtsModelPhase.downloading,
              progress: progress,
              message: message,
            ),
          );
        },
        onVerifying: (message) {
          if (operation != _operationSerial) return;
          emit(
            LlamaDartTtsModelState(
              phase: LlamaDartTtsModelPhase.verifying,
              progress: state.progress,
              message: message,
            ),
          );
        },
      );
      if (operation != _operationSerial) return;
      await _activate(operation);
    } catch (error) {
      if (operation != _operationSerial) return;
      emit(
        LlamaDartTtsModelState(
          phase: LlamaDartTtsModelPhase.failed,
          progress: state.progress,
          message: '$error',
        ),
      );
    }
  }

  Future<void> activate() async {
    if (state.phase == LlamaDartTtsModelPhase.loading) return;
    final operation = ++_operationSerial;
    await _activate(operation);
  }

  Future<void> _activate(int operation) async {
    final installed = await _store.resolve(qwen3Tts17bQ4);
    if (operation != _operationSerial) return;
    if (installed == null) {
      emit(
        const LlamaDartTtsModelState(
          message: 'Install the model before activating Local AI voice.',
        ),
      );
      return;
    }
    emit(
      const LlamaDartTtsModelState(
        phase: LlamaDartTtsModelPhase.loading,
        progress: 1,
        message: 'Loading neural voice…',
      ),
    );
    try {
      await _textToSpeech.prepare();
      if (operation != _operationSerial) return;
      emit(
        const LlamaDartTtsModelState(
          phase: LlamaDartTtsModelPhase.ready,
          progress: 1,
          message: 'Neural voice ready',
        ),
      );
    } catch (error) {
      if (operation != _operationSerial) return;
      emit(
        LlamaDartTtsModelState(
          phase: LlamaDartTtsModelPhase.failed,
          progress: 1,
          message: '$error',
        ),
      );
    }
  }

  Future<void> cancel() async {
    ++_operationSerial;
    await _store.cancelInstall(qwen3Tts17bQ4);
    emit(
      const LlamaDartTtsModelState(
        phase: LlamaDartTtsModelPhase.cancelled,
        message: 'Download cancelled',
      ),
    );
  }

  Future<void> deactivate() async {
    final operation = ++_operationSerial;
    await _textToSpeech.unload();
    final installed = await _store.resolve(qwen3Tts17bQ4);
    if (operation != _operationSerial) return;
    emit(
      LlamaDartTtsModelState(
        phase: installed == null
            ? LlamaDartTtsModelPhase.idle
            : LlamaDartTtsModelPhase.ready,
        progress: installed == null ? 0 : 1,
        message: installed == null ? 'Model not installed' : 'Model installed',
      ),
    );
  }

  Future<void> remove() async {
    final operation = ++_operationSerial;
    await _textToSpeech.unload();
    await _store.delete(qwen3Tts17bQ4);
    if (operation != _operationSerial) return;
    emit(const LlamaDartTtsModelState(message: 'Local neural voice removed'));
  }
}
