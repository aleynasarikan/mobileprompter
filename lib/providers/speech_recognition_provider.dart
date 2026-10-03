import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tiefprompt/services/speech_recognition_service.dart';

part 'speech_recognition_provider.freezed.dart';
part 'speech_recognition_provider.g.dart';

@freezed
abstract class SpeechRecognitionState with _$SpeechRecognitionState {
  const SpeechRecognitionState._();

  const factory SpeechRecognitionState({
    @Default(false) bool initialized,
    @Default(false) bool available,

    /// Null until checked.
    bool? permissionGranted,

    /// The plugin found no Android RecognitionService.
    @Default(false) bool recognizerMissing,

    /// The user wants to listen; stays true while a continuous session
    /// restarts.
    @Default(false) bool isActive,

    /// The plugin reports listening as soon as `startListening` is posted, so
    /// this does not prove that audio is captured; see [soundLevelEvents].
    @Default(false) bool isListening,
    @Default('') String status,
    @Default('') String partialText,

    /// All final results of the current run, joined with spaces.
    @Default('') String finalText,
    String? error,
    String? errorCode,
    @Default(false) bool errorRecoverable,
    String? localeId,
    @Default(false) bool isPreferredLocale,
    String? localeWarning,
    @Default(0) int availableLocaleCount,

    /// Recognizer sessions started since the last [SpeechRecognition.start].
    @Default(0) int sessionCount,

    /// Input level statistics since the last [SpeechRecognition.start].
    @Default(0) int soundLevelEvents,
    double? soundLevel,
    double? minSoundLevel,
    double? maxSoundLevel,

    /// Newest first.
    @Default(<String>[]) List<String> log,
  }) = _SpeechRecognitionState;

  /// The recognizer reports roughly -2 dB for digital silence; a range this
  /// small means no real audio reaches it.
  static const flatSignalRange = 1.0;

  /// The plugin's own threshold for "speech was heard".
  static const speechLevel = 9.0;

  bool get isSignalFlat =>
      minSoundLevel != null &&
      maxSoundLevel! - minSoundLevel! < flatSignalRange;
}

@riverpod
class SpeechRecognition extends _$SpeechRecognition {
  static const _maxLogEntries = 50;

  late SpeechRecognitionService _service;

  @override
  SpeechRecognitionState build() {
    _service = ref.watch(speechRecognitionServiceProvider);
    final subscription = _service.events.listen(_onEvent);
    ref.onDispose(() {
      subscription.cancel();
      _service.cancel();
    });
    return const SpeechRecognitionState();
  }

  Future<bool> initialize() async {
    final available = await _service.initialize();
    if (!ref.mounted) return false;
    final permission = await _service.hasPermission();
    if (!ref.mounted) return false;
    _log('RECORD_AUDIO granted: $permission');
    if (!available) {
      state = state.copyWith(
        initialized: true,
        available: false,
        permissionGranted: permission,
        error: state.error ?? 'Speech recognition is not available.',
        errorRecoverable: false,
      );
      return false;
    }

    final locale = await _service.resolveLocale();
    if (!ref.mounted) return false;
    _log(
      'locale: ${locale.localeId} (preferred: ${locale.isPreferred}, '
      'reported: ${locale.availableLocaleIds.length})',
    );
    state = state.copyWith(
      initialized: true,
      available: true,
      permissionGranted: permission,
      recognizerMissing: false,
      localeId: locale.localeId,
      isPreferredLocale: locale.isPreferred,
      localeWarning: locale.warning,
      availableLocaleCount: locale.availableLocaleIds.length,
    );
    return true;
  }

  Future<void> start() async {
    if (!state.available && !await initialize()) return;
    if (!ref.mounted) return;
    state = state.copyWith(
      isActive: true,
      partialText: '',
      finalText: '',
      error: null,
      errorCode: null,
      sessionCount: 0,
      soundLevelEvents: 0,
      soundLevel: null,
      minSoundLevel: null,
      maxSoundLevel: null,
    );
    _log('start');
    await _service.start(localeId: state.localeId);
  }

  Future<void> stop() async {
    state = state.copyWith(isActive: false);
    _log('stop');
    await _service.stop();
  }

  Future<void> toggle() => _service.isActive ? stop() : start();

  void _onEvent(SpeechRecognitionEvent event) {
    switch (event) {
      case SpeechListeningChanged(:final isListening, :final status):
        _log('status: $status');
        state = state.copyWith(
          isListening: isListening,
          status: status,
          isActive: _service.isActive,
          sessionCount: state.sessionCount + (isListening ? 1 : 0),
        );
      case SpeechResult(:final text, isFinal: false):
        state = state.copyWith(partialText: text, error: null, errorCode: null);
      case SpeechResult(:final text, isFinal: true, :final confidence):
        _log('final: "$text" (confidence $confidence)');
        state = state.copyWith(
          partialText: '',
          finalText: [
            state.finalText,
            text,
          ].where((s) => s.isNotEmpty).join(' '),
          error: null,
          errorCode: null,
        );
      case SpeechFailure(:final code, :final message, :final recoverable):
        _log('error: $code — $message${recoverable ? ' (restarting)' : ''}');
        state = state.copyWith(
          error: message,
          errorCode: code,
          errorRecoverable: recoverable,
          isActive: _service.isActive,
          permissionGranted:
              code == SpeechRecognitionService.permissionDeniedCode ||
                  code == 'error_permission' ||
                  code == 'error_insufficient_permissions'
              ? false
              : state.permissionGranted,
          recognizerMissing:
              state.recognizerMissing ||
              code == SpeechRecognitionService.recognizerNotAvailableCode,
        );
      case SpeechSoundLevel(:final level):
        final min = state.minSoundLevel;
        final max = state.maxSoundLevel;
        state = state.copyWith(
          soundLevelEvents: state.soundLevelEvents + 1,
          soundLevel: level,
          minSoundLevel: min == null || level < min ? level : min,
          maxSoundLevel: max == null || level > max ? level : max,
        );
      case SpeechDiagnostic(:final message):
        _log(message);
    }
  }

  void _log(String message) {
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${(now.millisecond ~/ 100)}';
    state = state.copyWith(
      log: ['$time $message', ...state.log.take(_maxLogEntries - 1)],
    );
  }
}
