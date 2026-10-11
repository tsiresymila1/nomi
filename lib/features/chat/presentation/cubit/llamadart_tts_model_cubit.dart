import 'package:gena/features/chat/data/models/llamadart_tts_model_profile.dart';
import 'package:gena/features/chat/data/services/llamadart_tts_model_store.dart';
import 'package:gena/features/chat/data/services/local_neural_text_to_speech.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

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
    this.profile = qwen3Tts17bQ4,
    this.customProfiles = const <LlamaDartTtsModelProfile>[],
    this.phase = LlamaDartTtsModelPhase.idle,
    this.progress = 0,
    this.message,
  });

  final LlamaDartTtsModelProfile profile;
  final List<LlamaDartTtsModelProfile> customProfiles;
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

  List<LlamaDartTtsModelProfile> get allProfiles => <LlamaDartTtsModelProfile>[
    qwen3Tts17bQ4,
    ...customProfiles,
  ];

  LlamaDartTtsModelState copyWith({
    LlamaDartTtsModelProfile? profile,
    List<LlamaDartTtsModelProfile>? customProfiles,
    LlamaDartTtsModelPhase? phase,
    double? progress,
    String? message,
    bool clearMessage = false,
  }) {
    return LlamaDartTtsModelState(
      profile: profile ?? this.profile,
      customProfiles: customProfiles ?? this.customProfiles,
      phase: phase ?? this.phase,
      progress: (progress ?? this.progress).clamp(0, 1),
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

class LlamaDartTtsModelCubit extends HydratedCubit<LlamaDartTtsModelState> {
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
      state.copyWith(
        phase: LlamaDartTtsModelPhase.checking,
        progress: 0,
        message: 'Checking ${state.profile.name}…',
      ),
    );
    try {
      final installed = await _store.resolve(state.profile);
      if (operation != _operationSerial) return;
      emit(
        state.copyWith(
          phase: installed == null
              ? LlamaDartTtsModelPhase.idle
              : LlamaDartTtsModelPhase.ready,
          progress: installed == null ? 0 : 1,
          message: installed == null
              ? state.profile.isExternal
                    ? 'External model files are unavailable'
                    : 'Model not installed'
              : 'Model installed',
        ),
      );
    } catch (error) {
      if (operation != _operationSerial) return;
      emit(
        state.copyWith(phase: LlamaDartTtsModelPhase.failed, message: '$error'),
      );
    }
  }

  Future<void> install() async {
    if (state.isBusy) return;
    final operation = ++_operationSerial;
    emit(
      state.copyWith(
        phase: LlamaDartTtsModelPhase.downloading,
        progress: 0,
        message: 'Preparing neural voice download…',
      ),
    );
    try {
      await _store.install(
        state.profile,
        onProgress: (progress, message) {
          if (operation != _operationSerial) return;
          emit(
            state.copyWith(
              phase: LlamaDartTtsModelPhase.downloading,
              progress: progress,
              message: message,
            ),
          );
        },
        onVerifying: (message) {
          if (operation != _operationSerial) return;
          emit(
            state.copyWith(
              phase: LlamaDartTtsModelPhase.verifying,
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
        state.copyWith(phase: LlamaDartTtsModelPhase.failed, message: '$error'),
      );
    }
  }

  Future<LlamaDartTtsModelProfile> registerExternal({
    required String name,
    required String modelPath,
    required int modelSizeBytes,
    required String projectorPath,
    required int projectorSizeBytes,
  }) async {
    final profile = LlamaDartTtsModelProfile.external(
      name: name,
      modelPath: modelPath,
      modelSizeBytes: modelSizeBytes,
      projectorPath: projectorPath,
      projectorSizeBytes: projectorSizeBytes,
    );
    await selectProfile(profile);
    return profile;
  }

  Future<void> selectProfile(LlamaDartTtsModelProfile profile) async {
    if (profile == state.profile) return;
    final operation = ++_operationSerial;
    await _textToSpeech.unload();
    if (operation != _operationSerial) return;
    final customProfiles = profile.isExternal
        ? <LlamaDartTtsModelProfile>[
            for (final existing in state.customProfiles)
              if (existing.id != profile.id) existing,
            profile,
          ]
        : state.customProfiles;
    emit(
      state.copyWith(
        profile: profile,
        customProfiles: List.unmodifiable(customProfiles),
        phase: LlamaDartTtsModelPhase.checking,
        progress: 0,
        message: 'Checking ${profile.name}…',
      ),
    );
    final installed = await _store.resolve(profile);
    if (operation != _operationSerial) return;
    if (installed == null) {
      emit(
        state.copyWith(
          phase: LlamaDartTtsModelPhase.idle,
          message: profile.isExternal
              ? 'External model files are unavailable'
              : 'Model not installed',
        ),
      );
      return;
    }
    await _activate(operation);
  }

  Future<void> activate() async {
    if (state.phase == LlamaDartTtsModelPhase.loading) return;
    final operation = ++_operationSerial;
    await _activate(operation);
  }

  Future<void> _activate(int operation) async {
    final installed = await _store.resolve(state.profile);
    if (operation != _operationSerial) return;
    if (installed == null) {
      emit(
        state.copyWith(
          phase: LlamaDartTtsModelPhase.idle,
          progress: 0,
          message:
              'Install or locate the model before activating Local AI voice.',
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        phase: LlamaDartTtsModelPhase.loading,
        progress: 1,
        message: 'Loading ${state.profile.name}…',
      ),
    );
    try {
      await _textToSpeech.prepare();
      if (operation != _operationSerial) return;
      emit(
        state.copyWith(
          phase: LlamaDartTtsModelPhase.ready,
          progress: 1,
          message: 'Neural voice ready',
        ),
      );
    } catch (error) {
      if (operation != _operationSerial) return;
      emit(
        state.copyWith(
          phase: LlamaDartTtsModelPhase.failed,
          progress: 1,
          message: '$error',
        ),
      );
    }
  }

  Future<void> cancel() async {
    ++_operationSerial;
    await _store.cancelInstall(state.profile);
    emit(
      state.copyWith(
        phase: LlamaDartTtsModelPhase.cancelled,
        progress: 0,
        message: 'Download cancelled',
      ),
    );
  }

  Future<void> deactivate() async {
    final operation = ++_operationSerial;
    await _textToSpeech.unload();
    final installed = await _store.resolve(state.profile);
    if (operation != _operationSerial) return;
    emit(
      state.copyWith(
        phase: installed == null
            ? LlamaDartTtsModelPhase.idle
            : LlamaDartTtsModelPhase.ready,
        progress: installed == null ? 0 : 1,
        message: installed == null ? 'Model not installed' : 'Model installed',
      ),
    );
  }

  Future<void> remove() async {
    if (state.profile.isExternal) {
      await removeCustom(state.profile.id);
      return;
    }
    final operation = ++_operationSerial;
    await _textToSpeech.unload();
    await _store.delete(state.profile);
    if (operation != _operationSerial) return;
    emit(
      state.copyWith(
        phase: LlamaDartTtsModelPhase.idle,
        progress: 0,
        message: 'Local neural voice removed',
      ),
    );
  }

  Future<void> removeCustom(String id) async {
    final profiles = state.customProfiles
        .where((profile) => profile.id != id)
        .toList(growable: false);
    if (profiles.length == state.customProfiles.length) return;
    if (state.profile.id != id) {
      emit(state.copyWith(customProfiles: profiles));
      return;
    }
    final operation = ++_operationSerial;
    await _textToSpeech.unload();
    final installed = await _store.resolve(qwen3Tts17bQ4);
    if (operation != _operationSerial) return;
    emit(
      state.copyWith(
        profile: qwen3Tts17bQ4,
        customProfiles: profiles,
        phase: installed == null
            ? LlamaDartTtsModelPhase.idle
            : LlamaDartTtsModelPhase.ready,
        progress: installed == null ? 0 : 1,
        message: installed == null ? 'Model not installed' : 'Model installed',
      ),
    );
  }

  @override
  LlamaDartTtsModelState? fromJson(Map<String, dynamic> json) {
    final customProfiles = <LlamaDartTtsModelProfile>[];
    final rawProfiles = json['customProfiles'];
    if (rawProfiles is List) {
      for (final raw in rawProfiles) {
        final profile = LlamaDartTtsModelProfile.fromJson(raw);
        if (profile.isExternal) customProfiles.add(profile);
      }
    }
    final selected = LlamaDartTtsModelProfile.fromJson(json['profile']);
    return LlamaDartTtsModelState(
      profile:
          selected.isExternal &&
              !customProfiles.any((profile) => profile.id == selected.id)
          ? qwen3Tts17bQ4
          : selected,
      customProfiles: List.unmodifiable(customProfiles),
    );
  }

  @override
  Map<String, dynamic>? toJson(LlamaDartTtsModelState state) =>
      <String, dynamic>{
        'profile': state.profile.toJson(),
        'customProfiles': state.customProfiles
            .map((profile) => profile.toJson())
            .toList(growable: false),
      };
}
