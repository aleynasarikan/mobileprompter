import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:talker/talker.dart';
import 'package:tiefprompt/providers/talker_provider.dart';

part 'speech_recognition_service.g.dart';

const String kPreferredSpeechLocaleId = 'tr_TR';

sealed class SpeechRecognitionEvent {
  const SpeechRecognitionEvent();
}

class SpeechListeningChanged extends SpeechRecognitionEvent {
  final bool isListening;
  final String status;

  const SpeechListeningChanged({
    required this.isListening,
    required this.status,
  });
}

class SpeechResult extends SpeechRecognitionEvent {
  final String text;
  final bool isFinal;
  final double confidence;

  const SpeechResult({
    required this.text,
    required this.isFinal,
    required this.confidence,
  });
}

class SpeechFailure extends SpeechRecognitionEvent {
  /// Plugin error (`error_*`), platform exception code or one of the
  /// `SpeechRecognitionService.*Code` constants.
  final String code;
  final String message;

  /// True when listening continues (e.g. silence timeouts in continuous mode).
  final bool recoverable;

  const SpeechFailure({
    required this.code,
    required this.message,
    required this.recoverable,
  });
}

/// Input level reported by the recognizer (Android `onRmsChanged`, roughly
/// -2 dB for silence up to ~10 dB for loud speech).
class SpeechSoundLevel extends SpeechRecognitionEvent {
  final double level;

  const SpeechSoundLevel(this.level);
}

/// Informational message for the debug log.
class SpeechDiagnostic extends SpeechRecognitionEvent {
  final String message;

  const SpeechDiagnostic(this.message);
}

class SpeechLocaleResolution {
  /// Locale passed to the recognizer; null means the recognizer's default.
  final String? localeId;
  final bool isPreferred;
  final String? warning;
  final List<String> availableLocaleIds;

  const SpeechLocaleResolution({
    required this.localeId,
    required this.isPreferred,
    required this.availableLocaleIds,
    this.warning,
  });
}

/// Wraps the `speech_to_text` plugin. The plugin's [SpeechToText] is a
/// process-wide singleton, so only one instance of this service should exist.
class SpeechRecognitionService {
  // Android reports these when the user is silent or a session ends; in
  // continuous mode they only mean "start a new session".
  static const _silenceErrors = {
    'error_no_match',
    'error_speech_timeout',
    'error_client',
    'error_busy',
  };

  static const _fatalErrors = {
    'error_permission',
    'error_insufficient_permissions',
    'error_language_not_supported',
    'error_language_unavailable',
    'error_audio_error',
  };

  static const permissionDeniedCode = 'permission_denied';
  static const recognizerNotAvailableCode = 'recognizerNotAvailable';
  static const initFailedCode = 'init_failed';
  static const listenFailedCode = 'listen_failed';

  static const _restartDelay = Duration(milliseconds: 300);
  static const _maxFailedRestarts = 5;

  /// Upper bound for one recognizer session; Android usually ends it earlier.
  static const listenFor = Duration(seconds: 60);

  /// Silence allowed before a session ends.
  static const pauseFor = Duration(seconds: 2);

  final SpeechToText _speech;
  final Talker? _talker;
  final _events = StreamController<SpeechRecognitionEvent>.broadcast();

  bool _wantsListening = false;
  bool _continuous = true;
  String? _localeId;
  Timer? _restartTimer;
  int _failedRestarts = 0;
  bool _listenInFlight = false;
  bool _stopInFlight = false;

  SpeechRecognitionService({SpeechToText? speech, this._talker})
    : _speech = speech ?? SpeechToText();

  Stream<SpeechRecognitionEvent> get events => _events.stream;

  bool get isAvailable => _speech.isAvailable;

  bool get isListening => _speech.isListening;

  /// True between [start]/[resume] and [stop]/[pause], including the short
  /// gaps while a continuous session restarts.
  bool get isActive => _wantsListening;

  String? get localeId => _localeId;

  /// Whether RECORD_AUDIO is currently granted (does not prompt).
  Future<bool> hasPermission() async {
    try {
      return await _speech.hasPermission;
    } on PlatformException catch (e) {
      _diagnose('hasPermission failed: ${e.code}: ${e.message}');
      return false;
    }
  }

  /// Requests the microphone permission on first use.
  ///
  /// On Android the plugin returns false when the permission is denied and
  /// throws [recognizerNotAvailableCode] when no RecognitionService exists.
  Future<bool> initialize() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: kDebugMode,
      );
      // The plugin only registers listeners on its first successful
      // initialization.
      _speech.statusListener = _onStatus;
      _speech.errorListener = _onError;
      _talker?.info('Speech recognition available: $available');
      _diagnose('initialize() -> $available');
      if (!available) {
        if (await hasPermission()) {
          _emitFailure(
            'initialize() returned false although RECORD_AUDIO is granted.',
            code: initFailedCode,
            recoverable: false,
          );
        } else {
          _emitFailure(
            'Microphone permission (RECORD_AUDIO) denied.',
            code: permissionDeniedCode,
            recoverable: false,
          );
        }
      }
      return available;
    } on PlatformException catch (e) {
      _emitFailure(
        e.code == recognizerNotAvailableCode
            ? 'No Android RecognitionService found on this device '
                  '(${e.message}).'
            : '${e.message}',
        code: e.code,
        recoverable: false,
      );
      return false;
    }
  }

  Future<SpeechLocaleResolution> resolveLocale({
    String preferredLocaleId = kPreferredSpeechLocaleId,
  }) async {
    final locales = await _speech.locales();
    final ids = locales.map((l) => l.localeId).toList();
    final preferred = _normalize(preferredLocaleId);
    final language = preferred.split('_').first;

    if (ids.firstWhereOrNull((id) => _normalize(id) == preferred)
        case final id?) {
      return SpeechLocaleResolution(
        localeId: id,
        isPreferred: true,
        availableLocaleIds: ids,
      );
    }

    if (ids.firstWhereOrNull(
          (id) => _normalize(id).split('_').first == language,
        )
        case final id?) {
      return SpeechLocaleResolution(
        localeId: id,
        isPreferred: false,
        availableLocaleIds: ids,
        warning: '$preferredLocaleId not listed, using $id.',
      );
    }

    // Some recognizers (e.g. recent Google app versions) do not report their
    // languages; they usually still accept the requested one.
    if (ids.isEmpty) {
      return SpeechLocaleResolution(
        localeId: preferredLocaleId,
        isPreferred: true,
        availableLocaleIds: ids,
        warning:
            'Recognizer did not report its locales; requesting '
            '$preferredLocaleId anyway.',
      );
    }

    final system = await _speech.systemLocale();
    return SpeechLocaleResolution(
      localeId: system?.localeId,
      isPreferred: false,
      availableLocaleIds: ids,
      warning:
          '$preferredLocaleId is not available on this device, using '
          '${system?.localeId ?? 'the recognizer default'}.',
    );
  }

  Future<void> start({String? localeId, bool continuous = true}) async {
    if (!_speech.isAvailable && !await initialize()) return;
    _localeId = localeId;
    _continuous = continuous;
    _wantsListening = true;
    _failedRestarts = 0;
    await _listen();
  }

  /// Stops listening; the recognizer still delivers a final result.
  Future<void> stop() async {
    _wantsListening = false;
    _restartTimer?.cancel();
    try {
      await _speech.stop();
    } on PlatformException catch (e) {
      _emitFailure(
        'stop failed: ${e.message}',
        code: e.code,
        recoverable: false,
      );
    }
  }

  Future<void> pause() => stop();

  /// Resumes with the locale and mode of the last [start].
  Future<void> resume() async {
    if (!_speech.isAvailable) return;
    _wantsListening = true;
    _failedRestarts = 0;
    await _listen();
  }

  /// Stops listening and discards any pending result.
  Future<void> cancel() async {
    _wantsListening = false;
    _restartTimer?.cancel();
    try {
      await _speech.cancel();
    } on PlatformException catch (e) {
      _emitFailure(
        'cancel failed: ${e.message}',
        code: e.code,
        recoverable: false,
      );
    }
  }

  Future<void> dispose() async {
    await cancel();
    await _events.close();
  }

  Future<void> _listen() async {
    _restartTimer?.cancel();
    if (!_wantsListening ||
        _speech.isListening ||
        _listenInFlight ||
        _stopInFlight) {
      return;
    }
    _diagnose(
      'listen(locale: ${_localeId ?? 'default'}, partialResults: true, '
      'listenFor: ${listenFor.inSeconds}s, pauseFor: ${pauseFor.inSeconds}s)',
    );
    _listenInFlight = true;
    try {
      await _speech.listen(
        onResult: _onResult,
        onSoundLevelChange: _onSoundLevel,
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          partialResults: true,
          cancelOnError: false,
          listenFor: listenFor,
          pauseFor: pauseFor,
        ),
      );
    } on ListenFailedException catch (e) {
      _failedRestarts++;
      final willRetry = _canRestart;
      _emitFailure(
        'listen failed: ${e.message} ${e.details ?? ''}'.trim(),
        code: listenFailedCode,
        recoverable: willRetry,
      );
      if (willRetry) {
        _scheduleRestart();
      } else {
        _wantsListening = false;
      }
    } on SpeechToTextNotInitializedException {
      _wantsListening = false;
      _emitFailure(
        'Speech recognition is not initialized.',
        code: initFailedCode,
        recoverable: false,
      );
    } finally {
      _listenInFlight = false;
    }
  }

  /// Android's recognizer ends its session with a final result, but the
  /// plugin drops all later results and keeps reporting "listening" until
  /// its pause timer fires. Ending the session right away lets the next one
  /// start after [_restartDelay].
  Future<void> _restartAfterFinal() async {
    if (!_canRestart || _stopInFlight) return;
    _restartTimer?.cancel();
    _diagnose('final result: restarting session');
    _stopInFlight = true;
    try {
      await _speech.stop();
    } on PlatformException catch (e) {
      _diagnose('stop after final failed: ${e.code}: ${e.message}');
    } finally {
      _stopInFlight = false;
    }
    // The `done` status emitted by the stop may already have scheduled a
    // restart; this replaces it, so only one listen() follows.
    _scheduleRestart();
  }

  bool get _canRestart =>
      _wantsListening && _continuous && _failedRestarts < _maxFailedRestarts;

  void _scheduleRestart() {
    if (!_canRestart) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(_restartDelay, _listen);
  }

  void _onStatus(String status) {
    _talker?.debug('Speech status: $status');
    final isListening = status == SpeechToText.listeningStatus;
    if (isListening) _failedRestarts = 0;
    _add(SpeechListeningChanged(isListening: isListening, status: status));
    if (status == SpeechToText.doneStatus) _scheduleRestart();
  }

  void _onError(SpeechRecognitionError error) {
    _talker?.warning(
      'Speech error: ${error.errorMsg} (permanent: ${error.permanent})',
    );
    if (_fatalErrors.contains(error.errorMsg)) _wantsListening = false;
    if (!_silenceErrors.contains(error.errorMsg)) _failedRestarts++;

    final willRestart = _canRestart;
    _emitFailure(
      _describeError(error.errorMsg),
      code: error.errorMsg,
      recoverable: willRestart,
    );
    if (willRestart) {
      _scheduleRestart();
    } else {
      _wantsListening = false;
    }
  }

  static String _describeError(String code) => switch (code) {
    // The plugin turns no_match into speech_timeout when the input level
    // never reached its speech threshold.
    'error_speech_timeout' => 'No speech detected (input level stayed low).',
    'error_no_match' => 'Audio heard but nothing recognized.',
    'error_audio_error' => 'Audio recording error.',
    'error_permission' ||
    'error_insufficient_permissions' => 'Microphone permission missing.',
    'error_network' || 'error_network_timeout' => 'Network error.',
    'error_server' || 'error_server_disconnected' => 'Recognizer server error.',
    'error_language_not_supported' => 'Locale not supported by recognizer.',
    'error_language_unavailable' => 'Locale not downloaded / unavailable.',
    'error_busy' => 'Recognizer busy.',
    'error_client' => 'Recognizer client error.',
    _ => code,
  };

  void _onSoundLevel(double level) => _add(SpeechSoundLevel(level));

  void _onResult(SpeechRecognitionResult result) {
    _add(
      SpeechResult(
        text: result.recognizedWords,
        isFinal: result.finalResult,
        confidence: result.confidence,
      ),
    );
    if (result.finalResult) unawaited(_restartAfterFinal());
  }

  void _emitFailure(
    String message, {
    required String code,
    required bool recoverable,
  }) {
    _add(SpeechFailure(code: code, message: message, recoverable: recoverable));
  }

  void _diagnose(String message) {
    _talker?.debug('Speech: $message');
    _add(SpeechDiagnostic(message));
  }

  void _add(SpeechRecognitionEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  static String _normalize(String localeId) =>
      localeId.replaceAll('-', '_').toLowerCase();
}

extension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

@Riverpod(keepAlive: true)
SpeechRecognitionService speechRecognitionService(Ref ref) {
  final service = SpeechRecognitionService(talker: ref.read(talkerProvider));
  ref.onDispose(service.dispose);
  return service;
}
