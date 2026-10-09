import 'dart:async';

import 'package:flutter/services.dart';

/// Buttons on the native floating window.
enum FloatingOverlayAction { togglePlay, close }

/// Android floating teleprompter window.
///
/// The native side is a microphone foreground service that adds a
/// [TYPE_APPLICATION_OVERLAY] view. Other platforms have no implementation;
/// call these methods only on Android.
abstract class CreatorOverlayApi {
  Future<bool> canDrawOverlays();

  Future<void> openOverlaySettings();

  Future<bool> isRunning();

  /// [labels] are the translated texts of the native window and its
  /// notification (keys: notificationTitle, notificationText, play, pause,
  /// close).
  Future<void> show({
    required List<String> words,
    required int activeWordIndex,
    required bool useMicrophone,
    Map<String, String> labels = const {},
  });

  Future<void> update(int activeWordIndex);

  Future<void> setPlaying(bool playing);

  /// Hidden while CueLine itself is on screen.
  Future<void> setVisible(bool visible);

  /// Sends CueLine to the background so the floating window is in view.
  Future<void> moveAppToBack();

  Future<void> hide();

  Stream<FloatingOverlayAction> get actions;
}

class CreatorOverlay implements CreatorOverlayApi {
  const CreatorOverlay();

  static const String channelName = 'app.cueline.teleprompter/creator_overlay';

  static const MethodChannel _channel = MethodChannel(channelName);

  static StreamController<FloatingOverlayAction>? _actions;

  @override
  Stream<FloatingOverlayAction> get actions {
    var controller = _actions;
    if (controller == null) {
      controller = StreamController<FloatingOverlayAction>.broadcast();
      _actions = controller;
      _channel.setMethodCallHandler((call) async {
        if (call.method != 'onAction') return;
        final action = switch (call.arguments) {
          'togglePlay' => FloatingOverlayAction.togglePlay,
          'close' => FloatingOverlayAction.close,
          _ => null,
        };
        if (action != null) _actions?.add(action);
      });
    }
    return controller.stream;
  }

  @override
  Future<bool> canDrawOverlays() async {
    final allowed = await _channel.invokeMethod<bool>('canDrawOverlays');
    return allowed ?? false;
  }

  @override
  Future<void> openOverlaySettings() async {
    await _channel.invokeMethod<void>('openOverlaySettings');
  }

  @override
  Future<bool> isRunning() async {
    final running = await _channel.invokeMethod<bool>('isRunning');
    return running ?? false;
  }

  @override
  Future<void> show({
    required List<String> words,
    required int activeWordIndex,
    required bool useMicrophone,
    Map<String, String> labels = const {},
  }) async {
    await _channel.invokeMethod<void>('show', {
      'words': words,
      'activeWordIndex': activeWordIndex,
      'useMicrophone': useMicrophone,
      'labels': labels,
    });
  }

  @override
  Future<void> update(int activeWordIndex) async {
    await _channel.invokeMethod<void>('update', {
      'activeWordIndex': activeWordIndex,
    });
  }

  @override
  Future<void> setPlaying(bool playing) async {
    await _channel.invokeMethod<void>('setPlaying', {'playing': playing});
  }

  @override
  Future<void> setVisible(bool visible) async {
    await _channel.invokeMethod<void>('setVisible', {'visible': visible});
  }

  @override
  Future<void> moveAppToBack() async {
    await _channel.invokeMethod<bool>('moveAppToBack');
  }

  @override
  Future<void> hide() async {
    await _channel.invokeMethod<void>('hide');
  }
}
