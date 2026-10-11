import 'package:gena/features/chat/data/models/whisper_model_profile.dart';
import 'package:gena/features/chat/data/services/whisper_model_provisioner.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

enum WhisperModelStatus {
  idle,
  checking,
  queued,
  downloading,
  paused,
  ready,
  failed,
  cancelled,
}

class WhisperModelState {
  const WhisperModelState({
    this.profile = WhisperModelProfile.tiny,
    this.customProfiles = const <WhisperModelProfile>[],
    this.status = WhisperModelStatus.idle,
    this.progress = 0,
    this.message,
    this.errorMessage,
  });

  final WhisperModelProfile profile;
  final List<WhisperModelProfile> customProfiles;
  final WhisperModelStatus status;
  final double progress;
  final String? message;
  final String? errorMessage;

  WhisperModelState copyWith({
    WhisperModelProfile? profile,
    List<WhisperModelProfile>? customProfiles,
    WhisperModelStatus? status,
    double? progress,
    String? message,
    String? errorMessage,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return WhisperModelState(
      profile: profile ?? this.profile,
      customProfiles: customProfiles ?? this.customProfiles,
      status: status ?? this.status,
      progress: (progress ?? this.progress).clamp(0.0, 1.0),
      message: clearMessage ? null : message ?? this.message,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  List<WhisperModelProfile> get allProfiles => <WhisperModelProfile>[
    ...WhisperModelProfile.builtIn,
    ...customProfiles,
  ];
}

class WhisperModelCubit extends HydratedCubit<WhisperModelState>
    implements WhisperProvisioner {
  WhisperModelCubit({WhisperModelManager? modelManager})
    : _modelManager = modelManager,
      super(const WhisperModelState());

  final WhisperModelManager? _modelManager;
  int _preparationSerial = 0;

  Future<void> selectProfile(WhisperModelProfile profile) async {
    if (profile == state.profile) return;
    final customProfiles = profile.isExternal
        ? <WhisperModelProfile>[
            for (final existing in state.customProfiles)
              if (existing.id != profile.id) existing,
            profile,
          ]
        : state.customProfiles;
    emit(
      state.copyWith(
        profile: profile,
        customProfiles: List.unmodifiable(customProfiles),
        status: WhisperModelStatus.idle,
        progress: 0,
        message: '${profile.label} selected',
        clearError: true,
      ),
    );
    if (_modelManager == null) return;
    try {
      await ensureReady(profile);
    } catch (_) {
      // The preparation state already exposes the actionable failure in UI.
    }
  }

  Future<void> removeCustom(String id) async {
    final profiles = state.customProfiles
        .where((profile) => profile.id != id)
        .toList(growable: false);
    if (profiles.length == state.customProfiles.length) return;
    if (state.profile.id == id) {
      emit(
        state.copyWith(
          profile: WhisperModelProfile.tiny,
          customProfiles: profiles,
          status: WhisperModelStatus.idle,
          progress: 0,
          message: 'Tiny selected',
          clearError: true,
        ),
      );
      return;
    }
    emit(state.copyWith(customProfiles: profiles));
  }

  @override
  Future<String> ensureReady(
    WhisperModelProfile profile, {
    void Function(double progress, String message)? onProgress,
  }) async {
    final manager = _modelManager;
    if (manager == null) {
      throw StateError('Whisper model provisioning is not configured.');
    }
    final operation = ++_preparationSerial;

    _emitFor(
      operation,
      state.copyWith(
        profile: profile,
        status: WhisperModelStatus.checking,
        progress: 0,
        message: 'Checking ${profile.label}…',
        clearError: true,
      ),
    );
    try {
      final installed = await manager.isInstalled(profile);
      if (!installed) {
        _emitFor(
          operation,
          state.copyWith(
            profile: profile,
            status: WhisperModelStatus.queued,
            progress: 0,
            message: '${profile.label} queued',
            clearError: true,
          ),
        );
      }

      final path = await manager.ensureReady(
        profile,
        onProgress: (progress, message) {
          final status = progress >= 1
              ? WhisperModelStatus.ready
              : WhisperModelStatus.downloading;
          _emitFor(
            operation,
            state.copyWith(
              profile: profile,
              status: status,
              progress: progress,
              message: message,
              clearError: true,
            ),
          );
          onProgress?.call(progress, message);
        },
      );
      _emitFor(
        operation,
        state.copyWith(
          profile: profile,
          status: WhisperModelStatus.ready,
          progress: 1,
          message: '${profile.label} is ready',
          clearError: true,
        ),
      );
      return path;
    } catch (error) {
      _emitFor(
        operation,
        state.copyWith(
          profile: profile,
          status: WhisperModelStatus.failed,
          progress: 0,
          errorMessage: 'Whisper preparation failed: $error',
        ),
      );
      rethrow;
    }
  }

  Future<void> refreshStatus() async {
    final manager = _modelManager;
    if (manager == null) return;
    final operation = ++_preparationSerial;
    final installed = await manager.isInstalled(state.profile);
    _emitFor(
      operation,
      state.copyWith(
        status: installed ? WhisperModelStatus.ready : WhisperModelStatus.idle,
        progress: installed ? 1 : 0,
        message: installed ? '${state.profile.label} is ready' : null,
        clearMessage: !installed,
        clearError: true,
      ),
    );
  }

  Future<void> cancelDownload() async {
    final manager = _modelManager;
    if (manager == null) return;
    final operation = ++_preparationSerial;
    await manager.cancel(state.profile);
    _emitFor(
      operation,
      state.copyWith(
        status: WhisperModelStatus.cancelled,
        progress: 0,
        message: 'Whisper download cancelled',
        clearError: true,
      ),
    );
  }

  void _emitFor(int operation, WhisperModelState next) {
    if (!isClosed && operation == _preparationSerial) emit(next);
  }

  @override
  WhisperModelState? fromJson(Map<String, dynamic> json) {
    final customProfiles = <WhisperModelProfile>[];
    final rawProfiles = json['customProfiles'];
    if (rawProfiles is List) {
      for (final raw in rawProfiles) {
        final profile = WhisperModelProfile.parse(raw);
        if (profile.isExternal) customProfiles.add(profile);
      }
    }
    final selected = WhisperModelProfile.parse(json['profile']);
    return WhisperModelState(
      profile:
          selected.isExternal &&
              !customProfiles.any((profile) => profile.id == selected.id)
          ? WhisperModelProfile.tiny
          : selected,
      customProfiles: List.unmodifiable(customProfiles),
    );
  }

  @override
  Map<String, dynamic>? toJson(WhisperModelState state) {
    return <String, dynamic>{
      'profile': state.profile.toJson(),
      'customProfiles': state.customProfiles
          .map((profile) => profile.toJson())
          .toList(growable: false),
    };
  }
}
