import 'package:gena/features/chat/data/models/whisper_model_profile.dart';
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
    this.status = WhisperModelStatus.idle,
    this.progress = 0,
    this.message,
    this.errorMessage,
  });

  final WhisperModelProfile profile;
  final WhisperModelStatus status;
  final double progress;
  final String? message;
  final String? errorMessage;

  WhisperModelState copyWith({
    WhisperModelProfile? profile,
    WhisperModelStatus? status,
    double? progress,
    String? message,
    String? errorMessage,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return WhisperModelState(
      profile: profile ?? this.profile,
      status: status ?? this.status,
      progress: (progress ?? this.progress).clamp(0.0, 1.0),
      message: clearMessage ? null : message ?? this.message,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class WhisperModelCubit extends HydratedCubit<WhisperModelState> {
  WhisperModelCubit() : super(const WhisperModelState());

  Future<void> selectProfile(WhisperModelProfile profile) async {
    if (profile == state.profile) return;
    emit(
      WhisperModelState(profile: profile, message: '${profile.label} selected'),
    );
  }

  @override
  WhisperModelState? fromJson(Map<String, dynamic> json) {
    return WhisperModelState(
      profile: WhisperModelProfile.parse(json['profile']),
    );
  }

  @override
  Map<String, dynamic>? toJson(WhisperModelState state) {
    return <String, dynamic>{'profile': state.profile.id};
  }
}
