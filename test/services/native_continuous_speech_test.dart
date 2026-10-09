import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cueline/services/native_continuous_speech.dart';
import 'package:cueline/services/speech_recognition_service.dart';

import '../helpers/fake_speech_to_text.dart';

const _channel = MethodChannel('app.cueline.teleprompter/continuous_speech');
const _events = EventChannel(
  'app.cueline.teleprompter/continuous_speech/events',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;
  late MockStreamHandlerEventSink sink;
  late SpeechRecognitionService service;

  setUp(() {
    calls = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call.method);
      return null;
    });
    messenger.setMockStreamHandler(
      _events,
      MockStreamHandler.inline(
        onListen: (_, events) {
          sink = events;
        },
      ),
    );
    service = SpeechRecognitionService(
      speech: NativeContinuousSpeech(plugin: FakeSpeechToText()),
    );
  });

  tearDown(() => service.dispose());

  // The native side keeps one session across sentences. Ending it after a
  // final would bring back the beep and the blinking microphone.
  test('a final keeps the native session running', () async {
    final results = <SpeechResult>[];
    final subscription = service.events.listen((event) {
      if (event is SpeechResult) results.add(event);
    });

    await service.start(localeId: 'tr_TR');
    await _settle(); // the event channel subscribes asynchronously
    sink.success({'type': 'status', 'status': 'listening'});
    sink.success({
      'type': 'result',
      'text': 'merhaba',
      'final': false,
      'confidence': -1.0,
    });
    sink.success({
      'type': 'result',
      'text': 'merhaba dünya',
      'final': true,
      'confidence': 0.9,
    });
    await _settle();

    expect(calls, ['start'], reason: 'no cancel or second start after final');
    expect(service.isListening, isTrue);
    expect(results.map((r) => (r.text, r.isFinal)), [
      ('merhaba', false),
      ('merhaba dünya', true),
    ]);

    await service.stop();
    expect(calls, ['start', 'stop']);
    await subscription.cancel();
  });

  test('a fatal native error ends the run', () async {
    await service.start(localeId: 'tr_TR');
    await _settle(); // the event channel subscribes asynchronously
    sink.success({'type': 'status', 'status': 'listening'});
    sink.success({
      'type': 'error',
      'code': 'error_language_unavailable',
      'message': 'error_language_unavailable',
    });
    sink.success({'type': 'status', 'status': 'done'});
    await _settle();

    expect(service.isActive, isFalse);
    expect(calls, ['start']);
  });
}

/// Platform messages are delivered asynchronously, even when mocked.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));
