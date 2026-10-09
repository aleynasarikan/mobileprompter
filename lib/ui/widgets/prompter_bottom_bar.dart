import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cueline/core/constants.dart';
import 'package:cueline/core/control_buttons.dart';
import 'package:cueline/core/disabled_feature_screen_state.dart';
import 'package:cueline/core/fonts.dart';
import 'package:cueline/providers/combining_provider.dart';
import 'package:cueline/providers/feature_provider.dart';
import 'package:cueline/providers/fonts_provider.dart';
import 'package:cueline/providers/prompter_config.dart';
import 'package:cueline/providers/prompter_provider.dart';
import 'package:cueline/providers/settings_provider.dart';
import 'package:cueline/providers/speech_recognition_provider.dart';
import 'package:cueline/providers/theme_provider.dart';
import 'package:cueline/ui/screens/reset_settings_screen.dart';
import 'package:cueline/ui/theme/cueline_tokens.dart';

class _BoolToggle extends Notifier<bool> {
  _BoolToggle(this._initial);
  final bool _initial;
  @override
  bool build() => _initial;
  void toggle() => state = !state;
}

final fontSettingsVisibleProvider = NotifierProvider<_BoolToggle, bool>(
  () => _BoolToggle(false),
);
final displaySettingsVisibleProvider = NotifierProvider<_BoolToggle, bool>(
  () => _BoolToggle(false),
);

/// Height of the portrait bottom bar above the system navigation inset.
const double kPortraitBottomBarBodyHeight = 56;

class PrompterBottomBar extends ConsumerWidget {
  const PrompterBottomBar({super.key});

  IconData _playIcon(WidgetRef ref) {
    final playing = ref.watch(prompterProvider.select((p) => p.isPlaying));
    if (!playing) return Icons.play_arrow_rounded;
    // isActive, not isListening: the recognizer restarts after every
    // sentence and the icon must not blink through those short gaps.
    final listening = ref.watch(
      speechRecognitionProvider.select((s) => s.isActive),
    );
    return listening ? Icons.stop_rounded : Icons.mic_none;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSettingsVisible = ref.watch(fontSettingsVisibleProvider);
    final displaySettingsVisible = ref.watch(displaySettingsVisibleProvider);

    return Stack(
      children: [
        Positioned(bottom: 0, left: 0, right: 0, child: _chrome(context, ref)),
        if (fontSettingsVisible) SafeArea(child: _FontSettingsDialog()),
        if (displaySettingsVisible) SafeArea(child: _DisplaySettingsDialog()),
      ],
    );
  }

  Widget _chrome(BuildContext context, WidgetRef ref) {
    final tokens = CueLineTheme.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final playing = ref.watch(prompterProvider.select((p) => p.isPlaying));
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ColoredBox(
      color: tokens.chromeFill,
      child: Padding(
        padding: EdgeInsets.only(
          left: CueLineTokens.spaceSm,
          right: CueLineTokens.spaceSm,
          bottom: bottomInset,
        ),
        child: SizedBox(
          height: kPortraitBottomBarBodyHeight,
          child: Row(
            children: [
              _FeatureGatedIconButton(
                feature: Feature.textSettings,
                displayText: context.tr("PrompterScreen.IconButton_TextFormat"),
                icon: Icon(Icons.text_fields, color: onSurface),
                tooltip: context.tr("PrompterScreen.IconButton_TextFormat"),
                onPressed: () =>
                    ref.read(fontSettingsVisibleProvider.notifier).toggle(),
              ),
              const Spacer(),
              Semantics(
                button: true,
                label: context.tr("PrompterScreen.IconButton_TogglePlayPause"),
                child: IconButton(
                  iconSize: CueLineTokens.iconLg,
                  style: IconButton.styleFrom(
                    backgroundColor: playing
                        ? primary.withValues(alpha: 0.18)
                        : primary,
                    foregroundColor: playing
                        ? primary
                        : Theme.of(context).colorScheme.onPrimary,
                    minimumSize: const Size(
                      CueLineTokens.minTouch,
                      CueLineTokens.minTouch,
                    ),
                    maximumSize: const Size(
                      CueLineTokens.minTouch + 4,
                      CueLineTokens.minTouch + 4,
                    ),
                  ),
                  tooltip: context.tr(
                    "PrompterScreen.IconButton_TogglePlayPause",
                  ),
                  onPressed: () {
                    final enabled = ref.read(
                      featuresProvider.select(
                        (s) => s.features.contains(Feature.playPause),
                      ),
                    );
                    if (enabled) {
                      ref.read(prompterProvider.notifier).togglePlayPause();
                    }
                  },
                  icon: Icon(_playIcon(ref)),
                ),
              ),
              const Spacer(),
              _FeatureGatedIconButton(
                feature: Feature.displaySettings,
                displayText: context.tr(
                  "PrompterScreen.IconButton_DisplaySettings",
                ),
                icon: Icon(Icons.tune, color: onSurface),
                tooltip: context.tr(
                  "PrompterScreen.IconButton_DisplaySettings",
                ),
                onPressed: () =>
                    ref.read(displaySettingsVisibleProvider.notifier).toggle(),
              ),
              IconButton(
                icon: Icon(Icons.more_horiz, color: onSurface),
                tooltip: context.tr("PrompterScreen.IconButton_Settings"),
                onPressed: () => _showMoreSheet(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final speed = ref.watch(
              prompterProvider.select((p) => p.config.scrollSpeed),
            );
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CueLineTokens.spaceMd,
                  CueLineTokens.spaceSm,
                  CueLineTokens.spaceMd,
                  CueLineTokens.spaceLg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text(
                        context.tr(
                          "PrompterScreen.speed",
                          args: [speed.toStringAsFixed(1)],
                        ),
                      ),
                      leading: IconButton(
                        icon: const Icon(Icons.remove),
                        tooltip: context.tr(
                          "PrompterScreen.IconButton_DecreaseSpeed",
                        ),
                        onPressed: () => ref
                            .read(prompterProvider.notifier)
                            .decreaseSpeed(.1),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: context.tr(
                          "PrompterScreen.IconButton_IncreaseSpeed",
                        ),
                        onPressed: () => ref
                            .read(prompterProvider.notifier)
                            .increaseSpeed(.1),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.save_outlined),
                      title: Text(context.tr("PrompterScreen.IconButton_Save")),
                      onTap: () {
                        ref
                            .read(settingsProvider.notifier)
                            .applySettingsFromPrompter(
                              ref.read(prompterProvider),
                            );
                        Navigator.pop(sheetContext);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: Text(
                        context.tr("PrompterScreen.IconButton_Settings"),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        context.push("/settings");
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FontSettingsDialog extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:fontSize, :fontFamily) = ref.watch(
      prompterProvider.select(
        (p) => (fontSize: p.config.fontSize, fontFamily: p.config.fontFamily),
      ),
    );
    final themes = ref.watch(themesProvider);
    final fonts = ref.watch(fontsProvider);
    final combinedAsyncData = ref.watch(
      combinedAsyncDataProvider.call([themes, fonts]),
    );

    return switch (combinedAsyncData) {
      AsyncData(:final value) => Theme(
        data: (value.states[0] as ThemesState).darkTheme,
        child: SimpleDialog(
          title: Text(
            context.tr("PrompterScreen.SimpleDialog_TextFormat.title"),
            style: TextStyle(fontSize: 18),
          ),
          alignment: Alignment(1, 0),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height - 160,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FeatureGate(
                    feature: Feature.fontSize,
                    displayText: context.tr(
                      "SettingsScreen.NumberAppSetting_DefaultFontSize",
                    ),
                    child: Row(
                      children: [
                        Text(
                          context.tr(
                            "PrompterScreen.SimpleDialog_TextFormat.fontsize",
                            args: [
                              prompterDisplayFontSize(
                                fontSize,
                                MediaQuery.orientationOf(context),
                              ).toStringAsFixed(1),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.text_increase),
                          tooltip: context.tr(
                            "PrompterScreen.SimpleDialog_TextFormat.IconButton_TextIncrease",
                          ),
                          onPressed: () => ref
                              .read(prompterProvider.notifier)
                              .increaseFontSize(2),
                        ),
                        IconButton(
                          icon: Icon(Icons.text_decrease),
                          tooltip: context.tr(
                            "PrompterScreen.SimpleDialog_TextFormat.IconButton_TextDecrease",
                          ),
                          onPressed: () => ref
                              .read(prompterProvider.notifier)
                              .decreaseFontSize(2),
                        ),
                      ],
                    ),
                  ),
                  _FeatureGate(
                    feature: Feature.textAlignment,
                    displayText: context.tr(
                      "SettingsScreen.DropdownAppSetting_DefaultTextAlignment",
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.format_align_left),
                          tooltip: context.tr(
                            "PrompterScreen.SimpleDialog_TextFormat.IconButton_Left",
                          ),
                          onPressed: () => ref
                              .read(prompterProvider.notifier)
                              .setAlignment(TextAlign.left),
                        ),
                        IconButton(
                          icon: Icon(Icons.format_align_center),
                          tooltip: context.tr(
                            "PrompterScreen.SimpleDialog_TextFormat.IconButton_Center",
                          ),
                          onPressed: () => ref
                              .read(prompterProvider.notifier)
                              .setAlignment(TextAlign.center),
                        ),
                        IconButton(
                          icon: Icon(Icons.format_align_right),
                          tooltip: context.tr(
                            "PrompterScreen.SimpleDialog_TextFormat.IconButton_Right",
                          ),
                          onPressed: () => ref
                              .read(prompterProvider.notifier)
                              .setAlignment(TextAlign.right),
                        ),
                        IconButton(
                          icon: Icon(Icons.format_align_justify),
                          tooltip: context.tr(
                            "PrompterScreen.SimpleDialog_TextFormat.IconButton_Justified",
                          ),
                          onPressed: () => ref
                              .read(prompterProvider.notifier)
                              .setAlignment(TextAlign.justify),
                        ),
                      ],
                    ),
                  ),
                  _FeatureGate(
                    feature: Feature.fontFamily,
                    displayText: context.tr(
                      "SettingsScreen.DropdownAppSetting_DefaultFontFamily",
                    ),
                    child: Row(
                      children: [
                        DropdownButton(
                          value: fontFamily,
                          items: (value.states[1] as List<TiefPromptFontsFile>)
                              .map(
                                (font) => DropdownMenuItem(
                                  value: font.name,
                                  child: Text(
                                    font.name,
                                    style: TextStyle(fontFamily: font.name),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => ref
                              .read(prompterProvider.notifier)
                              .setFontFamily(value ?? 'Roboto'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      AsyncLoading() => Scaffold(
        appBar: AppBar(
          title: Text(context.tr("SettingsScreen.KeybindingsSettings.Title")),
        ),
        body: Center(
          child: CircularProgressIndicator(
            color:
                ref.read(settingsProvider).value?.appPrimaryColor ??
                kBrandAccent,
          ),
        ),
      ),
      _ => const ResetSettingsView(),
    };
  }
}

class _DisplaySettingsDialog extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prompterConfig = ref.watch(prompterProvider.select((p) => p.config));
    final themes = ref.watch(themesProvider);

    return switch (themes) {
      AsyncData(:final value) => Theme(
        data: value.darkTheme,
        child: SimpleDialog(
          title: Text(
            context.tr("PrompterScreen.SimpleDialog_DisplaySettings.title"),
            style: TextStyle(fontSize: 18),
          ),
          alignment: Alignment(-1, 0),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height - 160,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _FeatureGatedIconButton(
                            feature: Feature.flipX,
                            displayText: context.tr(
                              "SettingsScreen.BooleanAppSetting_DefaultFlipX",
                            ),
                            icon: Icon(Icons.flip),
                            isSelected: prompterConfig.mirroredX,
                            tooltip: context.tr(
                              "PrompterScreen.SimpleDialog_DisplaySettings.IconButton_FlipX",
                            ),
                            onPressed: () => ref
                                .read(prompterProvider.notifier)
                                .toggleMirroredX(),
                          ),
                          _FeatureGatedIconButton(
                            feature: Feature.flipY,
                            displayText: context.tr(
                              "SettingsScreen.BooleanAppSetting_DefaultFlipY",
                            ),
                            icon: RotatedBox(
                              quarterTurns: 1,
                              child: Icon(Icons.flip),
                            ),
                            isSelected: prompterConfig.mirroredY,
                            tooltip: context.tr(
                              "PrompterScreen.SimpleDialog_DisplaySettings.IconButton_FlipY",
                            ),
                            onPressed: () => ref
                                .read(prompterProvider.notifier)
                                .toggleMirroredY(),
                          ),
                          _FeatureGatedIconButton(
                            feature: Feature.markdown,
                            displayText: context.tr(
                              "SettingsScreen.BooleanAppSetting_Markdown",
                            ),
                            icon: Text(
                              "M",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: prompterConfig.markdownEnabled
                                    ? Theme.of(context).colorScheme.primary
                                    : IconTheme.of(context).color,
                              ),
                            ),
                            isSelected: prompterConfig.markdownEnabled,
                            tooltip: context.tr(
                              "PrompterScreen.SimpleDialog_DisplaySettings.IconButton_Markdown",
                            ),
                            onPressed: () => ref
                                .read(prompterProvider.notifier)
                                .toggleMarkdownEnabled(),
                          ),
                          _FeatureGatedIconButton(
                            feature: Feature.currentChapter,
                            displayText: context.tr(
                              "SettingsScreen.BooleanAppSetting_ShowCurrentChapter",
                            ),
                            icon: Text(
                              "C",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: prompterConfig.markdownEnabled
                                    ? (prompterConfig.showCurrentChapter
                                          ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                          : IconTheme.of(context).color)
                                    : Theme.of(context).disabledColor,
                              ),
                            ),
                            isSelected: prompterConfig.showCurrentChapter,
                            tooltip: context.tr(
                              "PrompterScreen.SimpleDialog_DisplaySettings.IconButton_ShowCurrentChapter",
                            ),
                            onPressed: prompterConfig.markdownEnabled
                                ? () => ref
                                      .read(prompterProvider.notifier)
                                      .toggleCurrentChapterEnabled()
                                : null,
                          ),
                        ],
                      ),
                      _FeatureGate(
                        feature: Feature.readingIndicatorBoxes,
                        displayText: context.tr(
                          "SettingsScreen.BooleanAppSetting_ReadingIndicatorBoxes",
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.indeterminate_check_box_outlined,
                              ),
                              isSelected:
                                  prompterConfig.displayReadingIndicatorBoxes,
                              tooltip: context.tr(
                                "PrompterScreen.SimpleDialog_DisplaySettings.IconButton_ReadingIndicatorBoxes",
                              ),
                              onPressed: () => ref
                                  .read(prompterProvider.notifier)
                                  .toggleDisplayReadingIndicatorBoxes(),
                            ),
                            Slider(
                              value: prompterConfig.readingIndicatorBoxesHeight,
                              min: 0.0,
                              max: 100.0,
                              divisions: 20,
                              label: prompterConfig.readingIndicatorBoxesHeight
                                  .toStringAsFixed(2),
                              onChanged: (value) => ref
                                  .read(prompterProvider.notifier)
                                  .setReadingIndicatorBoxHeight(value),
                            ),
                          ],
                        ),
                      ),
                      _FeatureGate(
                        feature: Feature.verticalMargins,
                        displayText: context.tr(
                          "SettingsScreen.BooleanAppSetting_VerticalMarginBoxes",
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.margin),
                              isSelected:
                                  prompterConfig.displayVerticalMarginBoxes,
                              tooltip: context.tr(
                                "PrompterScreen.SimpleDialog_DisplaySettings.IconButton_VerticalMarginBoxes",
                              ),
                              onPressed: () => ref
                                  .read(prompterProvider.notifier)
                                  .toggleDisplayVerticalMarginBoxes(),
                            ),
                            Slider(
                              value: prompterConfig.verticalMarginBoxesHeight,
                              min: 0.0,
                              max: 100.0,
                              divisions: 20,
                              label: prompterConfig.verticalMarginBoxesHeight
                                  .toStringAsFixed(2),
                              onChanged: (value) => ref
                                  .read(prompterProvider.notifier)
                                  .setVerticalMarginBoxHeight(value),
                            ),
                          ],
                        ),
                      ),
                      if (prompterConfig.displayVerticalMarginBoxes)
                        _FeatureGate(
                          feature: Feature.verticalMarginFade,
                          displayText: context.tr(
                            "SettingsScreen.BooleanAppSetting_VerticalMarginBoxes_FadeEnabled",
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.gradient),
                                tooltip: context.tr(
                                  "PrompterScreen.SimpleDialog_DisplaySettings.IconButton_FadeEnabled",
                                ),
                                isSelected: prompterConfig
                                    .verticalMarginBoxesFadeEnabled,
                                onPressed: () => ref
                                    .read(prompterProvider.notifier)
                                    .toggleVerticalMarginBoxesFadeEnabled(),
                              ),
                              Slider(
                                value: prompterConfig
                                    .verticalMarginBoxesFadeLength,
                                min: 0.0,
                                max: 100,
                                divisions: 20,
                                label: prompterConfig
                                    .verticalMarginBoxesFadeLength
                                    .toStringAsFixed(2),
                                onChanged: (value) => ref
                                    .read(prompterProvider.notifier)
                                    .setVerticalMarginBoxesFadeLength(value),
                              ),
                            ],
                          ),
                        ),
                      _FeatureGate(
                        feature: Feature.sideMargins,
                        displayText: context.tr(
                          "SettingsScreen.NumberAppSetting_SideMargin",
                        ),
                        child: Row(
                          children: [
                            Text(
                              context.tr(
                                "PrompterScreen.SimpleDialog_DisplaySettings.Slider_SideMargin",
                              ),
                            ),
                            Slider(
                              value: prompterConfig.sideMargin,
                              min: 0,
                              max: 100,
                              divisions: 100,
                              label: prompterConfig.sideMargin.toStringAsFixed(
                                2,
                              ),
                              onChanged: (value) => ref
                                  .read(prompterProvider.notifier)
                                  .setSideMargin(value),
                            ),
                          ],
                        ),
                      ),
                      _FeatureGate(
                        feature: Feature.countdownTimer,
                        displayText: context.tr(
                          "SettingsScreen.NumberAppSetting_CountdownTimer",
                        ),
                        child: Row(
                          children: [
                            Text(
                              context.tr(
                                "PrompterScreen.SimpleDialog_DisplaySettings.Slider_Countdown",
                              ),
                            ),
                            Slider(
                              value: prompterConfig.countdownDuration,
                              min: 0,
                              max: 60,
                              divisions: 60,
                              label: prompterConfig.countdownDuration
                                  .toStringAsFixed(0),
                              onChanged: (value) => ref
                                  .read(prompterProvider.notifier)
                                  .setCountdownDuration(value),
                            ),
                          ],
                        ),
                      ),
                      _FeatureGate(
                        feature: Feature.controlButtons,
                        displayText: context.tr(
                          "SettingsScreen.BooleanAppSetting_ControlButtons",
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => ref
                                  .read(prompterProvider.notifier)
                                  .toggleShowControlButtons(),
                              isSelected: prompterConfig.showControlButtons,
                              icon: Icon(Icons.apps_outlined),
                              tooltip: context.tr(
                                "SettingsScreen.BooleanAppSetting_ControlButtons",
                              ),
                            ),
                            DropdownButton(
                              value: prompterConfig.controlButtonsPosition,
                              items: ControlButtonsPosition.values
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(
                                        context.tr(
                                          "SettingsScreen.DropdownAppSetting_ControlButtonPosition.${v.name}",
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => ref
                                  .read(prompterProvider.notifier)
                                  .setControlButtonsPosition(value!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      AsyncLoading() => Scaffold(
        appBar: AppBar(
          title: Text(context.tr("SettingsScreen.KeybindingsSettings.Title")),
        ),
        body: Center(
          child: CircularProgressIndicator(
            color:
                ref.read(settingsProvider).value?.appPrimaryColor ??
                kBrandAccent,
          ),
        ),
      ),
      _ => const ResetSettingsView(),
    };
  }
}

class _FeatureGate extends ConsumerWidget {
  const _FeatureGate({
    required this.feature,
    required this.displayText,
    required this.child,
  });

  final Feature feature;
  final String displayText;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(
      featuresProvider.select((s) => s.features.contains(feature)),
    );

    if (!isEnabled) {
      return _FeatureDisabledInline(displayText: displayText, feature: feature);
    }

    return child;
  }
}

class _FeatureDisabledInline extends ConsumerWidget {
  const _FeatureDisabledInline({
    required this.displayText,
    required this.feature,
  });

  final String displayText;
  final Feature feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(Icons.lock_outline),
      tileColor: Colors.blueGrey.withAlpha(30),
      title: Text(displayText),
      onTap: () => context.push(
        "/disabledfeature",
        extra: DisabledFeatureScreenRouterExtra(feature: feature),
      ),
    );
  }
}

class _FeatureGatedIconButton extends ConsumerWidget {
  const _FeatureGatedIconButton({
    this.isSelected,
    required this.feature,
    required this.displayText,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Feature feature;
  final String displayText;
  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool? isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(
      featuresProvider.select((s) => s.features.contains(feature)),
    );

    if (isEnabled) {
      return IconButton(
        icon: icon,
        isSelected: isSelected,
        tooltip: tooltip,
        onPressed: onPressed,
      );
    }

    return IconButton(
      icon: Icon(Icons.lock_outline),
      tooltip: "$displayText: ${context.tr("ProFeatureDisabled")}",
      onPressed: () => context.push(
        "/disabledfeature",
        extra: DisabledFeatureScreenRouterExtra(feature: feature),
      ),
    );
  }
}
