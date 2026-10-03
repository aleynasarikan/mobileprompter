// Reproductions of seek problems seen with real speech.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiefprompt/services/karaoke_speech_follower.dart';
import 'package:tiefprompt/services/speech_recognition_service.dart';
import 'package:tiefprompt/ui/widgets/karaoke_text.dart';
import 'package:tiefprompt/ui/widgets/scrollable_text.dart';

// Word indices: 10 teşekkür, 11 ederim, 21 olacak, 26 isterim, 27 Bugün,
// 31 hakkında, 35 vereceğim, 61 geçelim.
const _text =
    'Değerli konuklar, hoş geldiniz. Bu akşamki toplantımıza katıldığınız '
    'için hepinize teşekkür ederim. Etkinliğimiz iki bölümden oluşacak ve '
    'sonunda soru cevap kısmı olacak. Öncelikle kendimi kısaca tanıtmak '
    'isterim. Bugün sizlere yapay zeka hakkında kısa bir bilgi vereceğim. '
    'Yapay zeka hayatımızın birçok alanında kullanılmaktadır. Sağlıktan '
    'eğitime, ulaşımdan finansa kadar pek çok sektörde önemli değişimler '
    'yaratmaktadır. Konuşmamın sonunda sorularınızı memnuniyetle '
    'yanıtlayacağım. Şimdi ilk bölüme geçelim.';

void main() {
  group('speech after a seek', () {
    late KaraokeController controller;
    late StreamController<SpeechRecognitionEvent> events;
    late KaraokeSpeechFollower follower;
    late List<String> trace;

    Future<void> setUpFollower(WidgetTester tester) async {
      controller = KaraokeController();
      final scrollController = ScrollController();
      addTearDown(controller.dispose);
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scrollController,
              child: KaraokeText(text: _text, controller: controller),
            ),
          ),
        ),
      );
      expect(controller.wordCount, 62);
      events = StreamController<SpeechRecognitionEvent>.broadcast(sync: true);
      follower = KaraokeSpeechFollower(
        controller: controller,
        events: events.stream,
      );
      addTearDown(events.close);
      addTearDown(follower.dispose);
      controller.speechMode = true;
      trace = [];
    }

    /// Records and returns the active word after [label].
    int step(String label) {
      final active = controller.activeWordIndex;
      final word = active >= 0 ? controller.document.words[active] : '-';
      trace.add(
        '$label → active $active "$word" '
        '(${follower.lastResult?.decision.name ?? '-'})',
      );
      return active;
    }

    /// A new recognizer session, as after every final in the service.
    void newSession() => events.add(
      const SpeechListeningChanged(isListening: true, status: 'listening'),
    );

    void partial(String text) =>
        events.add(SpeechResult(text: text, isFinal: false, confidence: 1));

    void finalResult(String text) =>
        events.add(SpeechResult(text: text, isFinal: true, confidence: 1));

    testWidgets(
      'delayed partial/final of the old utterance after a backward seek',
      (tester) async {
        await setUpFollower(tester);

        // Reading reaches the sentence starting at word 27.
        controller.seek(21);
        newSession();
        partial('öncelikle kendimi');
        partial('öncelikle kendimi kısaca tanıtmak isterim');
        finalResult('Öncelikle kendimi kısaca tanıtmak isterim.');
        step('read to "isterim"');
        newSession();
        partial('bugün sizlere yapay');
        partial('bugün sizlere yapay zeka hakkında');
        final beforeSeek = step('old utterance, last partial before seek');

        // The user scrolls back.
        controller.seek(10);
        final afterSeek = step('seek(10)');

        // Recognition of the old utterance lags behind the seek.
        partial('bugün sizlere yapay zeka hakkında kısa bir bilgi vereceğim');
        final afterLatePartial = step('late partial of the old utterance');
        finalResult(
          'Bugün sizlere yapay zeka hakkında kısa bir bilgi vereceğim.',
        );
        final afterLateFinal = step('late final of the old utterance');

        // The user reads on from the new position.
        newSession();
        partial('ederim');
        partial('ederim etkinliğimiz iki');
        final afterNewSpeech = step('new speech "ederim etkinliğimiz iki"');

        printOnFailure(trace.join('\n'));
        expect(beforeSeek, 31);
        expect(afterSeek, 10);
        expect(
          afterLatePartial,
          inInclusiveRange(8, 14),
          reason: 'late old partial must not move away from the seek',
        );
        expect(
          afterLateFinal,
          inInclusiveRange(8, 14),
          reason: 'late old final must not move away from the seek',
        );
        expect(
          afterNewSpeech,
          13,
          reason: 'new speech must be followed from the seek position',
        );
      },
    );

    testWidgets('the same final again after a seek', (tester) async {
      await setUpFollower(tester);
      const sentence = 'Bugün sizlere yapay zeka hakkında';

      controller.seek(26);
      newSession();
      finalResult(sentence);
      final first = step('first final');

      // The user scrolls back and reads the sentence again.
      controller.seek(26);
      step('seek(26)');
      newSession();
      finalResult(sentence);
      final second = step('same final again');

      printOnFailure(trace.join('\n'));
      expect(first, 31);
      expect(second, 31, reason: 'a repeated final must not be ignored');
    });
  });

  group('real drag on ScrollableText', () {
    testWidgets('a drag moves the active word to the reading line', (
      tester,
    ) async {
      final scrollable = ScrollableTextController();
      addTearDown(scrollable.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            speechRecognitionServiceProvider.overrideWithValue(
              SpeechRecognitionService(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ScrollableText(
                controller: scrollable,
                text: _text,
                sideMargin: 0,
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final karaoke = scrollable.karaokeController;
      final position = scrollable.scrollController;
      expect(karaoke.wordCount, 62);
      karaoke.seek(50);
      await tester.pump();
      final seeksBefore = karaoke.seekCount;

      // Drag up: the text scrolls down into the reading line.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -900),
      );
      expect(
        karaoke.isUserScrolling,
        isTrue,
        reason: 'set when the drag starts',
      );
      await tester.pumpAndSettle();
      final offsetDown = position.offset;
      final afterDown = karaoke.activeWordIndex;

      expect(offsetDown, greaterThan(0));
      expect(karaoke.isUserScrolling, isFalse);
      expect(karaoke.seekCount, greaterThan(seeksBefore));
      expect(afterDown, isNot(50));
      expect(afterDown, greaterThanOrEqualTo(0));
      // The drag used the same mapping as a direct call.
      karaoke.seekToReadingLine();
      expect(karaoke.activeWordIndex, afterDown);

      // Drag back down: the active word moves back.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();
      expect(position.offset, lessThan(offsetDown));
      expect(karaoke.activeWordIndex, lessThan(afterDown));
    });
  });
}
