import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:cueline/services/karaoke_speech_follower.dart';
import 'package:cueline/services/speech_recognition_service.dart';
import 'package:cueline/ui/widgets/karaoke_text.dart';

import '../helpers/fake_speech_to_text.dart';

/// Same gap [SpeechRecognitionService] waits before calling listen again.
const _restartDelay = Duration(milliseconds: 300);

void main() {
  group('SpeechRecognitionService restarts', () {
    late FakeSpeechToText speech;
    late SpeechRecognitionService service;

    setUp(() {
      speech = FakeSpeechToText();
      service = SpeechRecognitionService(speech: speech);
    });

    tearDown(() => service.dispose());

    // On Android the plugin keeps reporting "listening" after a final and
    // drops the session's later results; Google's continuous recognizer may
    // never send `done` for it. Waiting for `done` left the microphone deaf
    // after every sentence.
    testWidgets('a final result opens the next session without waiting for '
        'done', (tester) async {
      await service.start();
      speech.emitResult('elma', isFinal: true);
      await tester.pump();

      expect(speech.cancelCount, 1, reason: 'the finished session is ended');
      expect(
        speech.stopCount,
        0,
        reason:
            'a stop mid-sentence leaves the plugin end-of-speech timer '
            'running into the next session',
      );
      await tester.pump(_restartDelay);
      expect(speech.listenCount, 2);

      // The `done` caused by that stop belongs to the old session.
      speech.emitStatus(SpeechToText.doneStatus, session: 0);
      await tester.pump(_restartDelay);
      expect(speech.listenCount, 2, reason: 'one final, one restart');
      expect(service.isActive, isTrue);
    });

    testWidgets('a final whose done already came restarts once', (
      tester,
    ) async {
      await service.start();
      speech.emitStatus(SpeechToText.notListeningStatus);
      speech.emitResult('elma', isFinal: true);
      speech.emitStatus(SpeechToText.doneStatus);
      await tester.pump(_restartDelay);
      await tester.pump(_restartDelay);

      expect(speech.cancelCount, 0, reason: 'nothing left to end');
      expect(speech.listenCount, 2);
    });

    testWidgets('continuous speech keeps one session per utterance', (
      tester,
    ) async {
      await service.start();
      for (var i = 0; i < 5; i++) {
        speech.emitResult('cümle $i', isFinal: false);
        speech.emitResult('cümle $i', isFinal: true);
        await tester.pump(_restartDelay);
      }
      expect(speech.listenCount, 6);
      expect(service.isActive, isTrue);
    });

    testWidgets('stop during the final does not reopen the microphone', (
      tester,
    ) async {
      await service.start();
      speech.emitResult('elma', isFinal: true);
      await service.stop();
      await tester.pump(_restartDelay);
      expect(speech.listenCount, 1);
      expect(service.isActive, isFalse);
    });

    testWidgets('pause during the final does not reopen the microphone', (
      tester,
    ) async {
      await service.start();
      speech.emitResult('elma', isFinal: true);
      await service.pause();
      await tester.pump(_restartDelay);
      expect(speech.listenCount, 1);
      expect(service.isActive, isTrue);
    });

    testWidgets('one done event schedules one listen', (tester) async {
      await service.start();
      speech.emitStatus(SpeechToText.doneStatus);
      speech.emitStatus(SpeechToText.doneStatus);
      await tester.pump(_restartDelay);
      await tester.pump(_restartDelay);

      expect(speech.listenCount, 2);
      expect(speech.stopCount, 0);
    });

    testWidgets('a late result from the previous session is dropped', (
      tester,
    ) async {
      await service.start();
      speech.emitStatus(SpeechToText.doneStatus);
      await tester.pump(_restartDelay);

      expect(speech.listenCount, 2);

      final received = <SpeechRecognitionEvent>[];
      final sub = service.events.listen(received.add);
      addTearDown(sub.cancel);

      speech.emitResult('elma', isFinal: true, session: 0);
      await tester.pump();

      expect(
        received.whereType<SpeechResult>(),
        isEmpty,
        reason: 'a delayed final from the old session must not leak',
      );
      expect(speech.listenCount, 2);
    });

    testWidgets('start stop start stop does not leave the microphone open', (
      tester,
    ) async {
      await service.start();
      await service.stop();
      await service.start();
      await service.stop();
      speech.emitStatus(SpeechToText.doneStatus);
      await tester.pump(_restartDelay);

      expect(service.isActive, isFalse);
      expect(speech.listenCount, 2);
    });

    testWidgets('pause resume pause resume keeps a single active run', (
      tester,
    ) async {
      await service.start();
      await service.pause();
      await service.resume();
      await service.pause();
      await service.resume();
      expect(service.isActive, isTrue);
      expect(speech.listenCount, 3);
      await service.stop();
      expect(service.isActive, isFalse);
    });

    for (final code in ['error_client', 'error_busy']) {
      testWidgets('five $code failures close listening', (tester) async {
        await service.start();

        for (var failure = 0; failure < 4; failure++) {
          speech.emitError(code);
          await tester.pump(_restartDelay);
        }
        expect(service.isActive, isTrue);
        expect(speech.listenCount, 5);

        speech.emitError(code);
        await tester.pump(_restartDelay);

        expect(speech.listenCount, 5);
        expect(service.isActive, isFalse);
        expect(service.isListening, isFalse);
        expect(speech.stopCount, 0);
      });
    }

    testWidgets('error_speech_timeout does not use up the restart budget', (
      tester,
    ) async {
      await service.start();

      for (var i = 0; i < 6; i++) {
        speech.emitError('error_speech_timeout');
        await tester.pump(const Duration(seconds: 3));
      }
      expect(service.isActive, isTrue);
      expect(speech.listenCount, 7);

      for (var failure = 0; failure < 4; failure++) {
        speech.emitError('error_client');
        await tester.pump(_restartDelay);
      }
      expect(service.isActive, isTrue);
      expect(speech.listenCount, 11);

      speech.emitError('error_client');
      await tester.pump(_restartDelay);
      expect(service.isActive, isFalse);
      expect(speech.listenCount, 11);
    });
  });

  testWidgets(
    'a new listening session keeps the follower and advances the next word',
    (tester) async {
      final speech = FakeSpeechToText();
      final service = SpeechRecognitionService(speech: speech);
      addTearDown(service.dispose);

      final controller = KaraokeController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KaraokeText(
              text: 'elma armut kiraz',
              controller: controller,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      );

      final follower = KaraokeSpeechFollower(
        controller: controller,
        events: service.events,
      );
      addTearDown(follower.dispose);
      controller.speechMode = true;

      await service.start();
      speech.emitResult('elma', isFinal: false);
      await tester.pump();
      expect(follower.lastPartial, 'elma');
      expect(controller.activeWordIndex, 0);
      speech.emitResult('elma', isFinal: true);
      await tester.pump();
      expect(follower.lastFinal, 'elma');

      // No `done` yet, as on a device right after the final.
      await tester.pump(_restartDelay);

      expect(speech.listenCount, 2);
      expect(
        follower.lastFinal,
        'elma',
        reason: 'the new session must not reset the follower',
      );

      speech.emitResult('armut', isFinal: false);
      await tester.pump();
      expect(controller.activeWordIndex, 1);
    },
  );

  group('lifecycle and locale', () {
    late FakeSpeechToText speech;
    late SpeechRecognitionService service;

    setUp(() {
      speech = FakeSpeechToText();
      service = SpeechRecognitionService(speech: speech);
    });

    tearDown(() => service.dispose());

    test('Turkish is preferred unless the language is English', () {
      expect(defaultPreferredSpeechLocaleId(const Locale('tr', 'TR')), 'tr_TR');
      expect(defaultPreferredSpeechLocaleId(const Locale('en', 'US')), 'en_US');
      expect(defaultPreferredSpeechLocaleId(const Locale('de', 'DE')), 'tr_TR');
    });

    test('a Turkish script is recognized in Turkish on an English device', () {
      const en = Locale('en', 'US');
      expect(
        preferredSpeechLocaleIdForScript('Saygıdeğer Konuklar, iyi günler', en),
        'tr_TR',
      );
      expect(
        preferredSpeechLocaleIdForScript('İYİ GÜNLER', en),
        'tr_TR',
        reason: 'uppercase Turkish letters count too',
      );
      expect(
        preferredSpeechLocaleIdForScript('Good morning everyone', en),
        'en_US',
      );
      expect(
        preferredSpeechLocaleIdForScript(
          'Good morning everyone',
          const Locale('tr', 'TR'),
        ),
        'tr_TR',
      );
    });

    testWidgets('pause keeps the listening run active', (tester) async {
      await service.start();
      expect(service.isActive, isTrue);
      await service.pause();
      expect(service.isActive, isTrue);
      expect(speech.stopCount, 1);
      speech.emitStatus(SpeechToText.doneStatus);
      await tester.pump(_restartDelay);
      expect(
        speech.listenCount,
        1,
        reason: 'a done after pause must not restart in the background',
      );
      await service.resume();
      expect(speech.listenCount, 2);
      expect(service.isActive, isTrue);
    });

    testWidgets('stop ends the listening run', (tester) async {
      await service.start();
      await service.stop();
      expect(service.isActive, isFalse);
      expect(speech.stopCount, 1);
    });

    testWidgets('permission denial does not throw', (tester) async {
      speech.grantPermission = false;
      speech.availableOnInit = false;
      expect(await service.initialize(), isFalse);
      expect(service.isAvailable, isFalse);
    });

    testWidgets('empty and fatal errors stay recoverable or close cleanly', (
      tester,
    ) async {
      await service.start();
      speech.emitError('error_network');
      await tester.pump(_restartDelay);
      expect(service.isActive, isTrue);
      speech.emitError('error_permission');
      await tester.pump();
      expect(service.isActive, isFalse);
    });
  });
}
