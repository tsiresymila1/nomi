import 'package:hydrated_bloc/hydrated_bloc.dart';

class SelectedModelCubit extends HydratedCubit<int?> {
  SelectedModelCubit() : super(null);

  Future<void> selectModel(int modelId) async {
    if (state == modelId) return;
    emit(modelId);
  }

  Future<void> clearSelection() async {
    emit(null);
  }

  @override
  int? fromJson(Map<String, dynamic> json) {
    final raw = json['selectedModelId'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }

  @override
  Map<String, dynamic>? toJson(int? state) {
    return <String, dynamic>{'selectedModelId': state};
  }
}
