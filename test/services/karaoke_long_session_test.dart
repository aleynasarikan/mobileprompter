import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:cueline/services/karaoke_matcher.dart';
import 'package:cueline/services/karaoke_speech_follower.dart';
import 'package:cueline/services/speech_recognition_service.dart';
import 'package:cueline/ui/widgets/karaoke_text.dart';

void main() {
  test('a 5000-word script still matches around the active word', () {
    final words = [for (var i = 0; i < 5000; i++) 'w${i}x'];
    words[2500] = 'elma';
    words[2501] = 'armut';
    words[2502] = 'kiraz';
    final match = KaraokeMatcher(words)
        .match(tokenizeTurkish('elma armut kiraz'), activeWordIndex: 2499);
    expect(match.wordIndex, 2502);
    expect(match.confidence, greaterThanOrEqualTo(0.6));
  });

  test('low confidence does not jump across a long script', () {
    final words = [for (var i = 0; i < 5000; i++) 'w${i}x'];
    words[10] = 'elma';
    words[4000] = 'armut';
    final tracker = KaraokeSpeechTracker(KaraokeMatcher(words));
    final result = tracker.onPartial('armut', 10);
    expect(result?.wordIndex, isNull);
    expect(
      result?.decision,
      anyOf(KaraokeDecision.lowConfidence, KaraokeDecision.noMatch),
    );
  });

  test('disposed follower ignores later speech events', () async {
    final karaoke = KaraokeController();
    addTearDown(karaoke.dispose);
    karaoke.speechMode = true;

    final events = StreamController<SpeechRecognitionEvent>.broadcast();
    addTearDown(events.close);

    final follower = KaraokeSpeechFollower(
      controller: karaoke,
      events: events.stream,
    );
    follower.dispose();

    events.add(const SpeechResult(text: 'elma', isFinal: true, confidence: 1));
    await Future<void>.delayed(Duration.zero);
    expect(karaoke.activeWordIndex, -1);
  });
}
