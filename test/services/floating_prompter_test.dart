import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cueline/services/creator_mode.dart';
import 'package:cueline/services/creator_overlay.dart';
import 'package:cueline/services/floating_prompter.dart';

import '../helpers/fake_overlay.dart';

void main() {
  late FakeOverlay overlay;
  late CreatorMode mode;
  late FloatingPrompter floating;
  late _Stage stage;

  FloatingPrompter build({bool supported = true}) {
    final prompter = FloatingPrompter(mode, overlay, isSupported: supported);
    addTearDown(prompter.dispose);
    return prompter;
  }

  setUp(() {
    overlay = FakeOverlay();
    mode = CreatorMode(overlay);
    stage = _Stage(['bir', 'iki', 'üç', 'dört']);
    mode.attach(
      listenable: stage,
      words: () => stage.words,
      index: () => stage.index,
    );
    floating = build();
  });

  tearDown(() async {
    mode.dispose();
    stage.dispose();
    await overlay.close();
  });

  group('permission', () {
    test(
      'with permission it starts at once and hands over to the window',
      () async {
        floating.setPlaying(true);
        await floating.request(labels: const {'play': 'Oynat'});

        expect(floating.status, FloatingPrompterStatus.active);
        expect(overlay.servicesStarted, 1);
        expect(overlay.shows.single.words, ['bir', 'iki', 'üç', 'dört']);
        expect(overlay.shows.single.labels, {'play': 'Oynat'});
        expect(overlay.playing, isTrue);
        expect(overlay.visible, isTrue);
        expect(overlay.movedToBack, 1, reason: 'CueLine steps aside');
      },
    );

    test('without permission it asks first and starts nothing', () async {
      overlay.canDraw = false;
      await floating.request();

      expect(floating.status, FloatingPrompterStatus.permissionRequired);
      expect(overlay.servicesStarted, 0);
      expect(overlay.settingsOpened, 0, reason: 'the user decides first');
    });

    test('"not now" keeps the normal prompter', () async {
      overlay.canDraw = false;
      await floating.request();
      floating.declinePermission();

      expect(floating.status, FloatingPrompterStatus.off);
      expect(overlay.settingsOpened, 0);
      expect(overlay.servicesStarted, 0);
    });

    test('granted in settings starts when CueLine is back', () async {
      overlay
        ..canDraw = false
        ..grantOnSettings = true;
      await floating.request();
      await floating.openPermissionSettings();
      expect(floating.status, FloatingPrompterStatus.awaitingPermission);

      await floating.onAppResumed();

      expect(floating.status, FloatingPrompterStatus.active);
      expect(overlay.servicesStarted, 1);
    });

    test('denied in settings returns to off without asking again', () async {
      overlay.canDraw = false;
      await floating.request();
      await floating.openPermissionSettings();
      await floating.onAppResumed();
      await floating.onAppResumed();

      expect(floating.status, FloatingPrompterStatus.off);
      expect(overlay.settingsOpened, 1);
      expect(overlay.servicesStarted, 0);
    });

    test(
      'permission revoked later is asked for again on the next tap',
      () async {
        await floating.request();
        await floating.close();
        overlay.canDraw = false;

        await floating.request();

        expect(floating.status, FloatingPrompterStatus.permissionRequired);
      },
    );
  });

  group('lifecycle', () {
    test('a second request does not start a second service', () async {
      await Future.wait([floating.request(), floating.request()]);
      await floating.request();

      expect(overlay.servicesStarted, 1);
      expect(overlay.shows, hasLength(1));
    });

    test('close stops the service and is safe to repeat', () async {
      await floating.request();
      await floating.close();
      await floating.close();

      expect(floating.status, FloatingPrompterStatus.off);
      expect(overlay.running, isFalse);
      expect(overlay.hides, 1);
    });

    test('closing before anything started touches nothing', () async {
      await floating.close();
      expect(overlay.hides, 0);
    });

    test('the window hides while CueLine is on screen', () async {
      await floating.request();
      await floating.onAppResumed();
      expect(overlay.visible, isFalse);
      await floating.onAppHidden();
      expect(overlay.visible, isTrue);
    });

    test('visibility is not touched while off', () async {
      await floating.onAppHidden();
      await floating.onAppResumed();
      expect(overlay.visibleCalls, isEmpty);
    });

    test('play and pause reach the window only while it is shown', () async {
      floating.setPlaying(true);
      expect(overlay.playingCalls, isEmpty);

      await floating.request();
      floating.setPlaying(false);
      floating.setPlaying(false);
      floating.setPlaying(true);

      expect(overlay.playingCalls, [true, false, true]);
    });

    test('a missing microphone permission fails cleanly', () async {
      overlay.showError = 'microphone_permission_denied';
      await floating.request();

      expect(floating.status, FloatingPrompterStatus.failed);
      expect(floating.errorCode, 'microphone_permission_denied');
      expect(overlay.running, isFalse);
      expect(overlay.movedToBack, 0, reason: 'CueLine stays in front');

      overlay.showError = null;
      await floating.request();
      expect(floating.status, FloatingPrompterStatus.active);
    });

    test('iOS and other platforms say unsupported', () async {
      final ios = build(supported: false);
      await ios.request();
      expect(ios.status, FloatingPrompterStatus.unsupported);
      expect(overlay.servicesStarted, 0);
    });

    test('overlay buttons arrive as actions', () async {
      final received = <FloatingOverlayAction>[];
      final sub = floating.actions.listen(received.add);
      addTearDown(sub.cancel);

      overlay.tap(FloatingOverlayAction.togglePlay);
      overlay.tap(FloatingOverlayAction.close);

      expect(received, [
        FloatingOverlayAction.togglePlay,
        FloatingOverlayAction.close,
      ]);
    });
  });

  group('one karaoke pipeline', () {
    test('the window shows the active word of the stage controller', () async {
      await floating.request();
      stage.move(1);
      stage.move(2);
      await mode.pending;

      expect(overlay.updates, [
        2,
      ], reason: 'a burst of changes sends only the latest word');

      stage.move(3);
      await mode.pending;
      expect(overlay.updates, [2, 3]);
    });

    test('nothing is sent while the window is closed', () async {
      stage.move(1);
      await mode.pending;
      expect(overlay.shows, isEmpty);
      expect(overlay.updates, isEmpty);

      await floating.request();
      await floating.close();
      stage.move(3);
      await mode.pending;
      expect(overlay.updates, isEmpty);
    });
  });
}

/// Stands in for the prompter's KaraokeController.
class _Stage extends ChangeNotifier {
  _Stage(this.words);

  final List<String> words;
  int index = -1;

  void move(int to) {
    index = to;
    notifyListeners();
  }
}
