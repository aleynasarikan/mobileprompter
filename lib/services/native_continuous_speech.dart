import 'dart:async';

import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Android listening without a restart after every sentence.
///
/// The `speech_to_text` plugin ends its session after each final result, and
/// every new session plays the recognizer's start beep. The native
/// `ContinuousSpeech` keeps one run open (segmented session on Android 13+,
/// silent native restarts otherwise) and reports it as a single session:
/// `listening` once, results, `done` only after [stop], [cancel] or a fatal
/// error.
///
/// Permission, availability and locales still come from the plugin.
class NativeContinuousSpeech extends SpeechToText {
  static const _channelName = 'app.cueline.teleprompter/continuous_speech';

  NativeContinuousSpeech({
    SpeechToText? plugin,
    MethodChannel? methods,
    EventChannel? events,
  }) : _plugin = plugin ?? SpeechToText(),
       _methods = methods ?? const MethodChannel(_channelName),
       _events = events ?? const EventChannel('$_channelName/events'),
       // The only non-singleton constructor. Every channel-backed member is
       // overridden, so the plugin's own channel is never used through this.
       // ignore: invalid_use_of_visible_for_testing_member
       super.withMethodChannel();

  final SpeechToText _plugin;
  final MethodChannel _methods;
  final EventChannel _events;

  StreamSubscription<dynamic>? _subscription;
  SpeechResultListener? _onResult;
  SpeechSoundLevelChange? _onSoundLevel;
  bool _listening = false;

  @override
  bool get isAvailable => _plugin.isAvailable;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> get hasPermission => _plugin.hasPermission;

  @override
  Future<List<LocaleName>> locales() => _plugin.locales();

  @override
  Future<LocaleName?> systemLocale() => _plugin.systemLocale();

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    errorListener = onError;
    statusListener = onStatus;
    _subscribe();
    // Requests RECORD_AUDIO and checks for a recognition service.
    return _plugin.initialize(debugLogging: debugLogging);
  }

  @override
  Future listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    if (!isAvailable) throw SpeechToTextNotInitializedException();
    // The plugin may have been initialized before this wrapper existed.
    _subscribe();
    _onResult = onResult;
    _onSoundLevel = onSoundLevelChange;
    try {
      await _methods.invokeMethod<void>('start', {
        'localeId': listenOptions?.localeId ?? localeId,
      });
    } on PlatformException catch (e) {
      throw ListenFailedException(e.message, e.details?.toString());
    }
  }

  @override
  Future<void> stop() async {
    _listening = false;
    await _methods.invokeMethod<void>('stop');
  }

  @override
  Future<void> cancel() async {
    _listening = false;
    await _methods.invokeMethod<void>('cancel');
  }

  void _subscribe() {
    _subscription ??= _events.receiveBroadcastStream().listen(_onEvent);
  }

  void _onEvent(dynamic raw) {
    if (raw is! Map) return;
    switch (raw['type']) {
      case 'status':
        final status = raw['status'] as String;
        _listening = status == SpeechToText.listeningStatus;
        statusListener?.call(status);
      case 'result':
        final isFinal = raw['final'] == true;
        _onResult?.call(
          SpeechRecognitionResult([
            SpeechRecognitionWords(
              raw['text'] as String,
              null,
              (raw['confidence'] as num?)?.toDouble() ?? -1,
            ),
          ], (isFinal ? ResultType.finalResult : ResultType.partial).value),
        );
      case 'level':
        _onSoundLevel?.call((raw['level'] as num).toDouble());
      case 'error':
        _listening = false;
        errorListener?.call(
          SpeechRecognitionError(raw['code'] as String, true),
        );
    }
  }
}
