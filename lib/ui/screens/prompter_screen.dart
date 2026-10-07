import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cueline/core/constants.dart';
import 'package:cueline/core/control_buttons.dart';
import 'package:cueline/core/debouncer.dart';
import 'package:cueline/models/keybinding.dart';
import 'package:cueline/providers/feature_provider.dart';
import 'package:cueline/providers/keybinding_provider.dart';
import 'package:cueline/providers/prompter_config.dart';
import 'package:cueline/providers/prompter_provider.dart';
import 'package:cueline/providers/settings_provider.dart';
import 'package:cueline/providers/speech_recognition_provider.dart';
import 'package:cueline/services/script_service.dart';
import 'package:cueline/services/speech_recognition_service.dart';
import 'package:cueline/ui/widgets/countdown_timer.dart';
import 'package:cueline/ui/widgets/current_chapter_banner.dart';
import 'package:cueline/ui/widgets/prompter_bottom_bar.dart';
import 'package:cueline/ui/widgets/prompter_control_buttons_overlay.dart';
import 'package:cueline/ui/widgets/prompter_speech_status.dart';
import 'package:cueline/ui/widgets/prompter_top_bar.dart';
import 'package:cueline/ui/widgets/vertical_margin.dart';
import 'package:cueline/ui/widgets/scrollable_text.dart';
import 'package:cueline/providers/script_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class _ControlsVisible extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
}

final controlsVisibleProvider = NotifierProvider<_ControlsVisible, bool>(
  _ControlsVisible.new,
);

const double _kPortraitTextChromeGap = 8;

double _portraitTopInset(BuildContext context, bool controlsVisible) {
  final safe = MediaQuery.viewPaddingOf(context).top;
  final bar = controlsVisible ? kPortraitTopBarBodyHeight : 0.0;
  return safe + bar + _kPortraitTextChromeGap;
}

double _portraitBottomInset(BuildContext context, bool controlsVisible) {
  final safe = MediaQuery.viewPaddingOf(context).bottom;
  final bar = controlsVisible ? kPortraitBottomBarBodyHeight : 0.0;
  return safe + bar + _kPortraitTextChromeGap;
}

class PrompterScreen extends ConsumerStatefulWidget {
  const PrompterScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _PrompterScreenState();
}

class _PrompterScreenState extends ConsumerState<PrompterScreen>
    with WidgetsBindingObserver {
  final _focusNode = FocusNode();
  late final ScrollableTextController _scrollableTextController;
  late final Debouncer _scrollableTextControllerSaveDebouncer;
  bool _lifecyclePausedListening = false;

  /// `ref` cannot be used in [dispose]. The service is keep-alive and owns
  /// the microphone, so it is captured here to close listening on exit.
  late final SpeechRecognitionService _speechService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speechService = ref.read(speechRecognitionServiceProvider);
    _scrollableTextController = ScrollableTextController();
    _scrollableTextControllerSaveDebouncer = PeriodicRunDebouncer(
      delay: Duration(seconds: 1),
      periodicDelay: Duration(seconds: 5),
    );
    WakelockPlus.enable();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollableTextController.scrollController.hasClients) return;
      // Offset 0 already places the first line on the reading line.
      // The old default (half the screen) skipped that lead-in and, for a
      // short script, scrolled the words off the top.
      final storedScrollOffset = ref.read(scriptProvider).scrollPosition;
      if (storedScrollOffset == null || storedScrollOffset <= 0) return;
      _scrollableTextController.jumpTo(storedScrollOffset);
    });

    ref.read(settingsProvider).whenData((data) {
      ref.read(prompterProvider.notifier).applySettings(data);
    });

    _scrollableTextController.scrollController.addListener(_saveOnScroll);
  }

  @override
  Widget build(BuildContext context) {
    final script = ref.watch(scriptProvider);
    final scriptIsEmpty = script.text.trim().isEmpty;

    ref.listen(settingsProvider, (previous, next) async {
      next.whenData((data) {
        ref.read(prompterProvider.notifier).applySettings(data);
      });
    });

    ref.listen(prompterProvider.select((p) => p.isPlaying), (_, playing) {
      final speech = ref.read(speechRecognitionProvider.notifier);
      if (playing) {
        unawaited(
          speech.start(
            preferredLocaleId: preferredSpeechLocaleIdForScript(
              ref.read(scriptProvider).text,
            ),
          ),
        );
      } else {
        _lifecyclePausedListening = false;
        unawaited(speech.stop());
      }
    });

    final (:prompterConfig, :displayCountdown) = ref.watch(
      prompterProvider.select(
        (p) => (prompterConfig: p.config, displayCountdown: p.displayCountdown),
      ),
    );
    final controlsVisible = ref.watch(controlsVisibleProvider);
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final scrollableText = ScrollableText(
      controller: _scrollableTextController,
      text: script.text,
      style: TextStyle(
        fontSize: prompterDisplayFontSize(
          prompterConfig.fontSize,
          MediaQuery.orientationOf(context),
        ),
        fontFamily: prompterConfig.fontFamily,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      sideMargin:
          (MediaQuery.of(context).size.width / 2) *
          (prompterConfig.sideMargin / 100),
    );

    return KeyboardListener(
      onKeyEvent: (keyEvent) {
        if (keyEvent is KeyDownEvent) {
          _runEventAction(
            ref.read(keybindingsProvider.notifier).actionForEvent(keyEvent),
          );
        }
      },
      focusNode: _focusNode,
      autofocus: true,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () {
                ref.read(controlsVisibleProvider.notifier).toggle();
              },
              child: isPortrait
                  ? Padding(
                      padding: EdgeInsets.only(
                        top: _portraitTopInset(context, controlsVisible),
                        bottom: _portraitBottomInset(context, controlsVisible),
                      ),
                      child: scrollableText,
                    )
                  : SafeArea(
                      minimum: const EdgeInsets.all(16.0),
                      child: scrollableText,
                    ),
            ),
            if (prompterConfig.displayVerticalMarginBoxes)
              VerticalMargin(
                heightRatio: prompterConfig.verticalMarginBoxesHeight,
                color: Theme.of(context).canvasColor,
                fade: prompterConfig.verticalMarginBoxesFadeEnabled,
                // NOTE: fadeLength should be normalized to [0, 1]
                fadeLength: prompterConfig.verticalMarginBoxesFadeLength / 100,
              ),
            if (prompterConfig.displayReadingIndicatorBoxes)
              VerticalMargin(
                heightRatio: prompterConfig.readingIndicatorBoxesHeight,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(60),
              ),
            CurrentChapterBanner(
              offset: EdgeInsets.only(
                top: isPortrait
                    ? _portraitTopInset(context, controlsVisible)
                    : (controlsVisible ? 64 : 0),
              ),
            ),
            if ((!controlsVisible ||
                    (prompterConfig.controlButtonsPosition ==
                            ControlButtonsPosition.left ||
                        prompterConfig.controlButtonsPosition ==
                            ControlButtonsPosition.right)) &&
                prompterConfig.showControlButtons)
              PrompterControlButtonsOverlay(),
            if (controlsVisible) PrompterTopBar(),
            if (controlsVisible) PrompterBottomBar(),
            if (scriptIsEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    context.tr('PrompterScreen.Speech.emptyScript'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: _portraitBottomInset(context, controlsVisible) + 8,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: PrompterSpeechStatus(controlsVisible: controlsVisible),
              ),
            ),
            if (displayCountdown && prompterConfig.countdownDuration > 0)
              CountdownTimer(
                duration: prompterConfig.countdownDuration.toInt(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final speech = ref.read(speechRecognitionProvider.notifier);
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (ref.read(speechRecognitionProvider).isActive) {
          _lifecyclePausedListening = true;
          unawaited(speech.pause());
        }
      case AppLifecycleState.resumed:
        if (_lifecyclePausedListening) {
          _lifecyclePausedListening = false;
          if (ref.read(prompterProvider).isPlaying) {
            unawaited(speech.resumeListening());
          }
        }
      case AppLifecycleState.detached:
        unawaited(speech.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_speechService.stop());
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    WakelockPlus.disable();
    _focusNode.dispose();
    _scrollableTextController.dispose();
    _scrollableTextControllerSaveDebouncer.dispose();
    super.dispose();
  }

  Future<void> _runEventAction(
    Future<List<KeybindingAction>> actionForEvent,
  ) async {
    if (!context.mounted) {
      throw StateError("Context not available.");
    }

    for (final action in await actionForEvent) {
      switch (action) {
        case KeybindingAction.playPause:
          _gatedKeybinding(
            Feature.playPause,
            () => ref.read(prompterProvider.notifier).togglePlayPause(),
          );
          break;
        case KeybindingAction.scrollUp:
          _gatedKeybinding(
            Feature.keybindings,
            () => _scrollableTextController.jumpRelative(-75),
          );
          break;
        case KeybindingAction.scrollDown:
          _gatedKeybinding(
            Feature.keybindings,
            () => _scrollableTextController.jumpRelative(75),
          );
          break;
        case KeybindingAction.scrollUpSmall:
          _gatedKeybinding(
            Feature.keybindings,
            () => _scrollableTextController.jumpRelative(-25),
          );
          break;
        case KeybindingAction.scrollDownSmall:
          _gatedKeybinding(
            Feature.keybindings,
            () => _scrollableTextController.jumpRelative(25),
          );
          break;
        case KeybindingAction.pageUp:
          _gatedKeybinding(
            Feature.keybindings,
            () => _scrollableTextController.jumpRelative(
              -MediaQuery.of(context).size.height,
            ),
          );
          break;
        case KeybindingAction.pageDown:
          _gatedKeybinding(
            Feature.keybindings,
            () => _scrollableTextController.jumpRelative(
              MediaQuery.of(context).size.height,
            ),
          );
          break;
        case KeybindingAction.jumpStart:
          _gatedKeybinding(
            Feature.keybindings,
            () => _scrollableTextController.jumpTo(0),
          );
          break;
        case KeybindingAction.jumpEnd:
          _gatedKeybinding(
            Feature.keybindings,
            () => _scrollableTextController.jumpTo(
              _scrollableTextController
                  .scrollController
                  .position
                  .maxScrollExtent,
            ),
          );
          break;
        case KeybindingAction.toggleControls:
          _gatedKeybinding(
            Feature.keybindings,
            () => ref.read(controlsVisibleProvider.notifier).toggle(),
          );
          break;
        case KeybindingAction.fontSizeUp:
          _gatedKeybinding(
            Feature.fontSize,
            () => ref.read(prompterProvider.notifier).increaseFontSize(1),
          );
          break;
        case KeybindingAction.fontSizeDown:
          _gatedKeybinding(
            Feature.fontSize,
            () => ref.read(prompterProvider.notifier).decreaseFontSize(1),
          );
          break;
        case KeybindingAction.speedUp:
          _gatedKeybinding(
            Feature.keybindings,
            () => ref.read(prompterProvider.notifier).increaseSpeed(.1),
          );
          break;
        case KeybindingAction.speedDown:
          _gatedKeybinding(
            Feature.keybindings,
            () => ref.read(prompterProvider.notifier).decreaseSpeed(.1),
          );
          break;
        case KeybindingAction.openSettings:
          _gatedKeybinding(
            Feature.keybindings,
            () => context.push('/settings'),
          );
          break;
        case KeybindingAction.saveSettingsFromPrompter:
          _gatedKeybinding(
            Feature.keybindings,
            () => ref
                .read(settingsProvider.notifier)
                .applySettingsFromPrompter(ref.read(prompterProvider)),
          );
          break;
      }
    }
  }

  void _gatedKeybinding(Feature feature, Function() action) {
    final isEnabled = ref.read(
      featuresProvider.select((s) => s.features.contains(feature)),
    );

    if (isEnabled) {
      action();
    }
  }

  void _saveOnScroll() {
    _scrollableTextControllerSaveDebouncer.run(_saveScrollPosition);
  }

  void _saveScrollPosition() {
    final scriptId = ref.read(scriptProvider).id;
    final scrollOffset = _scrollableTextController.scrollController.offset;

    ref.read(scriptProvider.notifier).setScrollPosition(scrollOffset);
    if (scriptId != null) {
      ref
          .read(scriptServiceProvider.notifier)
          .updateScrollPosition(scriptId, scrollOffset);
    }
  }
}
