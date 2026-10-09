import 'dart:async';

import 'package:flutter/services.dart';
import 'package:cueline/services/creator_overlay.dart';

/// In-memory stand-in for the Android floating window and its service.
class FakeOverlay implements CreatorOverlayApi {
  /// Overlay ("display over other apps") permission.
  bool canDraw = true;

  /// What the user picks in the Android settings screen.
  bool grantOnSettings = false;

  /// Error code `show` fails with, e.g. microphone_permission_denied.
  String? showError;

  final shows =
      <
        ({List<String> words, int index, bool mic, Map<String, String> labels})
      >[];
  final updates = <int>[];
  final playingCalls = <bool>[];
  final visibleCalls = <bool>[];
  var hides = 0;
  var settingsOpened = 0;
  var movedToBack = 0;

  /// Mirrors the native service: one at most.
  var running = false;
  var servicesStarted = 0;
  bool? playing;
  bool? visible;

  final _actions = StreamController<FloatingOverlayAction>.broadcast(
    sync: true,
  );

  /// A tap on the native window.
  void tap(FloatingOverlayAction action) => _actions.add(action);

  @override
  Stream<FloatingOverlayAction> get actions => _actions.stream;

  @override
  Future<bool> canDrawOverlays() async => canDraw;

  @override
  Future<void> openOverlaySettings() async {
    settingsOpened++;
    if (grantOnSettings) canDraw = true;
  }

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<void> show({
    required List<String> words,
    required int activeWordIndex,
    required bool useMicrophone,
    Map<String, String> labels = const {},
  }) async {
    if (!canDraw) {
      throw PlatformException(code: 'overlay_permission_denied');
    }
    if (showError case final code?) throw PlatformException(code: code);
    shows.add((
      words: words,
      index: activeWordIndex,
      mic: useMicrophone,
      labels: labels,
    ));
    if (!running) {
      running = true;
      servicesStarted++;
    }
  }

  @override
  Future<void> update(int activeWordIndex) async {
    if (!running) throw PlatformException(code: 'overlay_not_running');
    updates.add(activeWordIndex);
  }

  @override
  Future<void> setPlaying(bool playing) async {
    playingCalls.add(playing);
    this.playing = playing;
  }

  @override
  Future<void> setVisible(bool visible) async {
    visibleCalls.add(visible);
    this.visible = visible;
  }

  @override
  Future<void> moveAppToBack() async {
    movedToBack++;
  }

  @override
  Future<void> hide() async {
    hides++;
    running = false;
  }

  Future<void> close() => _actions.close();
}
