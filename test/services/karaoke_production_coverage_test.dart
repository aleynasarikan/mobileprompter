import 'package:flutter_test/flutter_test.dart';
import 'package:cueline/services/karaoke_matcher.dart';

List<String> _words(String text) => [
  for (final part in text.split(RegExp(r'\s+')))
    if (part.isNotEmpty) part,
];

KaraokeMatch _match(String script, String spoken, {int active = -1}) =>
    KaraokeMatcher(_words(script))
        .match(tokenizeTurkish(spoken), activeWordIndex: active);

void main() {
  group('tokenization edge cases', () {
    test('case differences are ignored', () {
      expect(normalizeTurkishWord('BUGÜN'), 'bugün');
      expect(tokenizeTurkish('Bugün Sizlere'), ['bugün', 'sizlere']);
    });

    test('English contractions drop punctuation', () {
      // Turkish I→ı applies to English "I'm" as well; that is intentional.
      expect(tokenizeTurkish("don't I'm we'll"), ['dont', 'ım', 'well']);
    });

    test('hyphenated and slashed compounds split', () {
      expect(tokenizeTurkish('yapay-zeka AR/VR'), [
        'yapay',
        'zeka',
        'ar',
        'vr',
      ]);
    });

    test('short words stay tokens', () {
      expect(tokenizeTurkish('ve o bu şu'), ['ve', 'o', 'bu', 'şu']);
    });

    test('long Turkish words keep suffixes', () {
      expect(normalizeTurkishWord('konuşacaklarmış'), 'konuşacaklarmış');
    });
  });

  group('speech matching coverage', () {
    const script =
        'Bugün sizlere yapay zekâ hakkında konuşacağım. '
        'Bu teknolojinin hayatımızdaki etkilerini anlatacağım.';

    test('exact match', () {
      final match = _match(script, 'Bugün sizlere yapay');
      expect(match.wordIndex, 2);
      expect(match.method, KaraokeMatchMethod.exact);
      expect(match.confidence, 1.0);
    });

    test('case and punctuation differences still match', () {
      final match = _match(script, 'BUGÜN, sizlere! yapay.');
      expect(match.wordIndex, 2);
      expect(match.confidence, 1.0);
    });

    test('Turkish suffixes match fuzzily when long enough', () {
      final match = _match('kitapları masaya koydum', 'kitaplari masaya');
      expect(match.wordIndex, 1);
      expect(match.method, isNot(KaraokeMatchMethod.none));
    });

    test('missing spoken words are tolerated', () {
      final match = _match(script, 'Bugün yapay zeka konuşacağım');
      expect(match.wordIndex, 5);
      expect(match.method, KaraokeMatchMethod.sequence);
    });

    test('extra spoken words do not prevent a sequence match', () {
      final match = _match(script, 'Bugün eee sizlere yapay zeka');
      expect(match.wordIndex, 3);
      expect(match.method, KaraokeMatchMethod.sequence);
    });

    test('similar sounding folded Turkish matches', () {
      final match = _match(script, 'konusacagim', active: 3);
      expect(match.wordIndex, 5);
      expect(match.method, KaraokeMatchMethod.fuzzy);
    });

    test('unrelated similar-length words do not match', () {
      expect(_match(script, 'masa sandalye pencere').isNone, isTrue);
    });
  });

  group('karaoke progression', () {
    const words = [
      'elma',
      'armut',
      'kiraz',
      'çilek',
      'muz',
      'portakal',
      'mandalina',
      'karpuz',
      'kavun',
      'üzüm',
      'erik',
      'şeftali',
      'kayısı',
      'incir',
      'nar',
      'ayva',
      'limon',
      'greyfurt',
      'ananas',
      'hindistan',
      'masa',
      'sandalye',
      'kapı',
      'pencere',
      'duvar',
      'tavan',
      'halı',
      'perde',
      'lamba',
      'dolap',
      'kitap',
      'defter',
      'kalem',
      'silgi',
      'çanta',
      'tahta',
      'okul',
      'sınıf',
      'öğretmen',
      'öğrenci',
      'deniz',
      'göl',
      'nehir',
      'dağ',
      'orman',
      'çiçek',
      'ağaç',
      'yaprak',
      'toprak',
      'bulut',
    ];

    late KaraokeSpeechTracker tracker;
    var active = -1;

    void apply(KaraokeTrackResult? result) {
      if (result?.wordIndex case final index?) active = index;
    }

    String w(int from, [int? to]) =>
        words.sublist(from, (to ?? from) + 1).join(' ');

    setUp(() {
      tracker = KaraokeSpeechTracker(KaraokeMatcher(words));
      active = -1;
    });

    test('+1 +2 +3 advances', () {
      apply(tracker.onPartial(w(0), active));
      expect(active, 0);
      apply(tracker.onPartial(w(0, 1), active));
      expect(active, 1);
      apply(tracker.onPartial(w(0, 2), active));
      expect(active, 2);
      apply(tracker.onPartial(w(1, 4), active));
      expect(active, 4);
    });

    test('a jump larger than 10 needs a strong match', () {
      active = 0;
      final weak = tracker.onPartial(w(15), active);
      expect(weak?.wordIndex, isNull);
      expect(weak?.decision, KaraokeDecision.lowConfidence);

      final strong = tracker.onPartial(w(12, 15), active);
      expect(strong?.decision, KaraokeDecision.advanced);
      expect(strong?.wordIndex, 15);
    });

    test('a very large jump is rejected without a strong match', () {
      active = 0;
      final result = tracker.onPartial(w(40), active);
      expect(result?.wordIndex, isNull);
    });

    test('duplicate words use nearby context', () {
      final script = [...words.sublist(0, 10), 'elma', ...words.sublist(11)];
      tracker = KaraokeSpeechTracker(KaraokeMatcher(script));
      active = 8;
      apply(tracker.onPartial('üzüm elma', active));
      expect(active, 10);
    });

    test('the same word many times does not skip far ahead', () {
      tracker = KaraokeSpeechTracker(
        KaraokeMatcher(['elma', for (var i = 0; i < 20; i++) 'elma']),
      );
      apply(tracker.onPartial('elma', active));
      expect(active, lessThanOrEqualTo(2));
    });

    test('low confidence never moves the active word', () {
      active = 8;
      final result = tracker.onPartial('qqqqaaaa qqqqbbbb', active);
      expect(
        result?.decision,
        anyOf(KaraokeDecision.lowConfidence, KaraokeDecision.noMatch),
      );
      expect(result?.wordIndex, isNull);
    });

    test('high confidence advances', () {
      final result = tracker.onFinal(w(0, 4), active);
      apply(result);
      expect(active, 4);
      expect(result?.match.confidence, 1.0);
    });

    test('borderline confidence uses the 0.6 floor', () {
      active = 3;
      final result = tracker.onPartial('hava güzel', active);
      expect(result?.wordIndex, isNull);
      if (result != null && result.match.confidence > 0) {
        expect(result.match.confidence, lessThan(0.6));
      }
    });

    test('evolving partials replace earlier guesses', () {
      apply(tracker.onPartial('elma', active));
      expect(active, 0);
      apply(tracker.onPartial('elma armut', active));
      expect(active, 1);
      apply(tracker.onPartial('elma armut kiraz', active));
      expect(active, 2);
    });

    test('speech hesitation with filler is skipped', () {
      apply(tracker.onPartial('elma eee armut kiraz', active));
      expect(active, 2);
    });
  });

  group('long-running session', () {
    test('committed context stays bounded and tracking does not drift', () {
      final words = [
        for (var i = 0; i < 5000; i++) 'w${i.toString().padLeft(4, '0')}',
      ];
      final tracker = KaraokeSpeechTracker(KaraokeMatcher(words));
      var active = -1;
      for (var i = 0; i < 300; i += 3) {
        final spoken = words.sublist(i, i + 4).join(' ');
        final result = tracker.onFinal(spoken, active);
        if (result?.wordIndex case final index?) active = index;
      }
      expect(tracker.committed.length, lessThanOrEqualTo(5));
      expect(active, greaterThan(250));
      expect(active, lessThan(400));
    });
  });
}
