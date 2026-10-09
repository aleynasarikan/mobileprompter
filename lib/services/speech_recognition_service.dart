import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:talker/talker.dart';
import 'package:cueline/core/debug_flags.dart';
import 'package:cueline/providers/talker_provider.dart';
import 'package:cueline/services/karaoke_timing_log.dart';
import 'package:cueline/services/native_continuous_speech.dart';

part 'speech_recognition_service.g.dart';

const String kPreferredSpeechLocaleId = 'tr_TR';
const String kEnglishSpeechLocaleId = 'en_US';

/// Turkish-first, English when the device or app language is English.
String defaultPreferredSpeechLocaleId([Locale? locale]) {
  final language = (locale ?? PlatformDispatcher.instance.locale).languageCode
      .toLowerCase();
  if (language == 'en') return kEnglishSpeechLocaleId;
  return kPreferredSpeechLocaleId;
}

/// Letters that only Turkish uses among the supported script languages.
final _turkishLetters = RegExp('[çğıöşüÇĞİÖŞÜ]');

/// Recognizer language for [script]: Turkish when the script is Turkish,
/// otherwise [defaultPreferredSpeechLocaleId]. The device language alone is
/// not enough: a Turkish script on an English device was recognized as
/// English and never matched.
String preferredSpeechLocaleIdForScript(String script, [Locale? locale]) {
  if (_turkishLetters.hasMatch(script)) return kPreferredSpeechLocaleId;
  return defaultPreferredSpeechLocaleId(locale);
}

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
  // The recognizer ended because nobody spoke. These may start another
  // session. error_client and error_busy are failed restarts, not silence.
  static const _silenceErrors = {'error_no_match', 'error_speech_timeout'};

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

  /// Gap after a final. Words spoken while no session runs are lost and the
  /// karaoke position stalls until the next partial, so this stays short.
  static const _finalRestartDelay = Duration(milliseconds: 60);
  static const _maxRestartDelay = Duration(milliseconds: 2400);
  static const _maxFailedRestarts = 5;

  // No listenFor/pauseFor: the plugin enforces them with its own stop(),
  // which can land mid-sentence and leave its end-of-speech timer running
  // into the next session (see [_restartAfterFinal]). The recognizer ends
  // sessions itself, and every final restarts one.

  final SpeechToText _speech;
  final Talker? _talker;
  final _events = StreamController<SpeechRecognitionEvent>.broadcast();

  bool _wantsListening = false;
  bool _continuous = true;
  String? _localeId;
  Timer? _restartTimer;
  int _failedRestarts = 0;
  int _consecutiveSilence = 0;
  bool _listenInFlight = false;
  bool _disposed = false;

  /// True after [pause] until [resume]/[start]/[stop]. Blocks restarts so a
  /// `done` from [SpeechToText.stop] cannot reopen the microphone in the
  /// background.
  bool _enginePaused = false;

  /// Incremented once per [_listen] call that actually starts a session.
  int _generation = 0;

  /// Session that already has a restart timer. A second done/error for that
  /// same session does not schedule another one.
  int? _restartArmedFor;

  /// The current session ended with a final, not silence or an error.
  bool _endedWithFinal = false;

  SpeechRecognitionService({SpeechToText? speech, this._talker})
    : _speech = speech ?? SpeechToText();

  /// The engine keeps one session across sentences and restarts natively;
  /// a final must not end it.
  bool get _sessionSpansFinals => _speech is NativeContinuousSpeech;

  Stream<SpeechRecognitionEvent> get events => _events.stream;

  bool get isAvailable => _speech.isAvailable;

  bool get isListening => _speech.isListening;

  /// True between [start] and [stop], including [pause] and the short gaps
  /// while a continuous session restarts.
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
        onStatus: (status) => _onStatus(status, _generation),
        onError: (error) => _onError(error, _generation),
        debugLogging: kKaraokeDebugTools,
      );
      // The plugin only registers listeners on its first successful
      // initialization. [_listen] replaces these with a session-scoped pair.
      _speech.statusListener = (status) => _onStatus(status, _generation);
      _speech.errorListener = (error) => _onError(error, _generation);
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
    String? preferredLocaleId,
  }) async {
    preferredLocaleId ??= defaultPreferredSpeechLocaleId();
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
    _enginePaused = false;
    _failedRestarts = 0;
    _consecutiveSilence = 0;
    await _listen();
  }

  /// Stops listening; the recognizer still delivers a final result.
  Future<void> stop() async {
    _wantsListening = false;
    _enginePaused = false;
    _restartTimer?.cancel();
    _restartArmedFor = null;
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

  /// Stops the recognizer without ending the run. [isActive] stays true so
  /// karaoke following does not fall back to auto-scroll during a brief
  /// background pause. Call [resume] or [stop] next.
  Future<void> pause() async {
    _enginePaused = true;
    _restartTimer?.cancel();
    _restartArmedFor = null;
    try {
      await _speech.stop();
    } on PlatformException catch (e) {
      _emitFailure(
        'pause failed: ${e.message}',
        code: e.code,
        recoverable: true,
      );
    }
  }

  /// Resumes with the locale and mode of the last [start].
  Future<void> resume() async {
    if (!_speech.isAvailable) return;
    _enginePaused = false;
    _wantsListening = true;
    _failedRestarts = 0;
    _consecutiveSilence = 0;
    await _listen();
  }

  /// Stops listening and discards any pending result.
  Future<void> cancel() async {
    _wantsListening = false;
    _enginePaused = false;
    _restartTimer?.cancel();
    _restartArmedFor = null;
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
    _disposed = true;
    await cancel();
    await _events.close();
  }

  Future<void> _listen() async {
    _restartTimer?.cancel();
    if (_disposed ||
        _enginePaused ||
        !_wantsListening ||
        _speech.isListening ||
        _listenInFlight) {
      return;
    }
    final session = ++_generation;
    KaraokeTimingLog.listenStarted(session);
    _restartArmedFor = null;
    _endedWithFinal = false;
    _speech.statusListener = (status) => _onStatus(status, session);
    _speech.errorListener = (error) => _onError(error, session);
    _diagnose(
      'listen(locale: ${_localeId ?? 'default'}, partialResults: true)',
    );
    _listenInFlight = true;
    try {
      await _speech.listen(
        onResult: (result) => _onResult(result, session),
        onSoundLevelChange: _onSoundLevel,
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } on ListenFailedException catch (e) {
      _failedRestarts++;
      final willRetry = _canRestart;
      if (!willRetry) _closeListening();
      _emitFailure(
        'listen failed: ${e.message} ${e.details ?? ''}'.trim(),
        code: listenFailedCode,
        recoverable: willRetry,
      );
      if (willRetry) _armRestart(session);
    } on SpeechToTextNotInitializedException {
      _closeListening();
      _emitFailure(
        'Speech recognition is not initialized.',
        code: initFailedCode,
        recoverable: false,
      );
    } finally {
      _listenInFlight = false;
    }
  }

  /// After a final the plugin drops every later result of the session, and
  /// Google's continuous recognizer may keep the session open, so it is
  /// ended right away and the next one starts after [_restartDelay].
  ///
  /// It is cancelled, not stopped: a stop while the speaker is already on
  /// the next sentence makes the recognizer report end of speech afterwards,
  /// and the plugin's end-of-speech timer then marks the *next* session as
  /// not listening while the recognizer still runs it. Every later listen
  /// fails with error_client. The final is already delivered, so cancel
  /// loses nothing. The `done` this causes arms the same restart, which
  /// [_armRestart] schedules only once per session.
  Future<void> _restartAfterFinal(int session) async {
    if (session != _generation || !_canRestart) return;
    if (_speech.isListening) {
      try {
        await _speech.cancel();
      } on PlatformException catch (e) {
        _diagnose('cancel after final failed: ${e.code}: ${e.message}');
      }
    }
    _armRestart(session);
  }

  bool get _canRestart =>
      !_enginePaused &&
      _wantsListening &&
      _continuous &&
      _failedRestarts < _maxFailedRestarts;

  /// Schedules at most one restart for [session]. Callbacks from an older
  /// session, and a second callback from this session, do not call listen.
  void _armRestart(int session) {
    if (session != _generation) return;
    if (_disposed || !_canRestart) return;
    if (_speech.isListening) return;
    if (_restartArmedFor == session) return;
    _restartArmedFor = session;
    _restartTimer?.cancel();
    final delay = _delayForRestart();
    _diagnose('scheduling restart in ${delay.inMilliseconds}ms');
    _restartTimer = Timer(delay, () {
      if (_restartArmedFor == session) _restartArmedFor = null;
      if (_disposed ||
          session != _generation ||
          !_wantsListening ||
          _speech.isListening) {
        return;
      }
      _listen();
    });
  }

  /// Silence timeouts are retried, but the gap grows so an empty-session
  /// loop does not hammer the recognizer or the battery.
  Duration _delayForRestart() {
    if (_endedWithFinal) return _finalRestartDelay;
    if (_consecutiveSilence <= 1) return _restartDelay;
    final shift = (_consecutiveSilence - 1).clamp(1, 3);
    final ms = _restartDelay.inMilliseconds * (1 << shift);
    return Duration(
      milliseconds: ms.clamp(
        _restartDelay.inMilliseconds,
        _maxRestartDelay.inMilliseconds,
      ),
    );
  }

  void _closeListening() {
    _wantsListening = false;
    _restartTimer?.cancel();
    _restartArmedFor = null;
  }

  void _onStatus(String status, int session) {
    if (session != _generation) return;
    if (status == SpeechToText.listeningStatus) {
      KaraokeTimingLog.statusListening(session);
    } else if (status == SpeechToText.notListeningStatus) {
      KaraokeTimingLog.notListening(session);
    } else if (status == SpeechToText.doneStatus) {
      KaraokeTimingLog.done(session);
    } else {
      KaraokeTimingLog.statusOther(status, session);
    }
    _talker?.debug('Speech status: $status');
    final isListening = status == SpeechToText.listeningStatus;
    _add(SpeechListeningChanged(isListening: isListening, status: status));
    if (status == SpeechToText.doneStatus) _armRestart(session);
  }

  void _onError(SpeechRecognitionError error, int session) {
    if (session != _generation) return;
    _talker?.warning(
      'Speech error: ${error.errorMsg} (permanent: ${error.permanent})',
    );
    if (_fatalErrors.contains(error.errorMsg)) _wantsListening = false;
    if (_silenceErrors.contains(error.errorMsg)) {
      _consecutiveSilence++;
    } else {
      _failedRestarts++;
      _consecutiveSilence = 0;
    }

    final willRestart = _canRestart;
    // Set before the event so listeners observe the closed session.
    if (!willRestart) _closeListening();
    _emitFailure(
      _describeError(error.errorMsg),
      code: error.errorMsg,
      recoverable: willRestart,
    );
    if (willRestart) _armRestart(session);
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

  void _onResult(SpeechRecognitionResult result, int session) {
    // Drop callbacks from a session that already ended. A delayed final
    // from the previous listen must not move karaoke or arm another restart.
    if (session != _generation) return;
    // A recognized word means this session is healthy. `listening` alone is
    // not: the plugin reports it as soon as startListening is posted, before
    // a client/busy failure, and resetting there made the cap unreachable.
    if (result.recognizedWords.isNotEmpty) {
      _failedRestarts = 0;
      _consecutiveSilence = 0;
    }
    if (result.finalResult) {
      KaraokeTimingLog.finalResult(result.recognizedWords, session);
    } else {
      KaraokeTimingLog.partial(result.recognizedWords, session);
    }
    _add(
      SpeechResult(
        text: result.recognizedWords,
        isFinal: result.finalResult,
        confidence: result.confidence,
      ),
    );
    if (result.finalResult && !_sessionSpansFinals) {
      _endedWithFinal = true;
      unawaited(_restartAfterFinal(session));
    }
  }

  void _emitFailure(
    String message, {
    required String code,
    required bool recoverable,
  }) {
    KaraokeTimingLog.error(code, _generation);
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
  final service = SpeechRecognitionService(
    talker: ref.read(talkerProvider),
    speech: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? NativeContinuousSpeech()
        : null,
  );
  ref.onDispose(service.dispose);
  return service;
}
