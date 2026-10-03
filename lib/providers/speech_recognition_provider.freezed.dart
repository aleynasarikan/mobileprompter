// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'speech_recognition_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SpeechRecognitionState {

 bool get initialized; bool get available;/// Null until checked.
 bool? get permissionGranted;/// The plugin found no Android RecognitionService.
 bool get recognizerMissing;/// The user wants to listen; stays true while a continuous session
/// restarts.
 bool get isActive;/// The plugin reports listening as soon as `startListening` is posted, so
/// this does not prove that audio is captured; see [soundLevelEvents].
 bool get isListening; String get status; String get partialText;/// All final results of the current run, joined with spaces.
 String get finalText; String? get error; String? get errorCode; bool get errorRecoverable; String? get localeId; bool get isPreferredLocale; String? get localeWarning; int get availableLocaleCount;/// Recognizer sessions started since the last [SpeechRecognition.start].
 int get sessionCount;/// Input level statistics since the last [SpeechRecognition.start].
 int get soundLevelEvents; double? get soundLevel; double? get minSoundLevel; double? get maxSoundLevel;/// Newest first.
 List<String> get log;
/// Create a copy of SpeechRecognitionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpeechRecognitionStateCopyWith<SpeechRecognitionState> get copyWith => _$SpeechRecognitionStateCopyWithImpl<SpeechRecognitionState>(this as SpeechRecognitionState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SpeechRecognitionState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpeechRecognitionState&&(identical(other.initialized, _this.initialized) || other.initialized == _this.initialized)&&(identical(other.available, _this.available) || other.available == _this.available)&&(identical(other.permissionGranted, _this.permissionGranted) || other.permissionGranted == _this.permissionGranted)&&(identical(other.recognizerMissing, _this.recognizerMissing) || other.recognizerMissing == _this.recognizerMissing)&&(identical(other.isActive, _this.isActive) || other.isActive == _this.isActive)&&(identical(other.isListening, _this.isListening) || other.isListening == _this.isListening)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.partialText, _this.partialText) || other.partialText == _this.partialText)&&(identical(other.finalText, _this.finalText) || other.finalText == _this.finalText)&&(identical(other.error, _this.error) || other.error == _this.error)&&(identical(other.errorCode, _this.errorCode) || other.errorCode == _this.errorCode)&&(identical(other.errorRecoverable, _this.errorRecoverable) || other.errorRecoverable == _this.errorRecoverable)&&(identical(other.localeId, _this.localeId) || other.localeId == _this.localeId)&&(identical(other.isPreferredLocale, _this.isPreferredLocale) || other.isPreferredLocale == _this.isPreferredLocale)&&(identical(other.localeWarning, _this.localeWarning) || other.localeWarning == _this.localeWarning)&&(identical(other.availableLocaleCount, _this.availableLocaleCount) || other.availableLocaleCount == _this.availableLocaleCount)&&(identical(other.sessionCount, _this.sessionCount) || other.sessionCount == _this.sessionCount)&&(identical(other.soundLevelEvents, _this.soundLevelEvents) || other.soundLevelEvents == _this.soundLevelEvents)&&(identical(other.soundLevel, _this.soundLevel) || other.soundLevel == _this.soundLevel)&&(identical(other.minSoundLevel, _this.minSoundLevel) || other.minSoundLevel == _this.minSoundLevel)&&(identical(other.maxSoundLevel, _this.maxSoundLevel) || other.maxSoundLevel == _this.maxSoundLevel)&&const DeepCollectionEquality().equals(other.log, _this.log));
}


@override
int get hashCode {
  final _this = this as SpeechRecognitionState;
  return Object.hashAll([runtimeType,_this.initialized,_this.available,_this.permissionGranted,_this.recognizerMissing,_this.isActive,_this.isListening,_this.status,_this.partialText,_this.finalText,_this.error,_this.errorCode,_this.errorRecoverable,_this.localeId,_this.isPreferredLocale,_this.localeWarning,_this.availableLocaleCount,_this.sessionCount,_this.soundLevelEvents,_this.soundLevel,_this.minSoundLevel,_this.maxSoundLevel,const DeepCollectionEquality().hash(_this.log)]);
}

@override
String toString() {
  final _this = this as SpeechRecognitionState;
  return 'SpeechRecognitionState(initialized: ${_this.initialized}, available: ${_this.available}, permissionGranted: ${_this.permissionGranted}, recognizerMissing: ${_this.recognizerMissing}, isActive: ${_this.isActive}, isListening: ${_this.isListening}, status: ${_this.status}, partialText: ${_this.partialText}, finalText: ${_this.finalText}, error: ${_this.error}, errorCode: ${_this.errorCode}, errorRecoverable: ${_this.errorRecoverable}, localeId: ${_this.localeId}, isPreferredLocale: ${_this.isPreferredLocale}, localeWarning: ${_this.localeWarning}, availableLocaleCount: ${_this.availableLocaleCount}, sessionCount: ${_this.sessionCount}, soundLevelEvents: ${_this.soundLevelEvents}, soundLevel: ${_this.soundLevel}, minSoundLevel: ${_this.minSoundLevel}, maxSoundLevel: ${_this.maxSoundLevel}, log: ${_this.log})';
}


}

/// @nodoc
abstract mixin class $SpeechRecognitionStateCopyWith<$Res>  {
  factory $SpeechRecognitionStateCopyWith(SpeechRecognitionState value, $Res Function(SpeechRecognitionState) _then) = _$SpeechRecognitionStateCopyWithImpl;
@useResult
$Res call({
 bool initialized, bool available, bool? permissionGranted, bool recognizerMissing, bool isActive, bool isListening, String status, String partialText, String finalText, String? error, String? errorCode, bool errorRecoverable, String? localeId, bool isPreferredLocale, String? localeWarning, int availableLocaleCount, int sessionCount, int soundLevelEvents, double? soundLevel, double? minSoundLevel, double? maxSoundLevel, List<String> log
});




}
/// @nodoc
class _$SpeechRecognitionStateCopyWithImpl<$Res>
    implements $SpeechRecognitionStateCopyWith<$Res> {
  _$SpeechRecognitionStateCopyWithImpl(this._self, this._then);

  final SpeechRecognitionState _self;
  final $Res Function(SpeechRecognitionState) _then;

/// Create a copy of SpeechRecognitionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? initialized = null,Object? available = null,Object? permissionGranted = freezed,Object? recognizerMissing = null,Object? isActive = null,Object? isListening = null,Object? status = null,Object? partialText = null,Object? finalText = null,Object? error = freezed,Object? errorCode = freezed,Object? errorRecoverable = null,Object? localeId = freezed,Object? isPreferredLocale = null,Object? localeWarning = freezed,Object? availableLocaleCount = null,Object? sessionCount = null,Object? soundLevelEvents = null,Object? soundLevel = freezed,Object? minSoundLevel = freezed,Object? maxSoundLevel = freezed,Object? log = null,}) {
  return _then(SpeechRecognitionState(
initialized: null == initialized ? _self.initialized : initialized // ignore: cast_nullable_to_non_nullable
as bool,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,permissionGranted: freezed == permissionGranted ? _self.permissionGranted : permissionGranted // ignore: cast_nullable_to_non_nullable
as bool?,recognizerMissing: null == recognizerMissing ? _self.recognizerMissing : recognizerMissing // ignore: cast_nullable_to_non_nullable
as bool,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,isListening: null == isListening ? _self.isListening : isListening // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,partialText: null == partialText ? _self.partialText : partialText // ignore: cast_nullable_to_non_nullable
as String,finalText: null == finalText ? _self.finalText : finalText // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,errorRecoverable: null == errorRecoverable ? _self.errorRecoverable : errorRecoverable // ignore: cast_nullable_to_non_nullable
as bool,localeId: freezed == localeId ? _self.localeId : localeId // ignore: cast_nullable_to_non_nullable
as String?,isPreferredLocale: null == isPreferredLocale ? _self.isPreferredLocale : isPreferredLocale // ignore: cast_nullable_to_non_nullable
as bool,localeWarning: freezed == localeWarning ? _self.localeWarning : localeWarning // ignore: cast_nullable_to_non_nullable
as String?,availableLocaleCount: null == availableLocaleCount ? _self.availableLocaleCount : availableLocaleCount // ignore: cast_nullable_to_non_nullable
as int,sessionCount: null == sessionCount ? _self.sessionCount : sessionCount // ignore: cast_nullable_to_non_nullable
as int,soundLevelEvents: null == soundLevelEvents ? _self.soundLevelEvents : soundLevelEvents // ignore: cast_nullable_to_non_nullable
as int,soundLevel: freezed == soundLevel ? _self.soundLevel : soundLevel // ignore: cast_nullable_to_non_nullable
as double?,minSoundLevel: freezed == minSoundLevel ? _self.minSoundLevel : minSoundLevel // ignore: cast_nullable_to_non_nullable
as double?,maxSoundLevel: freezed == maxSoundLevel ? _self.maxSoundLevel : maxSoundLevel // ignore: cast_nullable_to_non_nullable
as double?,log: null == log ? _self.log : log // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [SpeechRecognitionState].
extension SpeechRecognitionStatePatterns on SpeechRecognitionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpeechRecognitionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpeechRecognitionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpeechRecognitionState value)  $default,){
final _that = this;
switch (_that) {
case _SpeechRecognitionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpeechRecognitionState value)?  $default,){
final _that = this;
switch (_that) {
case _SpeechRecognitionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool initialized,  bool available,  bool? permissionGranted,  bool recognizerMissing,  bool isActive,  bool isListening,  String status,  String partialText,  String finalText,  String? error,  String? errorCode,  bool errorRecoverable,  String? localeId,  bool isPreferredLocale,  String? localeWarning,  int availableLocaleCount,  int sessionCount,  int soundLevelEvents,  double? soundLevel,  double? minSoundLevel,  double? maxSoundLevel,  List<String> log)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpeechRecognitionState() when $default != null:
return $default(_that.initialized,_that.available,_that.permissionGranted,_that.recognizerMissing,_that.isActive,_that.isListening,_that.status,_that.partialText,_that.finalText,_that.error,_that.errorCode,_that.errorRecoverable,_that.localeId,_that.isPreferredLocale,_that.localeWarning,_that.availableLocaleCount,_that.sessionCount,_that.soundLevelEvents,_that.soundLevel,_that.minSoundLevel,_that.maxSoundLevel,_that.log);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool initialized,  bool available,  bool? permissionGranted,  bool recognizerMissing,  bool isActive,  bool isListening,  String status,  String partialText,  String finalText,  String? error,  String? errorCode,  bool errorRecoverable,  String? localeId,  bool isPreferredLocale,  String? localeWarning,  int availableLocaleCount,  int sessionCount,  int soundLevelEvents,  double? soundLevel,  double? minSoundLevel,  double? maxSoundLevel,  List<String> log)  $default,) {final _that = this;
switch (_that) {
case _SpeechRecognitionState():
return $default(_that.initialized,_that.available,_that.permissionGranted,_that.recognizerMissing,_that.isActive,_that.isListening,_that.status,_that.partialText,_that.finalText,_that.error,_that.errorCode,_that.errorRecoverable,_that.localeId,_that.isPreferredLocale,_that.localeWarning,_that.availableLocaleCount,_that.sessionCount,_that.soundLevelEvents,_that.soundLevel,_that.minSoundLevel,_that.maxSoundLevel,_that.log);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool initialized,  bool available,  bool? permissionGranted,  bool recognizerMissing,  bool isActive,  bool isListening,  String status,  String partialText,  String finalText,  String? error,  String? errorCode,  bool errorRecoverable,  String? localeId,  bool isPreferredLocale,  String? localeWarning,  int availableLocaleCount,  int sessionCount,  int soundLevelEvents,  double? soundLevel,  double? minSoundLevel,  double? maxSoundLevel,  List<String> log)?  $default,) {final _that = this;
switch (_that) {
case _SpeechRecognitionState() when $default != null:
return $default(_that.initialized,_that.available,_that.permissionGranted,_that.recognizerMissing,_that.isActive,_that.isListening,_that.status,_that.partialText,_that.finalText,_that.error,_that.errorCode,_that.errorRecoverable,_that.localeId,_that.isPreferredLocale,_that.localeWarning,_that.availableLocaleCount,_that.sessionCount,_that.soundLevelEvents,_that.soundLevel,_that.minSoundLevel,_that.maxSoundLevel,_that.log);case _:
  return null;

}
}

}

/// @nodoc


class _SpeechRecognitionState extends SpeechRecognitionState {
  const _SpeechRecognitionState({this.initialized = false, this.available = false, this.permissionGranted, this.recognizerMissing = false, this.isActive = false, this.isListening = false, this.status = '', this.partialText = '', this.finalText = '', this.error, this.errorCode, this.errorRecoverable = false, this.localeId, this.isPreferredLocale = false, this.localeWarning, this.availableLocaleCount = 0, this.sessionCount = 0, this.soundLevelEvents = 0, this.soundLevel, this.minSoundLevel, this.maxSoundLevel,  List<String> log = const <String>[]}): _log = log,super._();
  

@override@JsonKey() final  bool initialized;
@override@JsonKey() final  bool available;
/// Null until checked.
@override final  bool? permissionGranted;
/// The plugin found no Android RecognitionService.
@override@JsonKey() final  bool recognizerMissing;
/// The user wants to listen; stays true while a continuous session
/// restarts.
@override@JsonKey() final  bool isActive;
/// The plugin reports listening as soon as `startListening` is posted, so
/// this does not prove that audio is captured; see [soundLevelEvents].
@override@JsonKey() final  bool isListening;
@override@JsonKey() final  String status;
@override@JsonKey() final  String partialText;
/// All final results of the current run, joined with spaces.
@override@JsonKey() final  String finalText;
@override final  String? error;
@override final  String? errorCode;
@override@JsonKey() final  bool errorRecoverable;
@override final  String? localeId;
@override@JsonKey() final  bool isPreferredLocale;
@override final  String? localeWarning;
@override@JsonKey() final  int availableLocaleCount;
/// Recognizer sessions started since the last [SpeechRecognition.start].
@override@JsonKey() final  int sessionCount;
/// Input level statistics since the last [SpeechRecognition.start].
@override@JsonKey() final  int soundLevelEvents;
@override final  double? soundLevel;
@override final  double? minSoundLevel;
@override final  double? maxSoundLevel;
/// Newest first.
 final  List<String> _log;
/// Newest first.
@override@JsonKey() List<String> get log {
  if (_log is EqualUnmodifiableListView) return _log;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_log);
}


/// Create a copy of SpeechRecognitionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpeechRecognitionStateCopyWith<_SpeechRecognitionState> get copyWith => __$SpeechRecognitionStateCopyWithImpl<_SpeechRecognitionState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpeechRecognitionState&&(identical(other.initialized, initialized) || other.initialized == initialized)&&(identical(other.available, available) || other.available == available)&&(identical(other.permissionGranted, permissionGranted) || other.permissionGranted == permissionGranted)&&(identical(other.recognizerMissing, recognizerMissing) || other.recognizerMissing == recognizerMissing)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.isListening, isListening) || other.isListening == isListening)&&(identical(other.status, status) || other.status == status)&&(identical(other.partialText, partialText) || other.partialText == partialText)&&(identical(other.finalText, finalText) || other.finalText == finalText)&&(identical(other.error, error) || other.error == error)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.errorRecoverable, errorRecoverable) || other.errorRecoverable == errorRecoverable)&&(identical(other.localeId, localeId) || other.localeId == localeId)&&(identical(other.isPreferredLocale, isPreferredLocale) || other.isPreferredLocale == isPreferredLocale)&&(identical(other.localeWarning, localeWarning) || other.localeWarning == localeWarning)&&(identical(other.availableLocaleCount, availableLocaleCount) || other.availableLocaleCount == availableLocaleCount)&&(identical(other.sessionCount, sessionCount) || other.sessionCount == sessionCount)&&(identical(other.soundLevelEvents, soundLevelEvents) || other.soundLevelEvents == soundLevelEvents)&&(identical(other.soundLevel, soundLevel) || other.soundLevel == soundLevel)&&(identical(other.minSoundLevel, minSoundLevel) || other.minSoundLevel == minSoundLevel)&&(identical(other.maxSoundLevel, maxSoundLevel) || other.maxSoundLevel == maxSoundLevel)&&const DeepCollectionEquality().equals(other.log, _log));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,initialized,available,permissionGranted,recognizerMissing,isActive,isListening,status,partialText,finalText,error,errorCode,errorRecoverable,localeId,isPreferredLocale,localeWarning,availableLocaleCount,sessionCount,soundLevelEvents,soundLevel,minSoundLevel,maxSoundLevel,const DeepCollectionEquality().hash(_log)]);
}

@override
String toString() {
    return 'SpeechRecognitionState(initialized: $initialized, available: $available, permissionGranted: $permissionGranted, recognizerMissing: $recognizerMissing, isActive: $isActive, isListening: $isListening, status: $status, partialText: $partialText, finalText: $finalText, error: $error, errorCode: $errorCode, errorRecoverable: $errorRecoverable, localeId: $localeId, isPreferredLocale: $isPreferredLocale, localeWarning: $localeWarning, availableLocaleCount: $availableLocaleCount, sessionCount: $sessionCount, soundLevelEvents: $soundLevelEvents, soundLevel: $soundLevel, minSoundLevel: $minSoundLevel, maxSoundLevel: $maxSoundLevel, log: $log)';
}


}

/// @nodoc
abstract mixin class _$SpeechRecognitionStateCopyWith<$Res> implements $SpeechRecognitionStateCopyWith<$Res> {
  factory _$SpeechRecognitionStateCopyWith(_SpeechRecognitionState value, $Res Function(_SpeechRecognitionState) _then) = __$SpeechRecognitionStateCopyWithImpl;
@override @useResult
$Res call({
 bool initialized, bool available, bool? permissionGranted, bool recognizerMissing, bool isActive, bool isListening, String status, String partialText, String finalText, String? error, String? errorCode, bool errorRecoverable, String? localeId, bool isPreferredLocale, String? localeWarning, int availableLocaleCount, int sessionCount, int soundLevelEvents, double? soundLevel, double? minSoundLevel, double? maxSoundLevel, List<String> log
});




}
/// @nodoc
class __$SpeechRecognitionStateCopyWithImpl<$Res>
    implements _$SpeechRecognitionStateCopyWith<$Res> {
  __$SpeechRecognitionStateCopyWithImpl(this._self, this._then);

  final _SpeechRecognitionState _self;
  final $Res Function(_SpeechRecognitionState) _then;

/// Create a copy of SpeechRecognitionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? initialized = null,Object? available = null,Object? permissionGranted = freezed,Object? recognizerMissing = null,Object? isActive = null,Object? isListening = null,Object? status = null,Object? partialText = null,Object? finalText = null,Object? error = freezed,Object? errorCode = freezed,Object? errorRecoverable = null,Object? localeId = freezed,Object? isPreferredLocale = null,Object? localeWarning = freezed,Object? availableLocaleCount = null,Object? sessionCount = null,Object? soundLevelEvents = null,Object? soundLevel = freezed,Object? minSoundLevel = freezed,Object? maxSoundLevel = freezed,Object? log = null,}) {
  return _then(_SpeechRecognitionState(
initialized: null == initialized ? _self.initialized : initialized // ignore: cast_nullable_to_non_nullable
as bool,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,permissionGranted: freezed == permissionGranted ? _self.permissionGranted : permissionGranted // ignore: cast_nullable_to_non_nullable
as bool?,recognizerMissing: null == recognizerMissing ? _self.recognizerMissing : recognizerMissing // ignore: cast_nullable_to_non_nullable
as bool,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,isListening: null == isListening ? _self.isListening : isListening // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,partialText: null == partialText ? _self.partialText : partialText // ignore: cast_nullable_to_non_nullable
as String,finalText: null == finalText ? _self.finalText : finalText // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,errorRecoverable: null == errorRecoverable ? _self.errorRecoverable : errorRecoverable // ignore: cast_nullable_to_non_nullable
as bool,localeId: freezed == localeId ? _self.localeId : localeId // ignore: cast_nullable_to_non_nullable
as String?,isPreferredLocale: null == isPreferredLocale ? _self.isPreferredLocale : isPreferredLocale // ignore: cast_nullable_to_non_nullable
as bool,localeWarning: freezed == localeWarning ? _self.localeWarning : localeWarning // ignore: cast_nullable_to_non_nullable
as String?,availableLocaleCount: null == availableLocaleCount ? _self.availableLocaleCount : availableLocaleCount // ignore: cast_nullable_to_non_nullable
as int,sessionCount: null == sessionCount ? _self.sessionCount : sessionCount // ignore: cast_nullable_to_non_nullable
as int,soundLevelEvents: null == soundLevelEvents ? _self.soundLevelEvents : soundLevelEvents // ignore: cast_nullable_to_non_nullable
as int,soundLevel: freezed == soundLevel ? _self.soundLevel : soundLevel // ignore: cast_nullable_to_non_nullable
as double?,minSoundLevel: freezed == minSoundLevel ? _self.minSoundLevel : minSoundLevel // ignore: cast_nullable_to_non_nullable
as double?,maxSoundLevel: freezed == maxSoundLevel ? _self.maxSoundLevel : maxSoundLevel // ignore: cast_nullable_to_non_nullable
as double?,log: null == log ? _self._log : log // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
