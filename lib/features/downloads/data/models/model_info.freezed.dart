// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ModelInfo {

 int get id; String get name; String get description; String? get modelId; String get modelType; bool get supportImage; bool get supportAudio; bool get supportsFunctionCalls; bool get isThinking; double get temperature; int get topK; double get topP; int get maxTokens; int get tokenBuffer; int get randomSeed; String get preferredBackend; String get sourceType; String get source;
/// Create a copy of ModelInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelInfoCopyWith<ModelInfo> get copyWith => _$ModelInfoCopyWithImpl<ModelInfo>(this as ModelInfo, _$identity);

  /// Serializes this ModelInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModelInfo&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.modelType, modelType) || other.modelType == modelType)&&(identical(other.supportImage, supportImage) || other.supportImage == supportImage)&&(identical(other.supportAudio, supportAudio) || other.supportAudio == supportAudio)&&(identical(other.supportsFunctionCalls, supportsFunctionCalls) || other.supportsFunctionCalls == supportsFunctionCalls)&&(identical(other.isThinking, isThinking) || other.isThinking == isThinking)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.topK, topK) || other.topK == topK)&&(identical(other.topP, topP) || other.topP == topP)&&(identical(other.maxTokens, maxTokens) || other.maxTokens == maxTokens)&&(identical(other.tokenBuffer, tokenBuffer) || other.tokenBuffer == tokenBuffer)&&(identical(other.randomSeed, randomSeed) || other.randomSeed == randomSeed)&&(identical(other.preferredBackend, preferredBackend) || other.preferredBackend == preferredBackend)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,modelId,modelType,supportImage,supportAudio,supportsFunctionCalls,isThinking,temperature,topK,topP,maxTokens,tokenBuffer,randomSeed,preferredBackend,sourceType,source);

@override
String toString() {
  return 'ModelInfo(id: $id, name: $name, description: $description, modelId: $modelId, modelType: $modelType, supportImage: $supportImage, supportAudio: $supportAudio, supportsFunctionCalls: $supportsFunctionCalls, isThinking: $isThinking, temperature: $temperature, topK: $topK, topP: $topP, maxTokens: $maxTokens, tokenBuffer: $tokenBuffer, randomSeed: $randomSeed, preferredBackend: $preferredBackend, sourceType: $sourceType, source: $source)';
}


}

/// @nodoc
abstract mixin class $ModelInfoCopyWith<$Res>  {
  factory $ModelInfoCopyWith(ModelInfo value, $Res Function(ModelInfo) _then) = _$ModelInfoCopyWithImpl;
@useResult
$Res call({
 int id, String name, String description, String? modelId, String modelType, bool supportImage, bool supportAudio, bool supportsFunctionCalls, bool isThinking, double temperature, int topK, double topP, int maxTokens, int tokenBuffer, int randomSeed, String preferredBackend, String sourceType, String source
});




}
/// @nodoc
class _$ModelInfoCopyWithImpl<$Res>
    implements $ModelInfoCopyWith<$Res> {
  _$ModelInfoCopyWithImpl(this._self, this._then);

  final ModelInfo _self;
  final $Res Function(ModelInfo) _then;

/// Create a copy of ModelInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = null,Object? modelId = freezed,Object? modelType = null,Object? supportImage = null,Object? supportAudio = null,Object? supportsFunctionCalls = null,Object? isThinking = null,Object? temperature = null,Object? topK = null,Object? topP = null,Object? maxTokens = null,Object? tokenBuffer = null,Object? randomSeed = null,Object? preferredBackend = null,Object? sourceType = null,Object? source = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,modelType: null == modelType ? _self.modelType : modelType // ignore: cast_nullable_to_non_nullable
as String,supportImage: null == supportImage ? _self.supportImage : supportImage // ignore: cast_nullable_to_non_nullable
as bool,supportAudio: null == supportAudio ? _self.supportAudio : supportAudio // ignore: cast_nullable_to_non_nullable
as bool,supportsFunctionCalls: null == supportsFunctionCalls ? _self.supportsFunctionCalls : supportsFunctionCalls // ignore: cast_nullable_to_non_nullable
as bool,isThinking: null == isThinking ? _self.isThinking : isThinking // ignore: cast_nullable_to_non_nullable
as bool,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,topK: null == topK ? _self.topK : topK // ignore: cast_nullable_to_non_nullable
as int,topP: null == topP ? _self.topP : topP // ignore: cast_nullable_to_non_nullable
as double,maxTokens: null == maxTokens ? _self.maxTokens : maxTokens // ignore: cast_nullable_to_non_nullable
as int,tokenBuffer: null == tokenBuffer ? _self.tokenBuffer : tokenBuffer // ignore: cast_nullable_to_non_nullable
as int,randomSeed: null == randomSeed ? _self.randomSeed : randomSeed // ignore: cast_nullable_to_non_nullable
as int,preferredBackend: null == preferredBackend ? _self.preferredBackend : preferredBackend // ignore: cast_nullable_to_non_nullable
as String,sourceType: null == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ModelInfo].
extension ModelInfoPatterns on ModelInfo {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModelInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModelInfo() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModelInfo value)  $default,){
final _that = this;
switch (_that) {
case _ModelInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModelInfo value)?  $default,){
final _that = this;
switch (_that) {
case _ModelInfo() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  String description,  String? modelId,  String modelType,  bool supportImage,  bool supportAudio,  bool supportsFunctionCalls,  bool isThinking,  double temperature,  int topK,  double topP,  int maxTokens,  int tokenBuffer,  int randomSeed,  String preferredBackend,  String sourceType,  String source)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModelInfo() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.modelId,_that.modelType,_that.supportImage,_that.supportAudio,_that.supportsFunctionCalls,_that.isThinking,_that.temperature,_that.topK,_that.topP,_that.maxTokens,_that.tokenBuffer,_that.randomSeed,_that.preferredBackend,_that.sourceType,_that.source);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  String description,  String? modelId,  String modelType,  bool supportImage,  bool supportAudio,  bool supportsFunctionCalls,  bool isThinking,  double temperature,  int topK,  double topP,  int maxTokens,  int tokenBuffer,  int randomSeed,  String preferredBackend,  String sourceType,  String source)  $default,) {final _that = this;
switch (_that) {
case _ModelInfo():
return $default(_that.id,_that.name,_that.description,_that.modelId,_that.modelType,_that.supportImage,_that.supportAudio,_that.supportsFunctionCalls,_that.isThinking,_that.temperature,_that.topK,_that.topP,_that.maxTokens,_that.tokenBuffer,_that.randomSeed,_that.preferredBackend,_that.sourceType,_that.source);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  String description,  String? modelId,  String modelType,  bool supportImage,  bool supportAudio,  bool supportsFunctionCalls,  bool isThinking,  double temperature,  int topK,  double topP,  int maxTokens,  int tokenBuffer,  int randomSeed,  String preferredBackend,  String sourceType,  String source)?  $default,) {final _that = this;
switch (_that) {
case _ModelInfo() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.modelId,_that.modelType,_that.supportImage,_that.supportAudio,_that.supportsFunctionCalls,_that.isThinking,_that.temperature,_that.topK,_that.topP,_that.maxTokens,_that.tokenBuffer,_that.randomSeed,_that.preferredBackend,_that.sourceType,_that.source);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ModelInfo implements ModelInfo {
  const _ModelInfo({required this.id, required this.name, required this.description, this.modelId, required this.modelType, required this.supportImage, required this.supportAudio, required this.supportsFunctionCalls, required this.isThinking, required this.temperature, required this.topK, required this.topP, required this.maxTokens, required this.tokenBuffer, required this.randomSeed, required this.preferredBackend, required this.sourceType, required this.source});
  factory _ModelInfo.fromJson(Map<String, dynamic> json) => _$ModelInfoFromJson(json);

@override final  int id;
@override final  String name;
@override final  String description;
@override final  String? modelId;
@override final  String modelType;
@override final  bool supportImage;
@override final  bool supportAudio;
@override final  bool supportsFunctionCalls;
@override final  bool isThinking;
@override final  double temperature;
@override final  int topK;
@override final  double topP;
@override final  int maxTokens;
@override final  int tokenBuffer;
@override final  int randomSeed;
@override final  String preferredBackend;
@override final  String sourceType;
@override final  String source;

/// Create a copy of ModelInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModelInfoCopyWith<_ModelInfo> get copyWith => __$ModelInfoCopyWithImpl<_ModelInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ModelInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModelInfo&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.modelType, modelType) || other.modelType == modelType)&&(identical(other.supportImage, supportImage) || other.supportImage == supportImage)&&(identical(other.supportAudio, supportAudio) || other.supportAudio == supportAudio)&&(identical(other.supportsFunctionCalls, supportsFunctionCalls) || other.supportsFunctionCalls == supportsFunctionCalls)&&(identical(other.isThinking, isThinking) || other.isThinking == isThinking)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.topK, topK) || other.topK == topK)&&(identical(other.topP, topP) || other.topP == topP)&&(identical(other.maxTokens, maxTokens) || other.maxTokens == maxTokens)&&(identical(other.tokenBuffer, tokenBuffer) || other.tokenBuffer == tokenBuffer)&&(identical(other.randomSeed, randomSeed) || other.randomSeed == randomSeed)&&(identical(other.preferredBackend, preferredBackend) || other.preferredBackend == preferredBackend)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,modelId,modelType,supportImage,supportAudio,supportsFunctionCalls,isThinking,temperature,topK,topP,maxTokens,tokenBuffer,randomSeed,preferredBackend,sourceType,source);

@override
String toString() {
  return 'ModelInfo(id: $id, name: $name, description: $description, modelId: $modelId, modelType: $modelType, supportImage: $supportImage, supportAudio: $supportAudio, supportsFunctionCalls: $supportsFunctionCalls, isThinking: $isThinking, temperature: $temperature, topK: $topK, topP: $topP, maxTokens: $maxTokens, tokenBuffer: $tokenBuffer, randomSeed: $randomSeed, preferredBackend: $preferredBackend, sourceType: $sourceType, source: $source)';
}


}

/// @nodoc
abstract mixin class _$ModelInfoCopyWith<$Res> implements $ModelInfoCopyWith<$Res> {
  factory _$ModelInfoCopyWith(_ModelInfo value, $Res Function(_ModelInfo) _then) = __$ModelInfoCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, String description, String? modelId, String modelType, bool supportImage, bool supportAudio, bool supportsFunctionCalls, bool isThinking, double temperature, int topK, double topP, int maxTokens, int tokenBuffer, int randomSeed, String preferredBackend, String sourceType, String source
});




}
/// @nodoc
class __$ModelInfoCopyWithImpl<$Res>
    implements _$ModelInfoCopyWith<$Res> {
  __$ModelInfoCopyWithImpl(this._self, this._then);

  final _ModelInfo _self;
  final $Res Function(_ModelInfo) _then;

/// Create a copy of ModelInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = null,Object? modelId = freezed,Object? modelType = null,Object? supportImage = null,Object? supportAudio = null,Object? supportsFunctionCalls = null,Object? isThinking = null,Object? temperature = null,Object? topK = null,Object? topP = null,Object? maxTokens = null,Object? tokenBuffer = null,Object? randomSeed = null,Object? preferredBackend = null,Object? sourceType = null,Object? source = null,}) {
  return _then(_ModelInfo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,modelType: null == modelType ? _self.modelType : modelType // ignore: cast_nullable_to_non_nullable
as String,supportImage: null == supportImage ? _self.supportImage : supportImage // ignore: cast_nullable_to_non_nullable
as bool,supportAudio: null == supportAudio ? _self.supportAudio : supportAudio // ignore: cast_nullable_to_non_nullable
as bool,supportsFunctionCalls: null == supportsFunctionCalls ? _self.supportsFunctionCalls : supportsFunctionCalls // ignore: cast_nullable_to_non_nullable
as bool,isThinking: null == isThinking ? _self.isThinking : isThinking // ignore: cast_nullable_to_non_nullable
as bool,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,topK: null == topK ? _self.topK : topK // ignore: cast_nullable_to_non_nullable
as int,topP: null == topP ? _self.topP : topP // ignore: cast_nullable_to_non_nullable
as double,maxTokens: null == maxTokens ? _self.maxTokens : maxTokens // ignore: cast_nullable_to_non_nullable
as int,tokenBuffer: null == tokenBuffer ? _self.tokenBuffer : tokenBuffer // ignore: cast_nullable_to_non_nullable
as int,randomSeed: null == randomSeed ? _self.randomSeed : randomSeed // ignore: cast_nullable_to_non_nullable
as int,preferredBackend: null == preferredBackend ? _self.preferredBackend : preferredBackend // ignore: cast_nullable_to_non_nullable
as String,sourceType: null == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
