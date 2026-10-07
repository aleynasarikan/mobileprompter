import 'package:flutter/foundation.dart';
import 'package:cueline/core/debug_flags.dart';

/// Debug-only timestamps for the speech → karaoke → overlay path.
///
/// Monotonic [t] is milliseconds since the first use of this clock. Logging
/// does not change recognition, matching, or overlay updates. Every call is a
/// no-op unless [kKaraokeTimingLog] is set.
///
/// `speech_to_text` 7.5.0 does not forward Android `onEndOfSpeech`. The later
/// `notListening` / `done` statuses are what this process can see.
class KaraokeTimingLog {
  static final Stopwatch _clock = Stopwatch();

  static int? session;
  static int? lastActiveWordIndex;

  static int? _partialMs;
  static int? _openMs;
  static String? _openOrigin;
  static int? _finalMs;
  static int? _finalSession;
  static int? _finalToDoneMs;
  static int? _doneMs;
  static int? _doneSession;
  static int? _notListeningMs;
  static int? _indexMs;
  static bool _indexGapPending = false;

  static const _instantKeys = {
    'partial_to_follower',
    'final_to_follower',
    'partial_to_matcher',
    'final_to_matcher',
    'partial_to_activeWordIndex',
    'final_to_activeWordIndex',
    'activeWordIndex_to_overlay',
  };

  static int get nowMs {
    if (!_clock.isRunning) _clock.start();
    return _clock.elapsedMilliseconds;
  }

  static void listenStarted(int sessionId) {
    if (!kKaraokeTimingLog) return;
    final t = nowMs;
    session = sessionId;
    final gaps = <String, int>{};
    if (_finalToDoneMs != null) gaps['FINAL_TO_DONE'] = _finalToDoneMs!;
    if (_doneMs != null) gaps['DONE_TO_NEXT_LISTEN'] = t - _doneMs!;
    if (_finalMs != null) gaps['FINAL_TO_NEXT_LISTEN'] = t - _finalMs!;
    _log(
      'listen',
      t: t,
      session: sessionId,
      note: _endOfSpeechNote(
        finalSession: _finalSession,
        doneSession: _doneSession,
      ),
    );
    if (gaps.isNotEmpty) {
      _log(
        'session_gap',
        t: t,
        session: sessionId,
        gaps: gaps,
        note: _endOfSpeechNote(
          finalSession: _finalSession,
          doneSession: _doneSession,
        ),
      );
    }
    _finalMs = null;
    _finalSession = null;
    _finalToDoneMs = null;
    _doneMs = null;
    _doneSession = null;
    _notListeningMs = null;
    _partialMs = null;
    _openMs = null;
    _openOrigin = null;
  }

  static void statusListening(int sessionId) {
    if (!kKaraokeTimingLog) return;
    session = sessionId;
    _log('status_listening', session: sessionId);
  }

  static void notListening(int sessionId) {
    if (!kKaraokeTimingLog) return;
    final t = nowMs;
    session = sessionId;
    _notListeningMs = t;
    final gaps = <String, int>{};
    if (_finalMs != null && _finalSession == sessionId) {
      gaps['FINAL_TO_NOT_LISTENING'] = t - _finalMs!;
    }
    _log(
      'status_notListening',
      t: t,
      session: sessionId,
      gaps: gaps,
      note: 'onEndOfSpeech=unavailable',
    );
  }

  static void done(int sessionId) {
    if (!kKaraokeTimingLog) return;
    final t = nowMs;
    session = sessionId;
    _doneMs = t;
    _doneSession = sessionId;
    final gaps = <String, int>{};
    if (_finalMs != null && _finalSession == sessionId) {
      _finalToDoneMs = t - _finalMs!;
      gaps['FINAL_TO_DONE'] = _finalToDoneMs!;
    }
    if (_notListeningMs != null) {
      gaps['NOT_LISTENING_TO_DONE'] = t - _notListeningMs!;
    }
    _log(
      'done',
      t: t,
      session: sessionId,
      gaps: gaps,
      note: 'onEndOfSpeech=unavailable',
    );
  }

  static void statusOther(String status, int sessionId) {
    if (!kKaraokeTimingLog) return;
    session = sessionId;
    _log('status', session: sessionId, text: status);
  }

  static void partial(String text, int sessionId) {
    if (!kKaraokeTimingLog) return;
    final t = nowMs;
    session = sessionId;
    _partialMs = t;
    _openMs = t;
    _openOrigin = 'partial';
    _log('partial', t: t, session: sessionId, text: text);
  }

  static void finalResult(String text, int sessionId) {
    if (!kKaraokeTimingLog) return;
    final t = nowMs;
    session = sessionId;
    _finalMs = t;
    _finalSession = sessionId;
    _openMs = t;
    _openOrigin = 'final';
    _log('final', t: t, session: sessionId, text: text);
  }

  static void error(String code, int sessionId) {
    if (!kKaraokeTimingLog) return;
    session = sessionId;
    _log('error', session: sessionId, text: code);
  }

  static void followerReceived({required String text, required bool isFinal}) {
    if (!kKaraokeTimingLog) return;
    final originMs = isFinal ? _finalMs : _partialMs;
    final key = isFinal ? 'final_to_follower' : 'partial_to_follower';
    _log(
      isFinal ? 'follower_final' : 'follower_partial',
      text: text,
      gaps: originMs == null ? null : {key: nowMs - originMs},
    );
  }

  static void followerDropped(String reason) {
    if (!kKaraokeTimingLog) return;
    cancelOpenPartial();
    _log('follower_dropped', note: 'reason=$reason');
  }

  static void matcher({
    required String text,
    required bool isFinal,
    required int? produced,
    required String decision,
    required int matchIndex,
  }) {
    if (!kKaraokeTimingLog) return;
    final originMs = isFinal ? _finalMs : _partialMs;
    final key = isFinal ? 'final_to_matcher' : 'partial_to_matcher';
    _log(
      'matcher',
      text: text,
      gaps: originMs == null ? null : {key: nowMs - originMs},
      note: 'produced=${produced ?? 'none'} matchIndex=$matchIndex decision=$decision',
    );
  }

  static void indexChanged(int index, {required String source}) {
    if (!kKaraokeTimingLog) return;
    final t = nowMs;
    lastActiveWordIndex = index;
    _indexMs = t;
    _indexGapPending = true;
    final gaps = <String, int>{};
    if (source != 'seek' && _openMs != null && _openOrigin != null) {
      gaps['${_openOrigin}_to_activeWordIndex'] = t - _openMs!;
      _openMs = null;
      _openOrigin = null;
    }
    _log(
      'activeWordIndex',
      t: t,
      activeWordIndex: index,
      gaps: gaps,
      note: 'source=$source',
    );
  }

  /// Drops a partial/final that did not move the highlight, so a later seek
  /// is not reported as that partial's index update.
  static void cancelOpenPartial() {
    _openMs = null;
    _openOrigin = null;
  }

  static void overlay({required String kind, required int activeWordIndex}) {
    if (!kKaraokeTimingLog) return;
    final t = nowMs;
    final gaps = <String, int>{};
    if (_indexMs != null) {
      final attach = kind == 'update' ||
          kind == 'show' ||
          (kind == 'sync' && _indexGapPending);
      if (attach) gaps['activeWordIndex_to_overlay'] = t - _indexMs!;
    }
    if (kind == 'sync') _indexGapPending = false;
    _log(
      kind == 'sync' ? 'overlay_sync' : 'overlay_$kind',
      t: t,
      activeWordIndex: activeWordIndex,
      gaps: gaps,
    );
  }

  static String _endOfSpeechNote({int? finalSession, int? doneSession}) {
    final parts = <String>['onEndOfSpeech=unavailable'];
    if (finalSession != null) parts.add('finalSession=$finalSession');
    if (doneSession != null) parts.add('doneSession=$doneSession');
    return parts.join(' ');
  }

  static void _log(
    String event, {
    int? t,
    int? session,
    String? text,
    int? activeWordIndex,
    Map<String, int>? gaps,
    String? note,
  }) {
    final time = t ?? nowMs;
    final line = StringBuffer('[KARAOKE_TIMING] t=${time}ms event=$event');
    final sid = session ?? KaraokeTimingLog.session;
    if (sid != null) line.write(' session=$sid');
    final index = activeWordIndex ?? lastActiveWordIndex;
    if (index != null) line.write(' activeWordIndex=$index');
    if (text != null) line.write(' text="${_short(text)}"');
    if (gaps != null) {
      for (final gap in gaps.entries) {
        line.write(' ${gap.key}=${gap.value}ms');
      }
      final watched = gaps.entries.where((gap) => _instantKeys.contains(gap.key));
      if (watched.isNotEmpty) {
        line.write(
          watched.every((gap) => gap.value <= 5)
              ? ' pipeline=instant'
              : ' pipeline=delayed',
        );
      }
    }
    if (note != null) line.write(' $note');
    debugPrintSynchronously(line.toString());
  }

  static String _short(String text) {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').replaceAll('"', "'").trim();
    if (flat.length <= 80) return flat;
    return '${flat.substring(0, 77)}...';
  }
}
