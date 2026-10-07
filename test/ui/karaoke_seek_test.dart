import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cueline/services/karaoke_speech_follower.dart';
import 'package:cueline/services/speech_recognition_service.dart';
import 'package:cueline/ui/widgets/karaoke_text.dart';

/// 50 distinct words that do not match each other fuzzily.
const _words = [
  'elma', 'armut', 'kiraz', 'çilek', 'muz', 'portakal', 'mandalina', //
  'karpuz', 'kavun', 'üzüm', 'erik', 'şeftali', 'kayısı', 'incir', 'nar',
  'ayva', 'limon', 'greyfurt', 'ananas', 'hindistan', 'masa', 'sandalye',
  'kapı', 'pencere', 'duvar', 'tavan', 'halı', 'perde', 'lamba', 'dolap',
  'kitap', 'defter', 'kalem', 'silgi', 'çanta', 'tahta', 'okul', 'sınıf',
  'öğretmen', 'öğrenci', 'deniz', 'göl', 'nehir', 'dağ', 'orman', 'çiçek',
  'ağaç', 'yaprak', 'toprak', 'bulut',
];

String _w(int from, [int? to]) =>
    _words.sublist(from, (to ?? from) + 1).join(' ');

void main() {
  late KaraokeController controller;
  late ScrollController scrollController;

  /// One word per line, so line n holds word n.
  Future<void> pumpText(
    WidgetTester tester, {
    double topPadding = 0,
    double bottomPadding = 0,
  }) async {
    controller = KaraokeController();
    scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
            child: KaraokeText(
              text: _words.join('\n'),
              controller: controller,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
    );
  }

  double lineHeight(WidgetTester tester) =>
      tester.getSize(find.byType(RichText).first).height;

  /// First line whose bottom is below the reading line (35 % of the view).
  int wordAtReadingLine(WidgetTester tester) {
    final viewport = tester.getSize(find.byType(SingleChildScrollView)).height;
    return ((scrollController.offset + viewport * 0.35) / lineHeight(tester))
        .floor();
  }

  group('KaraokeController.seek', () {
    test('next/previous/reset are seeks', () {
      final controller = KaraokeController();
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.previous();
      expect(controller.activeWordIndex, -1);
      expect(controller.seekCount, 1);
      expect(notifications, 1, reason: 'seeks notify even without a change');

      controller.reset();
      expect(controller.seekCount, 2);

      controller.activeWordIndex = 0;
      expect(controller.seekCount, 2, reason: 'speech updates are no seeks');
    });

    testWidgets('next/previous/reset move the active word', (tester) async {
      await pumpText(tester);
      controller.next();
      controller.next();
      expect(controller.activeWordIndex, 1);
      controller.previous();
      expect(controller.activeWordIndex, 0);
      controller.reset();
      expect(controller.activeWordIndex, -1);
    });
  });

  group('seekToReadingLine', () {
    testWidgets('the word at the reading line becomes the next word', (
      tester,
    ) async {
      await pumpText(tester);
      scrollController.jumpTo(lineHeight(tester) * 20);
      await tester.pump();

      final next = wordAtReadingLine(tester);
      expect(next, greaterThan(20));
      expect(controller.seekToReadingLine(), isTrue);
      expect(controller.activeWordIndex, next - 1);

      // Scrolling back moves the active word back.
      scrollController.jumpTo(lineHeight(tester) * 5);
      await tester.pump();
      controller.seekToReadingLine();
      expect(controller.activeWordIndex, wordAtReadingLine(tester) - 1);
      expect(controller.activeWordIndex, lessThan(next - 1));
    });

    testWidgets('above the text means start from the beginning', (
      tester,
    ) async {
      await pumpText(tester, topPadding: 600);
      controller.activeWordIndex = 30;
      controller.seekToReadingLine();
      expect(controller.activeWordIndex, -1);
    });

    testWidgets('below the text means the last word', (tester) async {
      await pumpText(tester, bottomPadding: 600);
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pump();
      controller.seekToReadingLine();
      expect(controller.activeWordIndex, _words.length - 1);
    });

    test('returns false without a laid out text', () {
      final controller = KaraokeController();
      addTearDown(controller.dispose);
      expect(controller.seekToReadingLine(), isFalse);
      expect(controller.seekCount, 0);
    });
  });

  group('KaraokeSpeechFollower', () {
    late StreamController<SpeechRecognitionEvent> events;
    late KaraokeSpeechFollower follower;

    Future<void> setUpFollower(WidgetTester tester) async {
      await pumpText(tester);
      events = StreamController<SpeechRecognitionEvent>.broadcast(sync: true);
      follower = KaraokeSpeechFollower(
        controller: controller,
        events: events.stream,
      );
      addTearDown(events.close);
      addTearDown(follower.dispose);
      controller.speechMode = true;
    }

    Future<void> say(String text, {bool isFinal = false}) async {
      events.add(SpeechResult(text: text, isFinal: isFinal, confidence: 1));
    }

    void startSession() {
      events.add(
        const SpeechListeningChanged(isListening: true, status: 'listening'),
      );
    }

    Future<void> readUpTo30() async {
      controller.seek(25);
      await say(_w(26, 30), isFinal: true);
      expect(controller.activeWordIndex, 30);
    }

    testWidgets('backward seek: speech continues from the new position', (
      tester,
    ) async {
      await setUpFollower(tester);
      await readUpTo30();
      controller.seek(10);
      await say(_w(11));
      expect(controller.activeWordIndex, 11);
    });

    testWidgets('previous button is detected as a seek', (tester) async {
      await setUpFollower(tester);
      await readUpTo30();
      for (var i = 0; i < 5; i++) {
        controller.previous();
      }
      expect(controller.activeWordIndex, 25);
      await say(_w(26));
      expect(controller.activeWordIndex, 26);
    });

    testWidgets('reset starts from the beginning', (tester) async {
      await setUpFollower(tester);
      await readUpTo30();
      controller.reset();
      await say(_w(0));
      expect(controller.activeWordIndex, 0);
    });

    testWidgets('forward seek is accepted', (tester) async {
      await setUpFollower(tester);
      await readUpTo30();
      controller.seek(45);
      await say(_w(46));
      expect(controller.activeWordIndex, 46);
    });

    testWidgets(
      'seek while an utterance is running ignores the rest of that utterance',
      (tester) async {
        await setUpFollower(tester);
        controller.seek(25);
        await say(_w(26, 28));
        expect(controller.activeWordIndex, 28);

        controller.seek(10);
        expect(
          controller.activeWordIndex,
          10,
          reason: 'the seek position is kept',
        );

        // Words added after the seek still belong to the utterance that was
        // open then, including words from the new position.
        await say('${_w(26, 28)} ${_w(11)}');
        expect(controller.activeWordIndex, 10);
        expect(
          follower.lastResult,
          isNull,
          reason: 'the delayed continuation never reaches the tracker',
        );

        await say('${_w(26, 28)} ${_w(11, 12)}', isFinal: true);
        expect(
          controller.activeWordIndex,
          10,
          reason: 'the final of the open utterance is not tracked',
        );

        // This arrives before the next listening session, so it is followed
        // only when the final itself cleared the ignore.
        await say(_w(11));
        expect(controller.activeWordIndex, 11);

        startSession();
        await say(_w(12));
        expect(
          controller.activeWordIndex,
          12,
          reason:
              'the next listening session is followed from the new position',
        );
      },
    );

    testWidgets(
      'a seek with no open utterance does not drop the next utterance',
      (tester) async {
        await setUpFollower(tester);

        // A session has started and no partial is in flight.
        startSession();
        controller.seek(10);
        await say(_w(11));
        expect(
          controller.activeWordIndex,
          11,
          reason: 'speech after a seek is kept when nothing was being said',
        );

        // The utterance is closed, so the next seek again has nothing pending.
        await say(_w(11, 12), isFinal: true);
        expect(controller.activeWordIndex, 12);
        controller.seek(25);
        startSession();
        await say(_w(26, 28), isFinal: true);
        expect(
          controller.activeWordIndex,
          28,
          reason: 'a session that starts after the seek is followed',
        );
      },
    );

    testWidgets('a direct change of the active word is detected', (
      tester,
    ) async {
      await setUpFollower(tester);
      await readUpTo30();
      controller.activeWordIndex = 10;
      await say(_w(11));
      expect(controller.activeWordIndex, 11);
    });

    testWidgets('speech does not move the word while the user drags', (
      tester,
    ) async {
      await setUpFollower(tester);
      controller.seek(25);
      controller.isUserScrolling = true;
      await say(_w(26, 28));
      expect(controller.activeWordIndex, 25);
      expect(follower.lastPartial, _w(26, 28));

      // The drag ends with a seek. The utterance was already open, so the
      // rest of it, including words from the new position, is not tracked.
      controller.isUserScrolling = false;
      controller.seek(10);
      await say('${_w(26, 28)} ${_w(11)}');
      expect(controller.activeWordIndex, 10);
      expect(follower.lastPartial, '${_w(26, 28)} ${_w(11)}');
      expect(
        follower.lastResult,
        isNull,
        reason: 'the delayed continuation never reaches the tracker',
      );

      await say('${_w(26, 28)} ${_w(11)}', isFinal: true);
      expect(
        controller.activeWordIndex,
        10,
        reason: 'the final of the open utterance is not tracked',
      );

      await say(_w(11));
      expect(
        controller.activeWordIndex,
        11,
        reason: 'the final cleared the ignore before the next session',
      );

      startSession();
      await say(_w(12));
      expect(
        controller.activeWordIndex,
        12,
        reason: 'the next listening session is followed from the new position',
      );
    });

    testWidgets('speech updates are not taken for seeks', (tester) async {
      await setUpFollower(tester);
      controller.seek(25);
      await say(_w(26, 28), isFinal: true);
      expect(follower.lastResult, isNotNull, reason: 'a seek clears it');
      await say(_w(29, 30));
      expect(follower.lastResult, isNotNull);
      expect(controller.activeWordIndex, 30);
    });

    testWidgets('rapid seeks keep the last position', (tester) async {
      await setUpFollower(tester);
      await readUpTo30();
      for (var i = 0; i < 12; i++) {
        controller.seek(i.isEven ? 8 : 40);
      }
      expect(controller.activeWordIndex, 40);
      startSession();
      await say(_w(41));
      expect(controller.activeWordIndex, 41);
    });

    testWidgets('seek to the beginning and the end', (tester) async {
      await setUpFollower(tester);
      await readUpTo30();
      controller.seek(-1);
      startSession();
      await say(_w(0));
      expect(controller.activeWordIndex, 0);

      controller.seek(_words.length - 1);
      startSession();
      await say(_w(_words.length - 1), isFinal: true);
      expect(controller.activeWordIndex, _words.length - 1);
    });

    testWidgets('seek beyond the script clamps', (tester) async {
      await pumpText(tester);
      controller.seek(9999);
      expect(controller.activeWordIndex, _words.length - 1);
      controller.seek(-20);
      expect(controller.activeWordIndex, -1);
    });

    testWidgets('delayed old final after seek does not pull back', (
      tester,
    ) async {
      await setUpFollower(tester);
      controller.seek(25);
      await say(_w(26, 28));
      controller.seek(5);
      await say(_w(26, 28), isFinal: true);
      expect(controller.activeWordIndex, 5);
      startSession();
      await say(_w(6, 8), isFinal: true);
      expect(controller.activeWordIndex, 8);
    });

    testWidgets('follower dispose drops later speech events', (tester) async {
      await pumpText(tester);
      final localEvents = StreamController<SpeechRecognitionEvent>.broadcast(
        sync: true,
      );
      final localFollower = KaraokeSpeechFollower(
        controller: controller,
        events: localEvents.stream,
      );
      controller.speechMode = true;
      controller.seek(10);
      localEvents.add(
        SpeechResult(text: _w(11), isFinal: false, confidence: 1),
      );
      expect(controller.activeWordIndex, 11);
      localFollower.dispose();
      localEvents.add(
        const SpeechResult(text: 'masa sandalye', isFinal: true, confidence: 1),
      );
      expect(controller.activeWordIndex, 11);
      await localEvents.close();
    });
  });
}
