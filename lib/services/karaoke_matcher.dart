import 'dart:math' as math;

/// Deterministic matching of recognized speech against the prompter script.
///
/// Pure Dart: no Flutter, network or model dependencies, so it can be unit
/// tested and reasoned about in isolation.

final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);
final _tokenSeparator = RegExp(r'[\s\-‐‑–—/]+');

/// Turkish-aware lowercase without punctuation, e.g. `"İstanbul'da,"` →
/// `istanbulda`, `"Zekâ."` → `zeka`.
String normalizeTurkishWord(String word) {
  final out = StringBuffer();
  for (final rune in word.runes) {
    final char = String.fromCharCode(rune);
    final mapped = switch (char) {
      'İ' => 'i',
      'I' => 'ı',
      // The circumflex only marks vowel length; STT usually omits it.
      'Â' || 'â' => 'a',
      'Î' || 'î' => 'i',
      'Û' || 'û' => 'u',
      _ => char.toLowerCase(),
    };
    // Drops punctuation and combining marks (e.g. the dot of a decomposed
    // "i̇").
    for (final r in mapped.runes) {
      final c = String.fromCharCode(r);
      if (_letterOrDigit.hasMatch(c)) out.write(c);
    }
  }
  return out.toString();
}

/// Splits on whitespace, dashes and slashes and normalizes every token.
List<String> tokenizeTurkish(String text) => [
  for (final part in text.split(_tokenSeparator))
    if (normalizeTurkishWord(part) case final token when token.isNotEmpty)
      token,
];

/// Maps Turkish-specific letters to their base letter; only used for fuzzy
/// comparison, e.g. `konuşacağım` ≈ `konusacagim`.
String foldTurkish(String normalized) {
  final out = StringBuffer();
  for (final rune in normalized.runes) {
    final char = String.fromCharCode(rune);
    out.write(switch (char) {
      'ş' => 's',
      'ğ' => 'g',
      'ç' => 'c',
      'ö' => 'o',
      'ü' => 'u',
      'ı' => 'i',
      _ => char,
    });
  }
  return out.toString();
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      current[j] = math.min(
        math.min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + cost,
      );
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[b.length];
}

enum KaraokeMatchMethod {
  /// Every spoken word matched the script exactly, without gaps.
  exact,

  /// Exact words, but some spoken or script words were skipped.
  sequence,

  /// At least one word only matched approximately.
  fuzzy,
  none,
}

class KaraokeMatcherConfig {
  /// Script words before the active word that are searched.
  final int lookBehind;

  /// Script words after the active word that are searched.
  final int lookAhead;

  /// Searched words while no word is active yet.
  final int initialWindow;

  /// Number of most recent spoken words used as context.
  final int spokenContext;

  /// Script words that may be skipped between two matched words.
  final int maxScriptSkip;

  /// Spoken words that may be skipped between two matched words.
  final int maxSpokenSkip;

  /// Score deducted per skipped script word.
  final double scriptSkipPenalty;

  /// Folded-letter equality (`konuşacağım` / `konusacağım`).
  final double foldedSimilarity;

  /// Minimum edit-distance similarity for a fuzzy word match.
  final double minFuzzySimilarity;

  /// Shorter words must match exactly.
  final int minFuzzyLength;

  const KaraokeMatcherConfig({
    this.lookBehind = 6,
    this.lookAhead = 40,
    this.initialWindow = 50,
    this.spokenContext = 5,
    this.maxScriptSkip = 3,
    this.maxSpokenSkip = 2,
    this.scriptSkipPenalty = 0.15,
    this.foldedSimilarity = 0.9,
    this.minFuzzySimilarity = 0.75,
    this.minFuzzyLength = 4,
  });
}

class KaraokeMatch {
  static const none = KaraokeMatch(
    wordIndex: -1,
    confidence: 0,
    method: KaraokeMatchMethod.none,
    matchedCount: 0,
    matchedText: '',
    spokenText: '',
  );

  /// Script word index of the last matched spoken word, -1 for none.
  final int wordIndex;

  /// 0..1. Unmatched tokens carried over from the previous final are not
  /// counted in the denominator.
  final double confidence;
  final KaraokeMatchMethod method;
  final int matchedCount;

  /// Matched spoken words in order.
  final String matchedText;

  /// The spoken context that was matched.
  final String spokenText;

  const KaraokeMatch({
    required this.wordIndex,
    required this.confidence,
    required this.method,
    required this.matchedCount,
    required this.matchedText,
    required this.spokenText,
  });

  bool get isNone => method == KaraokeMatchMethod.none;

  @override
  String toString() =>
      'KaraokeMatch($wordIndex, ${confidence.toStringAsFixed(2)}, '
      '${method.name}, "$matchedText")';
}

class KaraokeMatcher {
  final KaraokeMatcherConfig config;
  final int wordCount;

  // Script tokens; a script word may yield several tokens ("yapay-zeka").
  final _tokens = <String>[];
  final _folded = <String>[];
  final _tokenWord = <int>[];

  KaraokeMatcher(
    List<String> scriptWords, {
    this.config = const KaraokeMatcherConfig(),
  }) : wordCount = scriptWords.length {
    for (var i = 0; i < scriptWords.length; i++) {
      for (final token in tokenizeTurkish(scriptWords[i])) {
        _tokens.add(token);
        _folded.add(foldTurkish(token));
        _tokenWord.add(i);
      }
    }
  }

  /// Finds where the most recent [spoken] tokens are in the script.
  ///
  /// Searches around [activeWordIndex] unless [global] is set. Among equally
  /// good candidates the one closest to the active word wins.
  ///
  /// [freshCount] is how many trailing tokens belong to the current partial
  /// or final. Tokens before them stay in the alignment as committed context.
  /// Unmatched committed tokens are left out of the confidence denominator.
  /// Omit it to treat every token as fresh.
  KaraokeMatch match(
    List<String> spoken, {
    required int activeWordIndex,
    bool global = false,
    int? freshCount,
  }) {
    final context = spoken.length > config.spokenContext
        ? spoken.sublist(spoken.length - config.spokenContext)
        : spoken;
    final m = context.length;
    if (m == 0 || _tokens.isEmpty) return KaraokeMatch.none;

    final (start, end) = _window(activeWordIndex, global);
    final w = end - start;
    if (w <= 0) return KaraokeMatch.none;

    final foldedSpoken = [for (final s in context) foldTurkish(s)];
    final score = List.generate(
      m,
      (_) => List<double>.filled(w, double.negativeInfinity),
    );
    final count = List.generate(m, (_) => List<int>.filled(w, 0));
    final allExact = List.generate(m, (_) => List<bool>.filled(w, true));
    final gaps = List.generate(m, (_) => List<int>.filled(w, 0));
    final previous = List.generate(m, (_) => List<int>.filled(w, -1));

    // score[i][j]: best chain of matches whose last element pairs spoken
    // word i with script token start + j.
    for (var i = 0; i < m; i++) {
      for (var j = 0; j < w; j++) {
        final (sim, exact) = _similarity(
          context[i],
          foldedSpoken[i],
          start + j,
        );
        if (sim <= 0) continue;

        var best = sim;
        var bestPrevious = -1;
        var bestGaps = 0;
        for (var pi = math.max(0, i - 1 - config.maxSpokenSkip); pi < i; pi++) {
          for (
            var pj = math.max(0, j - 1 - config.maxScriptSkip);
            pj < j;
            pj++
          ) {
            final s = score[pi][pj];
            if (s == double.negativeInfinity) continue;
            final scriptGap = j - pj - 1;
            final candidate = s + sim - scriptGap * config.scriptSkipPenalty;
            if (candidate > best) {
              best = candidate;
              bestPrevious = pi * w + pj;
              bestGaps = gaps[pi][pj] + scriptGap + (i - pi - 1);
            }
          }
        }

        score[i][j] = best;
        previous[i][j] = bestPrevious;
        gaps[i][j] = bestPrevious < 0 ? 0 : bestGaps;
        if (bestPrevious < 0) {
          count[i][j] = 1;
          allExact[i][j] = exact;
        } else {
          final pi = bestPrevious ~/ w;
          final pj = bestPrevious % w;
          count[i][j] = count[pi][pj] + 1;
          allExact[i][j] = exact && allExact[pi][pj];
        }
      }
    }

    // The chain has to reach the newest spoken word, or the one before it
    // (the newest one may be misrecognized or still incomplete).
    final expected = activeWordIndex + 1;
    var bestRank = double.negativeInfinity;
    var bestI = -1;
    var bestJ = -1;
    for (var i = math.max(0, m - 2); i < m; i++) {
      for (var j = 0; j < w; j++) {
        final s = score[i][j];
        if (s == double.negativeInfinity) continue;
        final distance = (_tokenWord[start + j] - expected).abs();
        final rank = s / m - distance * 1e-4;
        if (rank > bestRank) {
          bestRank = rank;
          bestI = i;
          bestJ = j;
        }
      }
    }
    if (bestI < 0) return KaraokeMatch.none;

    final inChain = List<bool>.filled(m, false);
    final matched = <String>[];
    for (var cell = bestI * w + bestJ; cell >= 0;) {
      final i = cell ~/ w;
      final j = cell % w;
      inChain[i] = true;
      matched.add(context[i]);
      cell = previous[i][j];
    }

    final matchedCount = count[bestI][bestJ];
    final contiguous = gaps[bestI][bestJ] == 0 && matchedCount == m;
    final method = !allExact[bestI][bestJ]
        ? KaraokeMatchMethod.fuzzy
        : contiguous
        ? KaraokeMatchMethod.exact
        : KaraokeMatchMethod.sequence;

    // Ranking above still divides by the full context length, so which
    // candidate wins does not change. Only the reported confidence drops
    // committed tokens that never joined the chosen chain.
    final fresh = freshCount == null
        ? spoken.length
        : math.min(math.max(freshCount, 0), spoken.length);
    final committedInContext = m - math.min(fresh, m);
    var unmatchedCommitted = 0;
    for (var i = 0; i < committedInContext; i++) {
      if (!inChain[i]) unmatchedCommitted++;
    }
    final denominator = m - unmatchedCommitted;

    return KaraokeMatch(
      wordIndex: _tokenWord[start + bestJ],
      confidence: denominator == 0
          ? 0
          : (score[bestI][bestJ] / denominator).clamp(0.0, 1.0),
      method: method,
      matchedCount: matchedCount,
      matchedText: matched.reversed.join(' '),
      spokenText: context.join(' '),
    );
  }

  /// Token range [start, end) to search.
  (int, int) _window(int activeWordIndex, bool global) {
    final n = _tokens.length;
    if (global) return (0, n);
    if (activeWordIndex < 0) return (0, math.min(n, config.initialWindow));
    final center = _lastTokenAtOrBefore(activeWordIndex);
    return (
      math.max(0, center - config.lookBehind),
      math.min(n, center + config.lookAhead + 1),
    );
  }

  int _lastTokenAtOrBefore(int wordIndex) {
    var low = 0;
    var high = _tokenWord.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_tokenWord[mid] <= wordIndex) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low - 1;
  }

  (double, bool) _similarity(String spoken, String foldedSpoken, int token) {
    if (spoken == _tokens[token]) return (1.0, true);
    final folded = _folded[token];
    if (foldedSpoken == folded) return (config.foldedSimilarity, false);
    final shorter = math.min(foldedSpoken.length, folded.length);
    if (shorter < config.minFuzzyLength) return (0, false);
    final longer = math.max(foldedSpoken.length, folded.length);
    final similarity = 1 - levenshtein(foldedSpoken, folded) / longer;
    if (similarity < config.minFuzzySimilarity) return (0, false);
    return (similarity * config.foldedSimilarity, false);
  }
}

enum KaraokeDecision {
  /// The active word moved to the match.
  advanced,

  /// A wide search after repeated weak matches relocated the speaker.
  resynced,

  /// The match confirms the current active word.
  unchanged,

  /// Too weak, or a jump that is too large for the evidence.
  lowConfidence,

  /// A match behind the active word that is not (yet) trusted.
  backwardIgnored,
  noMatch,
}

class KaraokeTrackerConfig {
  /// Matches below this confidence never move the active word.
  final double minConfidence;

  /// A single matched word may only advance this far.
  final int maxSingleWordAdvance;

  /// Advances beyond this need a strong match.
  final int largeJump;

  /// A strong match has at least this many words ...
  final int strongMinWords;

  /// ... and at least this confidence.
  final double strongConfidence;

  /// Consecutive weak results before searching the whole script.
  final int resyncAfterLowConfidence;

  /// Consecutive strong backward matches before moving back.
  final int resyncAfterBackward;

  const KaraokeTrackerConfig({
    this.minConfidence = 0.6,
    this.maxSingleWordAdvance = 2,
    this.largeJump = 10,
    this.strongMinWords = 3,
    this.strongConfidence = 0.8,
    this.resyncAfterLowConfidence = 4,
    this.resyncAfterBackward = 3,
  });
}

class KaraokeTrackResult {
  final KaraokeMatch match;
  final KaraokeDecision decision;

  /// New active word index, or null to keep the current one.
  final int? wordIndex;

  const KaraokeTrackResult(this.match, this.decision, [this.wordIndex]);
}

/// Turns the stream of partial/final recognition results into active word
/// updates.
///
/// Partials are cumulative per recognizer session and may revise earlier
/// words, so every partial replaces the previous one instead of being
/// appended. Final results are committed; the next session's partials are
/// matched together with the tail of the committed words. Unmatched
/// committed tokens do not reduce the confidence of the new partial.
class KaraokeSpeechTracker {
  final KaraokeMatcher matcher;
  final KaraokeTrackerConfig config;

  List<String> _committed = const [];
  String _lastPartial = '';
  String _lastFinal = '';
  int _lowConfidenceStreak = 0;
  int _backwardStreak = 0;

  /// Tokens of the running utterance that were spoken before the last
  /// [resetContext]; they are dropped from its later partials and final.
  List<String> _staleTokens = const [];

  KaraokeSpeechTracker(
    this.matcher, {
    this.config = const KaraokeTrackerConfig(),
  });

  /// Committed spoken tokens used as context for the next partials.
  List<String> get committed => _committed;

  void reset() {
    _committed = const [];
    _lastPartial = '';
    _lastFinal = '';
    _lowConfidenceStreak = 0;
    _backwardStreak = 0;
    _staleTokens = const [];
  }

  /// Forgets the spoken context after the active word was moved by hand, so
  /// that speech from the old position cannot pull it back.
  ///
  /// [pendingPartial] is the latest partial of the running utterance. Partials
  /// are cumulative, so its words would otherwise be matched again with every
  /// following partial of the same utterance.
  void resetContext({String pendingPartial = ''}) {
    _committed = const [];
    _lowConfidenceStreak = 0;
    _backwardStreak = 0;
    _lastPartial = pendingPartial;
    _lastFinal = '';
    _staleTokens = tokenizeTurkish(pendingPartial);
  }

  /// A new recognizer session starts a new utterance.
  void onSessionStart() {
    _lastPartial = '';
    _staleTokens = const [];
  }

  /// Returns null when [text] adds nothing new.
  KaraokeTrackResult? onPartial(String text, int activeWordIndex) {
    if (text == _lastPartial) return null;
    _lastPartial = text;
    final tokens = _withoutStaleTokens(tokenizeTurkish(text));
    if (tokens.isEmpty) return null;
    return _track([..._committed, ...tokens], activeWordIndex, tokens.length);
  }

  /// Returns null for empty or repeated finals.
  KaraokeTrackResult? onFinal(String text, int activeWordIndex) {
    _lastPartial = '';
    if (text == _lastFinal) return null;
    _lastFinal = text;
    final tokens = _withoutStaleTokens(tokenizeTurkish(text));
    _staleTokens = const [];
    if (tokens.isEmpty) return null;
    final spoken = [..._committed, ...tokens];
    final keep = matcher.config.spokenContext;
    _committed = spoken.length > keep
        ? spoken.sublist(spoken.length - keep)
        : spoken;
    return _track(spoken, activeWordIndex, tokens.length);
  }

  /// Drops the stale prefix while [tokens] still belong to the same
  /// utterance (same first word); a different first word means a new one.
  List<String> _withoutStaleTokens(List<String> tokens) {
    final stale = _staleTokens;
    if (stale.isEmpty) return tokens;
    if (tokens.isEmpty || tokens.first != stale.first) {
      _staleTokens = const [];
      return tokens;
    }
    return tokens.length > stale.length
        ? tokens.sublist(stale.length)
        : const [];
  }

  KaraokeTrackResult _track(List<String> spoken, int active, int freshCount) {
    final match = matcher.match(
      spoken,
      activeWordIndex: active,
      freshCount: freshCount,
    );
    final result = _decide(match, active);
    if (result.decision != KaraokeDecision.lowConfidence &&
        result.decision != KaraokeDecision.noMatch) {
      _lowConfidenceStreak = 0;
      return result;
    }

    if (++_lowConfidenceStreak < config.resyncAfterLowConfidence) {
      return result;
    }
    final global = matcher.match(
      spoken,
      activeWordIndex: active,
      global: true,
      freshCount: freshCount,
    );
    if (!_isStrong(global) || global.wordIndex == active) return result;
    _lowConfidenceStreak = 0;
    _backwardStreak = 0;
    return KaraokeTrackResult(
      global,
      KaraokeDecision.resynced,
      global.wordIndex,
    );
  }

  KaraokeTrackResult _decide(KaraokeMatch match, int active) {
    if (match.isNone) {
      return KaraokeTrackResult(match, KaraokeDecision.noMatch);
    }
    if (match.confidence < config.minConfidence) {
      return KaraokeTrackResult(match, KaraokeDecision.lowConfidence);
    }

    final target = match.wordIndex;
    if (target == active) {
      _backwardStreak = 0;
      return KaraokeTrackResult(match, KaraokeDecision.unchanged);
    }

    if (target < active) {
      if (_isStrong(match) && ++_backwardStreak >= config.resyncAfterBackward) {
        _backwardStreak = 0;
        return KaraokeTrackResult(match, KaraokeDecision.resynced, target);
      }
      return KaraokeTrackResult(match, KaraokeDecision.backwardIgnored);
    }

    _backwardStreak = 0;
    final advance = target - active;
    if (match.matchedCount < 2 && advance > config.maxSingleWordAdvance) {
      return KaraokeTrackResult(match, KaraokeDecision.lowConfidence);
    }
    if (advance > config.largeJump && !_isStrong(match)) {
      return KaraokeTrackResult(match, KaraokeDecision.lowConfidence);
    }
    return KaraokeTrackResult(match, KaraokeDecision.advanced, target);
  }

  bool _isStrong(KaraokeMatch match) =>
      match.matchedCount >= config.strongMinWords &&
      match.confidence >= config.strongConfidence;
}
