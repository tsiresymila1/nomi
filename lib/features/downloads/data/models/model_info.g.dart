// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ModelInfo _$ModelInfoFromJson(Map<String, dynamic> json) => _ModelInfo(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  description: json['description'] as String,
  modelId: json['modelId'] as String?,
  provider: json['provider'] as String,
  apiUrl: json['apiUrl'] as String?,
  apiToken: json['apiToken'] as String?,
  modelType: json['modelType'] as String,
  supportImage: json['supportImage'] as bool,
  supportAudio: json['supportAudio'] as bool,
  supportsFunctionCalls: json['supportsFunctionCalls'] as bool,
  isThinking: json['isThinking'] as bool,
  temperature: (json['temperature'] as num).toDouble(),
  topK: (json['topK'] as num).toInt(),
  topP: (json['topP'] as num).toDouble(),
  maxTokens: (json['maxTokens'] as num).toInt(),
  tokenBuffer: (json['tokenBuffer'] as num).toInt(),
  randomSeed: (json['randomSeed'] as num).toInt(),
  preferredBackend: json['preferredBackend'] as String,
  sourceType: json['sourceType'] as String,
  source: json['source'] as String,
);

Map<String, dynamic> _$ModelInfoToJson(_ModelInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'modelId': instance.modelId,
      'provider': instance.provider,
      'apiUrl': instance.apiUrl,
      'apiToken': instance.apiToken,
      'modelType': instance.modelType,
      'supportImage': instance.supportImage,
      'supportAudio': instance.supportAudio,
      'supportsFunctionCalls': instance.supportsFunctionCalls,
      'isThinking': instance.isThinking,
      'temperature': instance.temperature,
      'topK': instance.topK,
      'topP': instance.topP,
      'maxTokens': instance.maxTokens,
      'tokenBuffer': instance.tokenBuffer,
      'randomSeed': instance.randomSeed,
      'preferredBackend': instance.preferredBackend,
      'sourceType': instance.sourceType,
      'source': instance.source,
    };
