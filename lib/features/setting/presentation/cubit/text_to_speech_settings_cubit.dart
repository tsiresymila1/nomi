import 'package:gena/features/chat/data/services/text_to_speech.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

class TextToSpeechSettingsState {
  const TextToSpeechSettingsState({
    this.backend = TextToSpeechBackend.native,
    this.engine,
    this.voiceName,
    this.voiceLocale,
    this.speechRate = 0.5,
    this.pitch = 1,
  });

  final TextToSpeechBackend backend;
  final String? engine;
  final String? voiceName;
  final String? voiceLocale;
  final double speechRate;
  final double pitch;

  TextToSpeechPreferences get preferences => TextToSpeechPreferences(
    engine: engine,
    voiceName: voiceName,
    voiceLocale: voiceLocale,
    speechRate: speechRate,
    pitch: pitch,
  );

  TextToSpeechSettingsState copyWith({
    TextToSpeechBackend? backend,
    String? engine,
    String? voiceName,
    String? voiceLocale,
    double? speechRate,
    double? pitch,
    bool clearVoice = false,
  }) {
    return TextToSpeechSettingsState(
      backend: backend ?? this.backend,
      engine: engine ?? this.engine,
      voiceName: clearVoice ? null : voiceName ?? this.voiceName,
      voiceLocale: clearVoice ? null : voiceLocale ?? this.voiceLocale,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
    );
  }

  factory TextToSpeechSettingsState.fromJson(Map<String, dynamic> json) {
    return TextToSpeechSettingsState(
      backend: TextToSpeechBackend.values.firstWhere(
        (value) => value.name == json['backend'],
        orElse: () => TextToSpeechBackend.native,
      ),
      engine: json['engine'] as String?,
      voiceName: json['voiceName'] as String?,
      voiceLocale: json['voiceLocale'] as String?,
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0.5,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'backend': backend.name,
    'engine': engine,
    'voiceName': voiceName,
    'voiceLocale': voiceLocale,
    'speechRate': speechRate,
    'pitch': pitch,
  };
}

class TextToSpeechSettingsCubit
    extends HydratedCubit<TextToSpeechSettingsState> {
  TextToSpeechSettingsCubit() : super(const TextToSpeechSettingsState());

  void selectBackend(TextToSpeechBackend backend) {
    emit(state.copyWith(backend: backend));
  }

  void selectEngine(String? engine) {
    emit(state.copyWith(engine: engine, clearVoice: true));
  }

  void selectVoice(TextToSpeechVoice voice) {
    emit(state.copyWith(voiceName: voice.name, voiceLocale: voice.locale));
  }

  void setSpeechRate(double value) {
    emit(state.copyWith(speechRate: value.clamp(0.2, 0.9)));
  }

  void setPitch(double value) {
    emit(state.copyWith(pitch: value.clamp(0.5, 1.5)));
  }

  @override
  TextToSpeechSettingsState? fromJson(Map<String, dynamic> json) {
    return TextToSpeechSettingsState.fromJson(json);
  }

  @override
  Map<String, dynamic>? toJson(TextToSpeechSettingsState state) {
    return state.toJson();
  }
}
