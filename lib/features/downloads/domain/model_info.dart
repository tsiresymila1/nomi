import 'package:freezed_annotation/freezed_annotation.dart';

part 'model_info.freezed.dart';
part 'model_info.g.dart';

@freezed
abstract class ModelInfo with _$ModelInfo {
  const factory ModelInfo({
    required int id,
    required String name,
    required String description,
    required String modelType,
    required String sourceType,
    required String source,
  }) = _ModelInfo;

  factory ModelInfo.fromJson(Map<String, dynamic> json) =>
      _$ModelInfoFromJson(json);
}
