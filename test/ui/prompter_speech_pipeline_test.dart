import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:cueline/providers/feature_provider.dart';
import 'package:cueline/providers/prompter_config.dart';
import 'package:cueline/providers/prompter_provider.dart';
import 'package:cueline/providers/script_provider.dart';
import 'package:cueline/providers/settings_provider.dart';
import 'package:cueline/providers/speech_recognition_provider.dart';
import 'package:cueline/services/creator_mode.dart';
import 'package:cueline/services/creator_overlay.dart';
import 'package:cueline/services/floating_prompter.dart';
import 'package:cueline/services/speech_recognition_service.dart';
import 'package:cueline/ui/screens/prompter_screen.dart';
import 'package:cueline/ui/widgets/karaoke_text.dart';
import 'package:cueline/ui/widgets/prompter_bottom_bar.dart';

import '../../integration_test/fake_providers/features_fake_pro.dart';
import '../../integration_test/fake_providers/script_fake.dart';
import '../../integration_test/fake_providers/settings_fake.dart';
import '../helpers/fake_overlay.dart';
import '../helpers/fake_speech_to_text.dart';

/// Same gap [SpeechRecognitionService] waits before calling listen again.
const _restartDelay = Duration(milliseconds: 300);

/// 60 distinct words, long enough that following them has to scroll.
final _words = [
  for (final w in [
    'elma',
    'armut',
    'kiraz',
    'muz',
    'çilek',
    'karpuz',
    'kavun',
    'üzüm',
    'erik',
    'incir',
    'nar',
    'ayva',
    'limon',
    'mandalina',
    'portakal',
    'şeftali',
    'kayısı',
    'vişne',
    'dut',
    'hurma',
  ])
    for (final n in ['bir', 'iki', 'üç'].indexed) n.$1 == 0 ? w : '$w${n.$2}',
];

String _say(int from, int to) => _words.sublist(from, to + 1).join(' ');

/// The real screen: play, the speech provider, ScrollableText, KaraokeText.
/// Only the platform plugins are fakes.
void main() {
  late FakeSpeechToText speech;
  late SpeechRecognitionService service;
  late ProviderContainer container;
  late FakeOverlay overlay;

  /// Overlay permission of the next [pumpPrompter].
  var overlayCanDraw = true;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // wakelock_plus pigeon channel.
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => const StandardMessageCodec().encodeMessage(<Object?>[]),
    );
  });

  Future<void> pumpPrompter(
    WidgetTester tester, {
    Size size = const Size(1080, 1920),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    speech = FakeSpeechToText();
    service = SpeechRecognitionService(speech: speech);
    overlay = FakeOverlay()..canDraw = overlayCanDraw;
    overlayCanDraw = true;
    addTearDown(overlay.close);
    container = ProviderContainer(
      overrides: [
        creatorModeProvider.overrideWith((ref) {
          final mode = CreatorMode(overlay);
          ref.onDispose(mode.dispose);
          return mode;
        }),
        floatingPrompterProvider.overrideWith((ref) {
          final floating = FloatingPrompter(
            ref.watch(creatorModeProvider),
            overlay,
            isSupported: true,
          );
          ref.onDispose(floating.dispose);
          return floating;
        }),
        speechRecognitionServiceProvider.overrideWithValue(service),
        scriptProvider.overrideWith(
          () => ScriptFake(name: 'Prova', content: _words.join(' ')),
        ),
        settingsProvider.overrideWith(
          () => SettingsFake(
            SettingsState(config: PrompterConfiguration(fontSize: 40)),
          ),
        ),
        featuresProvider.overrideWith(FeaturesFakePro.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(service.dispose);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'unused',
        assetLoader: const _KeysAsText(),
        fallbackLocale: const Locale('en', 'US'),
        child: Builder(
          builder: (context) => UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: const PrompterScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  KaraokeController karaoke(WidgetTester tester) =>
      tester.widget<KaraokeText>(find.byType(KaraokeText)).controller;

  ScrollPosition scroll(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        ),
      )
      .position;

  /// The listening indicator pulses forever, so pumpAndSettle never returns
  /// while the microphone is on. 400 ms covers the 300 ms reveal scroll.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pressPlay(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(PrompterBottomBar),
        matching: find.byTooltip('PrompterScreen.IconButton_TogglePlayPause'),
      ),
    );
    await tester.pump();
    await tester.pump();
    await settle(tester);
  }

  Future<void> partial(WidgetTester tester, String text) async {
    speech.emitResult(text, isFinal: false);
    await settle(tester);
  }

  Future<void> finalResult(WidgetTester tester, String text) async {
    speech.emitResult(text, isFinal: true);
    await tester.pump();
    await tester.pump(_restartDelay);
    await settle(tester);
  }

  testWidgets('play starts listening and speech moves the active word', (
    tester,
  ) async {
    await pumpPrompter(tester);
    expect(karaoke(tester).activeWordIndex, -1);

    await pressPlay(tester);
    expect(container.read(prompterProvider).isPlaying, isTrue);
    expect(speech.listenCount, 1, reason: 'play opens the microphone');
    expect(speech.lastLocaleId, 'tr_TR', reason: 'the script is Turkish');
    expect(container.read(speechRecognitionProvider).isActive, isTrue);
    expect(karaoke(tester).speechMode, isTrue);

    // START → LISTENING → PARTIAL → ACTIVE INDEX → FINAL → CONTINUE
    await partial(tester, _say(0, 1));
    expect(karaoke(tester).activeWordIndex, 1);
    await partial(tester, _say(0, 3));
    expect(karaoke(tester).activeWordIndex, 3);
    await finalResult(tester, _say(0, 4));
    expect(karaoke(tester).activeWordIndex, 4);
    expect(speech.listenCount, 2, reason: 'next sentence is heard at once');

    final before = scroll(tester).pixels;
    var spoken = 4;
    while (spoken < 40) {
      final next = spoken + 2;
      await partial(tester, _say(spoken + 1, next - 1));
      await finalResult(tester, _say(spoken + 1, next));
      spoken = next;
      expect(karaoke(tester).activeWordIndex, spoken);
    }
    expect(
      scroll(tester).pixels,
      greaterThan(before),
      reason: 'the script scrolls with the voice',
    );
  });

  testWidgets('stop, start again, and leaving the screen', (tester) async {
    await pumpPrompter(tester);
    await pressPlay(tester);
    await partial(tester, _say(0, 2));
    expect(karaoke(tester).activeWordIndex, 2);

    await pressPlay(tester); // the same button stops
    expect(container.read(prompterProvider).isPlaying, isFalse);
    expect(service.isActive, isFalse);
    expect(karaoke(tester).speechMode, isFalse);

    // Results after stop do not move the script.
    speech.emitResult(_say(3, 5), isFinal: true);
    await settle(tester);
    expect(karaoke(tester).activeWordIndex, 2);

    await pressPlay(tester);
    expect(service.isActive, isTrue);
    await partial(tester, _say(3, 4));
    expect(karaoke(tester).activeWordIndex, 4);

    // Leave the prompter while listening.
    Navigator.of(tester.element(find.byType(PrompterScreen)))
        .pushReplacement(MaterialPageRoute(builder: (_) => const SizedBox()));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(service.isActive, isFalse, reason: 'leaving closes the microphone');
  });

  testWidgets('background and foreground keep following', (tester) async {
    await pumpPrompter(tester);
    await pressPlay(tester);
    await partial(tester, _say(0, 1));

    // START → LISTENING → BACKGROUND → FOREGROUND → LISTENING
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(service.isActive, isTrue, reason: 'paused, not stopped');
    expect(speech.isListening, isFalse);
    speech.emitStatus(SpeechToText.doneStatus);
    await tester.pump(_restartDelay);
    final listensWhileAway = speech.listenCount;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(speech.listenCount, listensWhileAway + 1);
    expect(speech.isListening, isTrue);

    await partial(tester, _say(2, 3));
    expect(karaoke(tester).activeWordIndex, 3);
  });

  testWidgets('seek drops the old utterance and follows from the new spot', (
    tester,
  ) async {
    await pumpPrompter(tester);
    await pressPlay(tester);
    await partial(tester, _say(0, 2));
    expect(karaoke(tester).activeWordIndex, 2);

    // START → LISTENING → SEEK → OLD STT RESULT → IGNORE → NEW STT
    karaoke(tester).seek(30);
    await settle(tester);
    await partial(tester, _say(0, 3));
    expect(karaoke(tester).activeWordIndex, 30);
    await finalResult(tester, _say(0, 4));
    expect(karaoke(tester).activeWordIndex, 30);

    await partial(tester, _say(31, 32));
    expect(karaoke(tester).activeWordIndex, 32);
  });

  testWidgets('landscape with a gesture bar lays out and follows', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 63, left: 120);
    await pumpPrompter(tester, size: const Size(2340, 1080));
    await pressPlay(tester);
    await partial(tester, _say(0, 2));
    expect(karaoke(tester).activeWordIndex, 2);
    expect(tester.takeException(), isNull, reason: 'no overflow');
  });

  group('floating prompter', () {
    final floatingButton = find.byTooltip('PrompterScreen.Floating.button');

    FloatingPrompter floating() => container.read(floatingPrompterProvider);

    Future<void> lastUpdateSent() =>
        container.read(creatorModeProvider).pending;

    void goToBackground(WidgetTester tester) {
      for (final state in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    }

    void comeBack(WidgetTester tester) {
      for (final state in const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    }

    testWidgets('speech keeps moving the window while CueLine is away', (
      tester,
    ) async {
      await pumpPrompter(tester);
      await pressPlay(tester);
      await partial(tester, _say(0, 2));

      await tester.tap(floatingButton);
      await settle(tester);
      expect(floating().status, FloatingPrompterStatus.active);
      expect(overlay.servicesStarted, 1);
      expect(overlay.shows.single.words, _words, reason: 'one script');
      expect(overlay.shows.single.index, 2, reason: 'same position');
      expect(overlay.playing, isTrue);
      expect(overlay.movedToBack, 1);

      // CueLine → background → social app in front.
      goToBackground(tester);
      await settle(tester);
      expect(overlay.visible, isTrue);
      expect(service.isActive, isTrue, reason: 'not paused for the window');
      expect(speech.isListening, isTrue);

      await partial(tester, _say(3, 5));
      await lastUpdateSent();
      expect(karaoke(tester).activeWordIndex, 5);
      expect(overlay.updates.last, 5);

      final listens = speech.listenCount;
      await finalResult(tester, _say(3, 6));
      await lastUpdateSent();
      expect(overlay.updates.last, 6);
      expect(speech.listenCount, listens + 1, reason: 'next sentence heard');

      // SEEK → OLD STT RESULT → IGNORE → NEW STT
      karaoke(tester).seek(30);
      await lastUpdateSent();
      final sentAfterSeek = overlay.updates.length;
      await partial(tester, _say(3, 9));
      await finalResult(tester, _say(3, 10));
      await partial(tester, _say(31, 32));
      await lastUpdateSent();
      expect(karaoke(tester).activeWordIndex, 32);
      expect(
        overlay.updates.skip(sentAfterSeek - 1),
        everyElement(greaterThanOrEqualTo(30)),
        reason: 'stale speech never pulled the window back',
      );

      // Pause and play from the window.
      overlay.tap(FloatingOverlayAction.togglePlay);
      await settle(tester);
      expect(container.read(prompterProvider).isPlaying, isFalse);
      expect(service.isActive, isFalse);
      expect(overlay.playing, isFalse);

      overlay.tap(FloatingOverlayAction.togglePlay);
      await settle(tester);
      expect(container.read(prompterProvider).isPlaying, isTrue);
      expect(service.isActive, isTrue);
      expect(overlay.playing, isTrue);
      await partial(tester, _say(33, 34));
      await lastUpdateSent();
      expect(overlay.updates.last, 34);

      // Back in CueLine the window steps aside but stays armed.
      comeBack(tester);
      await settle(tester);
      expect(overlay.visible, isFalse);
      expect(floating().isActive, isTrue);
      goToBackground(tester);
      await settle(tester);
      expect(overlay.visible, isTrue);

      // Close on the window.
      overlay.tap(FloatingOverlayAction.close);
      await settle(tester);
      expect(floating().status, FloatingPrompterStatus.off);
      expect(overlay.running, isFalse);
      expect(overlay.servicesStarted, 1, reason: 'never a second service');

      // Without the window, background pauses speech as before.
      expect(service.isActive, isTrue);
      comeBack(tester);
      goToBackground(tester);
      await settle(tester);
      expect(speech.isListening, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('leaving the prompter removes the window', (tester) async {
      await pumpPrompter(tester);
      await pressPlay(tester);
      await tester.tap(floatingButton);
      await settle(tester);
      expect(overlay.running, isTrue);

      Navigator.of(tester.element(find.byType(PrompterScreen)))
          .pushReplacement(MaterialPageRoute(builder: (_) => const SizedBox()));
      await settle(tester);

      expect(overlay.running, isFalse);
      expect(floating().status, FloatingPrompterStatus.off);
      expect(service.isActive, isFalse);
      expect(tester.takeException(), isNull);

      // A late button event after dispose does nothing.
      overlay.tap(FloatingOverlayAction.togglePlay);
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('permission: explain, not now, then allow in settings', (
      tester,
    ) async {
      overlayCanDraw = false;
      await pumpPrompter(tester);
      await pressPlay(tester);

      await tester.tap(floatingButton);
      await settle(tester);
      expect(
        find.text('PrompterScreen.Floating.permissionTitle'),
        findsOneWidget,
      );
      await tester.tap(find.text('PrompterScreen.Floating.notNow'));
      await settle(tester);
      expect(floating().status, FloatingPrompterStatus.off);
      expect(overlay.settingsOpened, 0);
      expect(overlay.servicesStarted, 0);
      expect(service.isActive, isTrue, reason: 'the prompter carries on');

      overlay.grantOnSettings = true;
      await tester.tap(floatingButton);
      await settle(tester);
      await tester.tap(find.text('PrompterScreen.Floating.openSettings'));
      await settle(tester);
      expect(overlay.settingsOpened, 1);
      expect(floating().status, FloatingPrompterStatus.awaitingPermission);

      // Settings covered CueLine; coming back finishes the start.
      goToBackground(tester);
      comeBack(tester);
      await settle(tester);
      expect(floating().status, FloatingPrompterStatus.active);
      expect(overlay.servicesStarted, 1);
    });

    testWidgets('without the microphone it explains and keeps the prompter', (
      tester,
    ) async {
      await pumpPrompter(tester);
      overlay.showError = 'microphone_permission_denied';
      await tester.tap(floatingButton);
      await settle(tester);

      expect(floating().status, FloatingPrompterStatus.failed);
      expect(
        find.text('PrompterScreen.Floating.microphoneRequired'),
        findsOneWidget,
      );
      expect(overlay.running, isFalse);
      // The message covers the play button until it times out.
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
      await pressPlay(tester);
      await partial(tester, _say(0, 1));
      expect(karaoke(tester).activeWordIndex, 1);
    });
  });
}

/// Translations are not under test; every key renders as itself.
class _KeysAsText extends AssetLoader {
  const _KeysAsText();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {};
}
