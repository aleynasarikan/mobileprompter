import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cueline/services/creator_mode.dart';
import 'package:cueline/services/creator_overlay.dart';

/// Floating prompter states.
///
/// ```
/// off ─request─▶ permissionRequired ─openSettings─▶ awaitingPermission
///  ▲                    │ notNow                         │ resumed
///  │                    ▼                                ▼
///  └──────────────── off ◀── denied ──────────── granted? ─▶ starting ─▶ active
///  ▲                                                          │ failure
///  └────────── close / prompter closed ◀── active      failed ◀┘
/// ```
///
/// Paused is not a state of its own: the overlay follows
/// [FloatingPrompter.playing], which mirrors the prompter's play state.
enum FloatingPrompterStatus {
  off,
  unsupported,
  permissionRequired,
  awaitingPermission,
  starting,
  active,
  failed,
}

/// Coordinates the Android floating window with the prompter.
///
/// It owns no karaoke state. [CreatorMode] mirrors the one
/// [KaraokeController] of the prompter into the window, so speech, matching
/// and seeking stay in the single existing pipeline.
class FloatingPrompter extends ChangeNotifier {
  FloatingPrompter(this._mode, this._overlay, {required this.isSupported});

  final CreatorMode _mode;
  final CreatorOverlayApi _overlay;

  /// Android 8+ only. iOS cannot draw over other apps.
  final bool isSupported;

  FloatingPrompterStatus _status = FloatingPrompterStatus.off;
  FloatingPrompterStatus get status => _status;

  /// Platform error code of the last failed start.
  String? errorCode;

  bool _playing = false;
  bool get playing => _playing;

  bool get isActive => _status == FloatingPrompterStatus.active;

  Map<String, String> _labels = const {};

  Stream<FloatingOverlayAction> get actions => _overlay.actions;

  void _set(FloatingPrompterStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }

  /// Starts the floating window, asking for the overlay permission first
  /// when it is missing. Must be called while CueLine is on screen: Android
  /// creates the microphone service only from the foreground.
  Future<void> request({Map<String, String> labels = const {}}) async {
    _labels = labels;
    if (!isSupported) {
      _set(FloatingPrompterStatus.unsupported);
      return;
    }
    // A second tap must not start a second service.
    if (_status == FloatingPrompterStatus.active ||
        _status == FloatingPrompterStatus.starting) {
      return;
    }
    errorCode = null;
    if (!await _canDraw()) {
      _set(FloatingPrompterStatus.permissionRequired);
      return;
    }
    await _activate();
  }

  /// The user agreed to the explanation; Android settings open next.
  Future<void> openPermissionSettings() async {
    _set(FloatingPrompterStatus.awaitingPermission);
    try {
      await _overlay.openOverlaySettings();
    } on PlatformException catch (e) {
      errorCode = e.code;
      _set(FloatingPrompterStatus.failed);
    }
  }

  /// "Not now": the prompter keeps working without the window.
  void declinePermission() {
    if (_status == FloatingPrompterStatus.permissionRequired) {
      _set(FloatingPrompterStatus.off);
    }
  }

  /// CueLine is on screen again.
  Future<void> onAppResumed() async {
    switch (_status) {
      case FloatingPrompterStatus.awaitingPermission:
        if (await _canDraw()) {
          await _activate();
        } else {
          // Denied in settings. Do not ask again until the next tap.
          _set(FloatingPrompterStatus.off);
        }
      case FloatingPrompterStatus.active:
        await _quietly(() => _overlay.setVisible(false));
      default:
        break;
    }
  }

  /// CueLine left the screen; the window takes over.
  Future<void> onAppHidden() async {
    if (!isActive) return;
    await _quietly(() => _overlay.setVisible(true));
  }

  void setPlaying(bool playing) {
    if (_playing == playing) return;
    _playing = playing;
    notifyListeners();
    if (isActive) unawaited(_quietly(() => _overlay.setPlaying(playing)));
  }

  /// Removes the window and stops the service. Safe to call in any state.
  Future<void> close() async {
    if (_status == FloatingPrompterStatus.off) return;
    final wasRunning =
        _status == FloatingPrompterStatus.active ||
        _status == FloatingPrompterStatus.starting;
    _set(FloatingPrompterStatus.off);
    if (wasRunning) await _quietly(_mode.hide);
  }

  Future<void> _activate() async {
    _set(FloatingPrompterStatus.starting);
    try {
      await _mode.show(useMicrophone: true, labels: _labels);
      if (_status != FloatingPrompterStatus.starting) {
        // Closed while starting.
        await _quietly(_mode.hide);
        return;
      }
      await _overlay.setPlaying(_playing);
      await _overlay.setVisible(true);
      _set(FloatingPrompterStatus.active);
      await _overlay.moveAppToBack();
    } on PlatformException catch (e) {
      errorCode = e.code;
      await _quietly(_mode.hide);
      _set(FloatingPrompterStatus.failed);
    }
  }

  Future<bool> _canDraw() async {
    try {
      return await _overlay.canDrawOverlays();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } on PlatformException {
      // The window is gone already; nothing to undo.
    } on MissingPluginException {
      // No native side (tests, other platforms).
    }
  }
}

final floatingPrompterProvider = Provider<FloatingPrompter>((ref) {
  final prompter = FloatingPrompter(
    ref.watch(creatorModeProvider),
    const CreatorOverlay(),
    isSupported: defaultTargetPlatform == TargetPlatform.android && !kIsWeb,
  );
  ref.onDispose(prompter.dispose);
  return prompter;
});
