import 'package:flutter_test/flutter_test.dart';
import 'package:cueline/services/karaoke_matcher.dart';

const _script =
    'Bugün sizlere yapay zekâ hakkında konuşacağım. '
    'Bu teknolojinin hayatımızdaki etkilerini anlatacağım.';

List<String> _words(String text) => text.split(RegExp(r'\s+'));

/// "başlangıç" + 100 × "dolgu" + [tail]; the tail starts at word 101.
String _padded(String tail) =>
    ['başlangıç', for (var i = 0; i < 100; i++) 'dolgu', tail].join(' ');

KaraokeMatch _match(String script, String spoken, {int active = -1}) =>
    KaraokeMatcher(_words(script))
        .match(tokenizeTurkish(spoken), activeWordIndex: active);

void main() {
  group('normalization', () {
    test('Turkish lowercase and dotted/dotless i', () {
      expect(normalizeTurkishWord('İSTANBUL'), 'istanbul');
      expect(normalizeTurkishWord('IŞIK'), 'ışık');
      expect(normalizeTurkishWord('ŞEKER ĞÇÖÜ'), 'şekerğçöü');
      // Decomposed "İ" (i + combining dot above).
      expect(normalizeTurkishWord('i\u0307yi'), 'iyi');
    });

    test('punctuation, quotes, brackets and apostrophes are removed', () {
      expect(
        tokenizeTurkish(
          '"Yapay zekâ" (Ankara) hakkında: konuşacağım!? Türkiye\'nin',
        ),
        ['yapay', 'zeka', 'ankara', 'hakkında', 'konuşacağım', 'türkiyenin'],
      );
    });

    test('circumflex is ignored', () {
      expect(normalizeTurkishWord('zekâ'), normalizeTurkishWord('zeka'));
    });
  });

  group('KaraokeMatcher', () {
    test('exact match finds the last spoken word', () {
      final match = _match(_script, 'Bugün sizlere yapay zekâ hakkında');
      expect(match.wordIndex, 4);
      expect(match.method, KaraokeMatchMethod.exact);
      expect(match.confidence, 1.0);
    });

    test('Turkish characters and punctuation match exactly', () {
      final match = _match(
        _script,
        'yapay zekâ hakkında konuşacağım',
        active: 1,
      );
      expect(match.wordIndex, 5);
      expect(match.method, KaraokeMatchMethod.exact);
    });

    test('zekâ / zeka is an exact match', () {
      final match = _match(_script, 'Bugün sizlere yapay zeka hakkında');
      expect(match.wordIndex, 4);
      expect(match.method, KaraokeMatchMethod.exact);
    });

    test('STT output with sentence punctuation reaches the sentence end', () {
      final match = _match(
        _script,
        'Bugün sizlere yapay zeka hakkında konuşacağım.',
      );
      expect(match.wordIndex, 5);
      expect(match.confidence, 1.0);
    });

    test('repeated words are resolved by context', () {
      const script =
          'Bugün teknoloji hakkında konuşacağız. '
          'Teknoloji hayatımızın her alanında yer alıyor.';
      expect(_match(script, 'konuşacağız teknoloji', active: 3).wordIndex, 4);
      expect(_match(script, 'teknoloji hayatımızın').wordIndex, 5);
      expect(_match(script, 'bugün teknoloji').wordIndex, 1);
    });

    test('skipped words are tolerated as a sequence match', () {
      final match = _match(_script, 'Bugün yapay zeka konuşacağım');
      expect(match.wordIndex, 5);
      expect(match.method, KaraokeMatchMethod.sequence);
      expect(match.confidence, greaterThan(0.8));
    });

    test('small spelling differences match fuzzily', () {
      final match = _match(
        _script,
        'yapay zeka hakkında konusacağım',
        active: 1,
      );
      expect(match.wordIndex, 5);
      expect(match.method, KaraokeMatchMethod.fuzzy);
      expect(match.confidence, greaterThan(0.9));
    });

    test('unrelated words do not match', () {
      final match = _match(_script, 'masa sandalye pencere', active: 1);
      expect(match.isNone, isTrue);
    });

    test('words outside the window are not searched', () {
      final script = _padded('kırmızı elma yeşil armut');
      expect(_match(script, 'kırmızı elma').isNone, isTrue);
      expect(_match(script, 'dolgu kırmızı elma', active: 95).wordIndex, 102);
    });
  });

  group('KaraokeSpeechTracker', () {
    late KaraokeSpeechTracker tracker;
    var active = -1;

    void apply(KaraokeTrackResult? result) {
      if (result?.wordIndex case final index?) active = index;
    }

    setUp(() {
      tracker = KaraokeSpeechTracker(KaraokeMatcher(_words(_script)));
      active = -1;
    });

    test('moves the speech into the right region', () {
      apply(
        tracker.onFinal(
          'Bugün sizlere yapay zeka hakkında konuşacağım.',
          active,
        ),
      );
      expect(active, 5);
    });

    test('evolving partials advance without being appended', () {
      for (final partial in [
        'Bugün',
        'Bugün sizlere',
        'Bugün sizlere yapay zekâ',
        'Bugün sizlere yapay zekâ hakkında',
      ]) {
        apply(tracker.onPartial(partial, active));
      }
      expect(active, 4);
      // A revised partial with the same meaning keeps the position.
      apply(tracker.onPartial('bugün sizlere yapay zeka hakkında', active));
      expect(active, 4);
    });

    test('final after partial does not duplicate words', () {
      apply(tracker.onPartial('Bugün sizlere yapay zekâ hakkında', active));
      apply(tracker.onFinal('Bugün sizlere yapay zekâ hakkında', active));
      expect(active, 4);
      expect(tracker.committed, [
        'bugün',
        'sizlere',
        'yapay',
        'zeka',
        'hakkında',
      ]);

      // The next session continues from the committed context.
      apply(tracker.onPartial('konuşacağım', active));
      expect(active, 5);
      apply(tracker.onPartial('konuşacağım bu teknolojinin', active));
      expect(active, 7);

      // A repeated final is ignored.
      expect(
        tracker.onFinal('Bugün sizlere yapay zekâ hakkında', active),
        isNull,
      );
    });

    test('a wrong match does not move the active word backwards', () {
      active = 8;
      final result = tracker.onPartial('yapay zeka hakkında', active);
      expect(result?.decision, KaraokeDecision.backwardIgnored);
      expect(result?.wordIndex, isNull);
      expect(active, 8);
    });

    test('a single word cannot jump far ahead', () {
      final result = tracker.onPartial('anlatacağım', active);
      expect(result?.wordIndex, isNull);
      expect(active, -1);
    });

    test('unrelated speech keeps the active word', () {
      active = 3;
      final result = tracker.onPartial('bugün hava çok güzel', active);
      expect(result?.wordIndex, isNull);
      expect(active, 3);
    });

    test('resyncs after repeated weak matches outside the window', () {
      tracker = KaraokeSpeechTracker(
        KaraokeMatcher(_words(_padded('kırmızı elma yeşil armut'))),
      );
      active = 0;
      final partials = [
        'kırmızı',
        'kırmızı elma',
        'kırmızı elma yeşil',
        'kırmızı elma yeşil armut',
      ];
      KaraokeTrackResult? last;
      for (final partial in partials) {
        last = tracker.onPartial(partial, active);
        apply(last);
        if (partial != partials.last) expect(active, 0);
      }
      expect(last?.decision, KaraokeDecision.resynced);
      expect(active, 104);
    });
  });

  group('KaraokeSpeechTracker.resetContext (manual seek)', () {
    late KaraokeSpeechTracker tracker;
    var active = -1;

    void apply(KaraokeTrackResult? result) {
      if (result?.wordIndex case final index?) active = index;
    }

    String w(int from, [int? to]) =>
        _fiftyWords.sublist(from, (to ?? from) + 1).join(' ');

    /// Reads words 26..30 so that the committed context sits at word 30.
    void readUpTo30() {
      active = 25;
      apply(tracker.onFinal(w(26, 30), active));
      expect(active, 30);
    }

    setUp(() {
      tracker = KaraokeSpeechTracker(KaraokeMatcher(_fiftyWords));
      active = -1;
    });

    test('without a reset the old context pulls a backward seek back', () {
      readUpTo30();
      active = 10;
      apply(tracker.onPartial(w(11), active));
      expect(active, 30);
    });

    test('backward seek: matching continues from the new position', () {
      readUpTo30();
      active = 10;
      tracker.resetContext();
      expect(tracker.committed, isEmpty);
      apply(tracker.onPartial(w(11), active));
      expect(active, 11);
      apply(tracker.onPartial(w(11, 13), active));
      expect(active, 13);
    });

    test('small backward seek inside the look-behind window', () {
      readUpTo30();
      active = 25;
      tracker.resetContext();
      apply(tracker.onPartial(w(26), active));
      expect(active, 26);
    });

    test('seek to the start does not return to the old position', () {
      readUpTo30();
      active = -1;
      apply(tracker.onPartial(w(0), active));
      expect(active, 30, reason: 'old context wins without a reset');

      active = -1;
      tracker.resetContext();
      apply(tracker.onPartial(w(0), active));
      expect(active, 0);
      apply(tracker.onPartial(w(0, 1), active));
      expect(active, 1);
    });

    test('forward seek is accepted', () {
      readUpTo30();
      active = 45;
      // 26..30 is outside this window. The exact +1 match is no longer
      // diluted by those unmatched committed tokens.
      expect(tracker.onPartial(w(46), active)?.wordIndex, 46);

      tracker.resetContext();
      apply(tracker.onPartial('${w(46)} ${w(47)}', active));
      expect(active, 47);
    });

    test('streaks are cleared', () {
      void threeWeakResults() {
        for (final text in [
          'bugün hava',
          'bugün hava güzel',
          'bugün hava çok güzel',
        ]) {
          expect(tracker.onPartial(text, active)?.wordIndex, isNull);
        }
      }

      // Words 20..23 lie behind the window around word 30.
      readUpTo30();
      threeWeakResults();
      expect(
        tracker.onPartial(w(20, 23), active)?.decision,
        KaraokeDecision.resynced,
      );

      tracker.reset();
      readUpTo30();
      threeWeakResults();
      tracker.resetContext();
      expect(
        tracker.onPartial(w(20, 23), active)?.decision,
        KaraokeDecision.noMatch,
      );
      expect(active, 30);
    });

    test('words of the running utterance before the seek are ignored', () {
      active = 25;
      apply(tracker.onPartial(w(26, 28), active));
      expect(active, 28);

      active = 10;
      tracker.resetContext(pendingPartial: w(26, 28));
      // Same partial again adds nothing.
      expect(tracker.onPartial(w(26, 28), active), isNull);
      // The cumulative partial grows with words from the new position.
      apply(tracker.onPartial('${w(26, 28)} ${w(11)}', active));
      expect(active, 11);
      apply(tracker.onFinal('${w(26, 28)} ${w(11, 12)}', active));
      expect(active, 12);
      expect(tracker.committed, [w(11), w(12)]);
    });

    test('a new utterance is not trimmed', () {
      active = 25;
      apply(tracker.onPartial(w(26, 28), active));
      active = 10;
      tracker.resetContext(pendingPartial: w(26, 28));
      apply(tracker.onPartial(w(11, 13), active));
      expect(active, 13);
    });

    test('a new session is not trimmed', () {
      active = 25;
      apply(tracker.onPartial(w(26, 28), active));
      active = 25;
      tracker.resetContext(pendingPartial: w(26, 28));
      tracker.onSessionStart();
      apply(tracker.onPartial(w(26, 28), active));
      expect(active, 28);
    });
  });
}

/// 50 distinct words that do not match each other fuzzily.
const _fiftyWords = [
  'elma', 'armut', 'kiraz', 'çilek', 'muz', 'portakal', 'mandalina', //
  'karpuz', 'kavun', 'üzüm', 'erik', 'şeftali', 'kayısı', 'incir', 'nar',
  'ayva', 'limon', 'greyfurt', 'ananas', 'hindistan', 'masa', 'sandalye',
  'kapı', 'pencere', 'duvar', 'tavan', 'halı', 'perde', 'lamba', 'dolap',
  'kitap', 'defter', 'kalem', 'silgi', 'çanta', 'tahta', 'okul', 'sınıf',
  'öğretmen', 'öğrenci', 'deniz', 'göl', 'nehir', 'dağ', 'orman', 'çiçek',
  'ağaç', 'yaprak', 'toprak', 'bulut',
];
