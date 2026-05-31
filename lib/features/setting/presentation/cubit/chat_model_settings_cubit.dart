import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:gena/features/setting/data/chat_model_settings.dart';

class ChatModelSettingsCubit extends HydratedCubit<ChatModelSettings> {
  ChatModelSettingsCubit() : super(ChatModelSettings.defaults());

  Future<void> save(ChatModelSettings next) async {
    emit(next);
  }

  Future<void> resetDefaults() async {
    emit(ChatModelSettings.defaults());
  }

  @override
  ChatModelSettings? fromJson(Map<String, dynamic> json) {
    return ChatModelSettings.fromJson(json);
  }

  @override
  Map<String, dynamic>? toJson(ChatModelSettings state) {
    return state.toJson();
  }
}
