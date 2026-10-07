import 'package:flutter/services.dart';

/// Android floating teleprompter window.
///
/// The native side is a foreground service that adds a
/// [TYPE_APPLICATION_OVERLAY] text view. Other platforms have no
/// implementation; call these methods only on Android.
abstract class CreatorOverlayApi {
  Future<bool> canDrawOverlays();

  Future<void> openOverlaySettings();

  Future<bool> isRunning();

  Future<void> show({
    required List<String> words,
    required int activeWordIndex,
    required bool useMicrophone,
  });

  Future<void> update(int activeWordIndex);

  Future<void> hide();
}

class CreatorOverlay implements CreatorOverlayApi {
  const CreatorOverlay();

  static const String channelName =
      'app.cueline.teleprompter/creator_overlay';

  static const MethodChannel _channel = MethodChannel(channelName);

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
  }) async {
    await _channel.invokeMethod<void>('show', {
      'words': words,
      'activeWordIndex': activeWordIndex,
      'useMicrophone': useMicrophone,
    });
  }

  @override
  Future<void> update(int activeWordIndex) async {
    await _channel.invokeMethod<void>('update', {
      'activeWordIndex': activeWordIndex,
    });
  }

  @override
  Future<void> hide() async {
    await _channel.invokeMethod<void>('hide');
  }
}
