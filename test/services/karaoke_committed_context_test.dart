import 'package:flutter_test/flutter_test.dart';
import 'package:cueline/services/karaoke_matcher.dart';

/// Kelime indeksleri tek tokenlidir ve fixture içinde sabittir.
///
/// 15 guncel — activeWordIndex
/// 16 önce
/// 17 aşama
/// 18 baglantinin — "ekinin" bu kelimeye eşleşmez
/// 19 gerçek
/// 20 kullanım
abstract final class Phrase {
  static const guncel = 15;
  static const once = 16;
  static const asama = 17;
  static const baglantinin = 18;
  static const gercek = 19;
  static const kullanim = 20;
}

/// Önceki finaldan kalan, aktif pencere içinde metne eşleşmeyen beş token.
const staleWords = ['qqqqaa', 'qqqqbb', 'qqqqcc', 'qqqqdd', 'qqqqee'];

const partials = [
  'önce',
  'önce aşama',
  'önce aşama ekinin',
  'önce aşama ekinin gerçek',
  'önce aşama ekinin gerçek kullanım',
];

List<String> phraseScript() {
  final words = <String>[
    for (var i = 0; i < 70; i++) 'zzz${i.toString().padLeft(2, '0')}',
  ];
  words[Phrase.guncel] = 'guncel';
  words[Phrase.once] = 'önce';
  words[Phrase.asama] = 'aşama';
  words[Phrase.baglantinin] = 'baglantinin';
  words[Phrase.gercek] = 'gerçek';
  words[Phrase.kullanim] = 'kullanım';
  return words;
}

List<String> numberedScript(int count, Map<int, String> at) {
  final words = <String>[
    for (var i = 0; i < count; i++) 'w${i.toString().padLeft(3, '0')}x',
  ];
  at.forEach((index, word) => words[index] = word);
  return words;
}

KaraokeSpeechTracker trackerWithStale(List<String> script) {
  final tracker = KaraokeSpeechTracker(KaraokeMatcher(script));
  final committed = tracker.onFinal(staleWords.join(' '), Phrase.guncel);
  expect(committed?.decision, KaraokeDecision.noMatch);
  expect(tracker.committed, staleWords);
  return tracker;
}

void main() {
  group('regression / baseline', () {
    test('final kuyruğu yokken "önce" güvenlik kurallarıyla 16ya ilerler', () {
      final script = phraseScript();
      final tracker = KaraokeSpeechTracker(KaraokeMatcher(script));
      expect(tracker.committed, isEmpty);

      final result = tracker.onPartial('önce', Phrase.guncel);

      expect(script[Phrase.once], 'önce');
      expect(result?.match.wordIndex, Phrase.once);
      expect(result?.match.matchedCount, 1);
      expect(result?.match.confidence, 1);
      // Tek kelime +1: maxSingleWordAdvance (2) ve largeJump (10) izin verir.
      expect(Phrase.once - Phrase.guncel, lessThanOrEqualTo(2));
      expect(result?.decision, KaraokeDecision.advanced);
      expect(result?.wordIndex, Phrase.once);
    });

    test('önceki finalın 5 tokenı aktif pencere içinde eşleşmez', () {
      final script = phraseScript();
      final matcher = KaraokeMatcher(script);
      final match = matcher.match(staleWords, activeWordIndex: Phrase.guncel);

      expect(staleWords, hasLength(5));
      expect(match.isNone, isTrue);
      expect(trackerWithStale(script).committed, staleWords);
    });
  });

  group('target: eski committed tokenlar yeni partialı ezmez', () {
    // Bu grubun testleri mevcut production kodunda kırmızıdır.
    // Payda düzeltmesi yapılmadan geçmeleri beklenmez.

    test('TARGET: 5 eşleşmeyen token varken "önce" 16ya ilerler', () {
      final tracker = trackerWithStale(phraseScript());

      final result = tracker.onPartial('önce', Phrase.guncel);

      expect(result?.decision, KaraokeDecision.advanced);
      expect(result?.wordIndex, Phrase.once);
    });

    test('TARGET: 5 eşleşmeyen token varken "önce aşama" 17ye ilerler', () {
      final tracker = trackerWithStale(phraseScript());
      var active = Phrase.guncel;

      final first = tracker.onPartial(partials[0], active);
      if (first?.wordIndex case final index?) active = index;
      final second = tracker.onPartial(partials[1], active);

      expect(second?.decision, KaraokeDecision.advanced);
      expect(second?.wordIndex, Phrase.asama);
    });
  });

  group('multi-partial', () {
    test(
      '"ekinin" 18. kelimeye eşleşmez; hizalama aşama (17) üzerinde kalır',
      () {
        final script = phraseScript();
        expect(script[Phrase.baglantinin], 'baglantinin');
        expect(script[Phrase.baglantinin], isNot('ekinin'));

        final matcher = KaraokeMatcher(script);
        // Son token penceredeki hiçbir kelimeye bağlanamaz.
        expect(
          matcher.match(['ekinin'], activeWordIndex: Phrase.guncel).isNone,
          isTrue,
        );

        final tracker = trackerWithStale(script);
        tracker.onPartial(partials[0], Phrase.guncel);
        tracker.onPartial(partials[1], Phrase.guncel);
        final result = tracker.onPartial(partials[2], Phrase.guncel);

        // Zincir en yeni tokena ya da bir öncekine kadar kurulur.
        // "ekinin" eşleşmediği için hizalama bir önceki token olan "aşama"da biter.
        expect(result?.match.spokenText.split(' ').last, 'ekinin');
        expect(result?.match.matchedText, 'önce aşama');
        expect(result?.match.wordIndex, Phrase.asama);
        expect(result?.match.wordIndex, isNot(Phrase.baglantinin));
      },
    );

    test('"gerçek" partialında mevcut production davranışı', () {
      final tracker = trackerWithStale(phraseScript());
      var active = Phrase.guncel;
      KaraokeTrackResult? result;
      for (final partial in partials.take(4)) {
        result = tracker.onPartial(partial, active);
        if (result?.wordIndex case final index?) active = index;
      }

      // "ekinin" does not match word 18. The unmatched committed token is
      // not in the denominator, so "gerçek" advances from 17 to 19.
      expect(result?.decision, KaraokeDecision.advanced);
      expect(result?.wordIndex, Phrase.gercek);
      expect(active, Phrase.gercek);
      expect(result?.match.wordIndex, Phrase.gercek);
      expect(result?.match.matchedText, 'önce aşama gerçek');
      expect(result?.match.matchedCount, 3);
      expect(result?.match.method, KaraokeMatchMethod.sequence);
      expect(result?.match.confidence, closeTo(0.7125, 1e-9));
    });

    test('TARGET: "kullanım" tek kararda 20ye sıçramaz, eşleşen kelimeler kademeli ilerler', () {
      final tracker = trackerWithStale(phraseScript());
      var active = Phrase.guncel;
      final trace = <int>[active];
      for (final partial in partials) {
        final result = tracker.onPartial(partial, active);
        if (result?.wordIndex case final index?) active = index;
        trace.add(active);
      }

      final jumps = <int>[
        for (var i = 1; i < trace.length; i++) trace[i] - trace[i - 1],
      ];
      expect(
        jumps,
        everyElement(lessThanOrEqualTo(2)),
        reason:
            'İz: $trace (15 guncel, 16 önce, 17 aşama, 18 baglantinin, '
            '19 gerçek, 20 kullanım). '
            'kullanım geldiğinde 15 → 20 tek sıçrama olmamalı.',
      );
      expect(trace.last, Phrase.kullanim);
    });
  });

  group('güvenlik sözleşmeleri', () {
    test('40 kelime ilerideki kısa kelime trackerı ilerletmez', () {
      const active = 15;
      const far = active + 40;
      final script = numberedScript(far + 5, {far: 've'});
      final tracker = KaraokeSpeechTracker(KaraokeMatcher(script));

      final result = tracker.onPartial('ve', active);

      expect(result?.match.wordIndex, far);
      expect(result?.match.matchedCount, 1);
      expect(result?.decision, KaraokeDecision.lowConfidence);
      expect(result?.wordIndex, isNull);
    });

    test('tek kelimelik eşleşme 2den fazla ileri sıçramaz', () {
      const active = 15;
      final allowed = numberedScript(40, {active + 2: 'merkur'});
      final allowedResult = KaraokeSpeechTracker(KaraokeMatcher(allowed))
          .onPartial('merkur', active);
      expect(allowedResult?.match.matchedCount, 1);
      expect(allowedResult?.decision, KaraokeDecision.advanced);
      expect(allowedResult?.wordIndex, active + 2);

      final rejected = numberedScript(40, {active + 3: 'telescop'});
      final rejectedResult = KaraokeSpeechTracker(KaraokeMatcher(rejected))
          .onPartial('telescop', active);
      expect(rejectedResult?.match.wordIndex, active + 3);
      expect(rejectedResult?.match.matchedCount, 1);
      expect(rejectedResult?.decision, KaraokeDecision.lowConfidence);
      expect(rejectedResult?.wordIndex, isNull);
    });

    test('10dan büyük sıçrama güçlü eşleşme olmadan kabul edilmez', () {
      const active = 15;

      final weak = numberedScript(50, {26: 'jupiter', 27: 'neptun'});
      final weakResult = KaraokeSpeechTracker(KaraokeMatcher(weak))
          .onPartial('jupiter neptun', active);
      expect(weakResult?.match.wordIndex, 27);
      expect(weakResult?.match.matchedCount, 2);
      expect(27 - active, greaterThan(10));
      expect(weakResult?.decision, KaraokeDecision.lowConfidence);
      expect(weakResult?.wordIndex, isNull);

      final strong = numberedScript(50, {24: 'alfa', 25: 'beta', 26: 'gama'});
      final strongResult = KaraokeSpeechTracker(KaraokeMatcher(strong))
          .onPartial('alfa beta gama', active);
      expect(strongResult?.match.matchedCount, greaterThanOrEqualTo(3));
      expect(strongResult?.match.confidence, greaterThanOrEqualTo(0.8));
      expect(26 - active, greaterThan(10));
      expect(strongResult?.decision, KaraokeDecision.advanced);
      expect(strongResult?.wordIndex, 26);
    });

    test('geri eşleşme yeterli tekrar olmadan activeWordIndexi düşürmez', () {
      const active = 30;
      final script = numberedScript(50, {
        24: 'alfa',
        25: 'beta',
        26: 'gama',
        29: 'delta',
      });

      final weak = KaraokeSpeechTracker(KaraokeMatcher(script));
      final weakResult = weak.onPartial('delta', active);
      expect(weakResult?.match.wordIndex, 29);
      expect(weakResult?.decision, KaraokeDecision.backwardIgnored);
      expect(weakResult?.wordIndex, isNull);

      // Aynı metin ikinci kez null döner; noktalama tokenları değiştirmez.
      const utterances = [
        'alfa beta gama',
        'alfa beta gama.',
        'alfa beta gama!',
      ];
      final strong = KaraokeSpeechTracker(KaraokeMatcher(script));
      for (final utterance in utterances.take(2)) {
        final result = strong.onPartial(utterance, active);
        expect(result?.match.wordIndex, 26);
        expect(result?.match.matchedCount, greaterThanOrEqualTo(3));
        expect(result?.decision, KaraokeDecision.backwardIgnored);
        expect(result?.wordIndex, isNull);
      }

      final third = strong.onPartial(utterances[2], active);
      expect(third?.match.wordIndex, 26);
      expect(third?.decision, KaraokeDecision.resynced);
      expect(third?.wordIndex, 26);
    });

    test('aynı kelime iki kez geçtiğinde doğru kopya seçilir', () {
      final script = numberedScript(40, {
        13: 'sol',
        14: 'elma',
        21: 'sag',
        22: 'elma',
      });
      final matcher = KaraokeMatcher(script);
      // Her iki kopya da look-behind penceresinin içinde kalsın.
      const active = 19;

      final ahead = matcher.match(
        tokenizeTurkish('sag elma'),
        activeWordIndex: active,
      );
      expect(ahead.wordIndex, 22);

      final behind = matcher.match(
        tokenizeTurkish('sol elma'),
        activeWordIndex: active,
      );
      expect(behind.wordIndex, 14);

      final tracker = KaraokeSpeechTracker(matcher);
      final moved = tracker.onPartial('sag elma', active);
      expect(moved?.wordIndex, 22);
    });
  });
}
