import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Records listen/stop and keeps each session's callbacks so a late event
/// can be delivered to the session it belongs to.
class FakeSpeechToText extends SpeechToText {
  FakeSpeechToText() : super.withMethodChannel();

  var _available = true;
  var _listening = false;
  bool grantPermission = true;
  bool availableOnInit = true;
  int listenCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  String? lastLocaleId;
  final List<_CapturedSession> _sessions = [];

  @override
  bool get isAvailable => _available;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> get hasPermission async => grantPermission;

  @override
  Future<List<LocaleName>> locales() async => [
    LocaleName('tr_TR', 'Türkçe'),
    LocaleName('en_US', 'English'),
  ];

  @override
  Future<LocaleName?> systemLocale() async => LocaleName('tr_TR', 'Türkçe');

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
    _available = availableOnInit;
    return availableOnInit;
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
    listenCount++;
    lastLocaleId = listenOptions?.localeId ?? localeId;
    final session = _CapturedSession(
      onResult: onResult,
      onStatus: statusListener,
      onError: errorListener,
    );
    _sessions.add(session);
    _listening = true;
    session.onStatus?.call(SpeechToText.listeningStatus);
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _listening = false;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    _listening = false;
  }

  void emitResult(String text, {required bool isFinal, int? session}) {
    _session(session).onResult?.call(
      SpeechRecognitionResult([
        SpeechRecognitionWords(text, null, 1),
      ], (isFinal ? ResultType.finalResult : ResultType.partial).value),
    );
  }

  void emitStatus(String status, {int? session}) {
    final index = session ?? _sessions.length - 1;
    if (index == _sessions.length - 1) {
      if (status == SpeechToText.listeningStatus) _listening = true;
      if (status == SpeechToText.doneStatus ||
          status == SpeechToText.notListeningStatus) {
        _listening = false;
      }
    }
    _sessions[index].onStatus?.call(status);
  }

  void emitError(String code, {int? session}) {
    _listening = false;
    _session(session).onError?.call(SpeechRecognitionError(code, true));
  }

  _CapturedSession _session(int? session) =>
      _sessions[session ?? _sessions.length - 1];
}

class _CapturedSession {
  final SpeechResultListener? onResult;
  final SpeechStatusListener? onStatus;
  final SpeechErrorListener? onError;

  const _CapturedSession({this.onResult, this.onStatus, this.onError});
}
