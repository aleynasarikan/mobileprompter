import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cueline/services/creator_overlay.dart';
import 'package:cueline/services/karaoke_timing_log.dart';

/// What to send to the floating window after a script or position change.
enum CreatorSyncKind { none, show, update }

class CreatorSync {
  final CreatorSyncKind kind;
  final int activeWordIndex;

  const CreatorSync._(this.kind, this.activeWordIndex);

  const CreatorSync.none() : this._(CreatorSyncKind.none, -1);

  const CreatorSync.show(int activeWordIndex)
    : this._(CreatorSyncKind.show, activeWordIndex);

  const CreatorSync.update(int activeWordIndex)
    : this._(CreatorSyncKind.update, activeWordIndex);
}

/// Full script when the words change, otherwise only the active index.
CreatorSync planCreatorSync({
  required bool visible,
  required List<String> words,
  required int activeWordIndex,
  required List<String>? sentWords,
  required int? sentIndex,
}) {
  if (!visible) return const CreatorSync.none();
  if (sentWords == null || !listEquals(sentWords, words)) {
    return CreatorSync.show(activeWordIndex);
  }
  if (sentIndex != activeWordIndex) {
    return CreatorSync.update(activeWordIndex);
  }
  return const CreatorSync.none();
}

/// Mirrors the stage teleprompter into the Android overlay.
///
/// The stage [KaraokeController] stays the source of truth. This host only
/// listens and forwards words plus the active index, so speech matching is
/// unchanged.
class CreatorMode extends ChangeNotifier {
  CreatorMode(this._overlay);

  final CreatorOverlayApi _overlay;

  Listenable? _stage;
  List<String> Function()? _stageWords;
  int Function()? _stageIndex;
  List<String> _fallbackWords = const [];

  bool isVisible = false;
  bool _useMicrophone = false;
  Map<String, String> _labels = const {};
  int _generation = 0;
  List<String>? _sentWords;
  int? _sentIndex;
  Future<void> _pending = Future<void>.value();

  /// Completes when the last queued overlay update has finished.
  Future<void> get pending => _pending;

  void attach({
    required Listenable listenable,
    required List<String> Function() words,
    required int Function() index,
  }) {
    if (identical(_stage, listenable)) return;
    _stage?.removeListener(_onStage);
    _stage = listenable;
    _stageWords = words;
    _stageIndex = index;
    listenable.addListener(_onStage);
    sync();
  }

  void detach(Listenable listenable) {
    if (!identical(_stage, listenable)) return;
    listenable.removeListener(_onStage);
    _stage = null;
    _stageWords = null;
    _stageIndex = null;
  }

  /// Used when the stage script has not been built yet.
  void setFallbackWords(List<String> words) {
    _fallbackWords = words;
  }

  List<String> get currentWords {
    final stageWords = _stageWords?.call() ?? const <String>[];
    if (stageWords.isNotEmpty) return stageWords;
    return _fallbackWords;
  }

  int get currentIndex {
    final stageWords = _stageWords?.call() ?? const <String>[];
    if (stageWords.isEmpty) return -1;
    return _stageIndex?.call() ?? -1;
  }

  void _onStage() => sync();

  void sync() {
    if (!isVisible) return;
    KaraokeTimingLog.overlay(kind: 'sync', activeWordIndex: currentIndex);
    _enqueue(_syncBody);
  }

  Future<void> show({
    required bool useMicrophone,
    Map<String, String> labels = const {},
  }) {
    _useMicrophone = useMicrophone;
    _labels = labels;
    if (!isVisible) {
      isVisible = true;
      notifyListeners();
    }
    return _enqueue(_syncBody);
  }

  Future<void> hide() {
    isVisible = false;
    _sentWords = null;
    _sentIndex = null;
    _generation++;
    notifyListeners();
    return _enqueue(_overlay.hide);
  }

  /// The service can outlive the Flutter isolate. Reattach after a restart.
  Future<void> adoptIfRunning() {
    return _enqueue(() async {
      if (isVisible || !await _overlay.isRunning()) return;
      isVisible = true;
      notifyListeners();
      await _syncBody();
    });
  }

  Future<bool> canDrawOverlays() => _overlay.canDrawOverlays();

  Future<void> openOverlaySettings() => _overlay.openOverlaySettings();

  Future<void> _enqueue(Future<void> Function() action) {
    final run = _pending.then((_) => action());
    _pending = run.then((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }

  Future<void> _syncBody() async {
    if (!isVisible) return;
    final generation = _generation;
    final words = currentWords;
    final index = currentIndex;
    final plan = planCreatorSync(
      visible: true,
      words: words,
      activeWordIndex: index,
      sentWords: _sentWords,
      sentIndex: _sentIndex,
    );
    switch (plan.kind) {
      case CreatorSyncKind.none:
        return;
      case CreatorSyncKind.show:
        KaraokeTimingLog.overlay(
          kind: 'show',
          activeWordIndex: plan.activeWordIndex,
        );
        await _overlay.show(
          words: words,
          activeWordIndex: plan.activeWordIndex,
          useMicrophone: _useMicrophone,
          labels: _labels,
        );
      case CreatorSyncKind.update:
        try {
          KaraokeTimingLog.overlay(
            kind: 'update',
            activeWordIndex: plan.activeWordIndex,
          );
          await _overlay.update(plan.activeWordIndex);
        } on PlatformException {
          if (!isVisible || generation != _generation) return;
          KaraokeTimingLog.overlay(
            kind: 'show',
            activeWordIndex: plan.activeWordIndex,
          );
          await _overlay.show(
            words: words,
            activeWordIndex: plan.activeWordIndex,
            useMicrophone: _useMicrophone,
            labels: _labels,
          );
        }
    }
    if (!isVisible || generation != _generation) return;
    _sentWords = List<String>.of(words);
    _sentIndex = plan.activeWordIndex;
  }

  @override
  void dispose() {
    _stage?.removeListener(_onStage);
    _stage = null;
    super.dispose();
  }
}

final creatorModeProvider = Provider<CreatorMode>((ref) {
  final mode = CreatorMode(const CreatorOverlay());
  ref.onDispose(mode.dispose);
  return mode;
});
