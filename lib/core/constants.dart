import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';
import 'package:cueline/core/fonts.dart';
import 'package:cueline/models/keybinding.dart';

const double kPrompterMinSpeed = 0.1;
const double kPrompterMaxSpeed = 20.0;

const double kPrompterMinFontSize = 12.0;
const double kPrompterMaxFontSize = 420.0;

const double kPrompterMinSideMargin = 0.0;
const double kPrompterMaxSideMargin = 99.0;

const String kAppName = 'Mobile Prompter';

const String kNewScriptName = "New Script";

const Color kBrandAccent = Color(0xFFE8B44C);

/// Alias kept so persisted settings defaults (`@Default(kBrandTeal)`) pick up
/// the CueLine accent without regenerating Freezed output.
const Color kBrandTeal = kBrandAccent;
const Color kBrandAbyss = Color(0xFF0B0C0F);
const Color kBrandAbyssSurface = Color(0xFF15171C);
const Color kBrandAbyssSurfaceAlt = Color(0xFF1C1F26);
const Color kBrandBorderDark = Color(0xFF2A2E37);
const Color kBrandDarkText = Color(0xFFF4F1EA);

const Color kBrandLightBackground = Color(0xFFF6F4EF);
const Color kBrandLightSurface = Color(0xFFFFFFFF);
const Color kBrandBorderLight = Color(0xFFE2DDD3);
const Color kBrandLightText = Color(0xFF14161A);

const double kBrandRadius = 12.0;

const TalkerRiverpodLoggerSettings kTalkerRiverpodObserverSettings =
    TalkerRiverpodLoggerSettings(
      printMutationStart: false,
      printMutationSuccess: false,
      printProviderAdded: false,
      printProviderUpdated: false,
    );

const int kSettingsSchemaVersion = 1;

final List<TiefPromptFontsFile> kAvailableFonts = [
  TiefPromptFontsFile(
    name: "Roboto",
    isBuiltIn: true,
    variants: [
      TiefPromptFontsVariant(
        weight: 400,
        fontStyle: FontStyle.normal,
        load: () async =>
            await rootBundle.load("assets/fonts/Roboto-Regular.ttf"),
      ),
      TiefPromptFontsVariant(
        weight: 700,
        fontStyle: FontStyle.normal,
        load: () async => await rootBundle.load("assets/fonts/Roboto-Bold.ttf"),
      ),
      TiefPromptFontsVariant(
        weight: 400,
        fontStyle: FontStyle.italic,
        load: () async =>
            await rootBundle.load("assets/fonts/Roboto-Italic.ttf"),
      ),
      TiefPromptFontsVariant(
        weight: 700,
        fontStyle: FontStyle.italic,
        load: () async =>
            await rootBundle.load("assets/fonts/Roboto-BoldItalic.ttf"),
      ),
    ],
  ),
  TiefPromptFontsFile(
    name: "RobotoMono",
    isBuiltIn: true,
    variants: [
      TiefPromptFontsVariant(
        weight: 400,
        fontStyle: FontStyle.normal,
        load: () async =>
            await rootBundle.load("assets/fonts/RobotoMono-Regular.ttf"),
      ),
      TiefPromptFontsVariant(
        weight: 700,
        fontStyle: FontStyle.normal,
        load: () async =>
            await rootBundle.load("assets/fonts/RobotoMono-Bold.ttf"),
      ),
      TiefPromptFontsVariant(
        weight: 400,
        fontStyle: FontStyle.italic,
        load: () async =>
            await rootBundle.load("assets/fonts/RobotoMono-Italic.ttf"),
      ),
      TiefPromptFontsVariant(
        weight: 700,
        fontStyle: FontStyle.italic,
        load: () async =>
            await rootBundle.load("assets/fonts/RobotoMono-BoldItalic.ttf"),
      ),
    ],
  ),
  TiefPromptFontsFile(
    name: "RobotoSlab",
    isBuiltIn: true,
    variants: [
      TiefPromptFontsVariant(
        weight: 400,
        fontStyle: FontStyle.normal,
        load: () async =>
            await rootBundle.load("assets/fonts/RobotoSlab-Regular.ttf"),
      ),
      TiefPromptFontsVariant(
        weight: 700,
        fontStyle: FontStyle.normal,
        load: () async =>
            await rootBundle.load("assets/fonts/RobotoSlab-Bold.ttf"),
      ),
    ],
  ),
  TiefPromptFontsFile(
    name: "OpenDyslexic",
    isBuiltIn: true,
    variants: [
      TiefPromptFontsVariant(
        weight: 400,
        fontStyle: FontStyle.normal,
        load: () async =>
            await rootBundle.load("assets/fonts/OpenDyslexic-Regular.ttf"),
      ),
      TiefPromptFontsVariant(
        weight: 700,
        fontStyle: FontStyle.normal,
        load: () async =>
            await rootBundle.load("assets/fonts/OpenDyslexic-Bold.ttf"),
      ),
      TiefPromptFontsVariant(
        weight: 400,
        fontStyle: FontStyle.italic,
        load: () async =>
            await rootBundle.load("assets/fonts/OpenDyslexic-Italic.ttf"),
      ),
      TiefPromptFontsVariant(
        weight: 700,
        fontStyle: FontStyle.italic,
        load: () async =>
            await rootBundle.load("assets/fonts/OpenDyslexic-BoldItalic.ttf"),
      ),
    ],
  ),
];

const kSupportedLocales = [
  ("Türkçe", Locale("tr", "TR")),
  ("English", Locale("en", "US")),
  ("Deutsch", Locale("de", "DE")),
  ("简体中文", Locale("zh", "CN")),
  ("Русский", Locale("ru")),
  ("العربية", Locale("ar")),
];

class ExtendedLocale extends Locale {
  const ExtendedLocale(super.languageCode, [super.countryCode]);

  @override
  String toString() {
    return super.toString().split("_").join("@");
  }
}

enum Feature {
  appLanguage,
  appTheme,
  primaryAppColor,
  textSettings,
  displaySettings,
  scrollSpeed,
  flipX,
  flipY,
  readingIndicatorBoxes,
  verticalMargins,
  verticalMarginFade,
  sideMargins,
  countdownTimer,
  prompterBackgroundColor,
  prompterTextColor,
  fontSize,
  textAlignment,
  fontFamily,
  keybindings,
  playPause,
  markdown,
  settingsRestore,
  controlButtons,
  showHelpRequest,
  ephemeralScript,
  currentChapter,
  customFonts,
}

enum FeatureKind { unverifiedBuild, freeVersion, paidVersion, fossVersion }

const kAllFeatures = [
  Feature.appLanguage,
  Feature.appTheme,
  Feature.primaryAppColor,
  Feature.textSettings,
  Feature.displaySettings,
  Feature.scrollSpeed,
  Feature.flipX,
  Feature.flipY,
  Feature.readingIndicatorBoxes,
  Feature.verticalMargins,
  Feature.verticalMarginFade,
  Feature.sideMargins,
  Feature.countdownTimer,
  Feature.prompterBackgroundColor,
  Feature.prompterTextColor,
  Feature.fontSize,
  Feature.textAlignment,
  Feature.fontFamily,
  Feature.keybindings,
  Feature.playPause,
  Feature.markdown,
  Feature.settingsRestore,
  Feature.controlButtons,
  Feature.showHelpRequest,
  Feature.ephemeralScript,
  Feature.currentChapter,
  Feature.customFonts,
];

const kFreeFeatures = [
  Feature.appLanguage,
  Feature.appTheme,
  Feature.primaryAppColor,
  Feature.textSettings,
  Feature.displaySettings,
  Feature.scrollSpeed,
  Feature.flipX,
  Feature.flipY,
  Feature.sideMargins,
  Feature.countdownTimer,
  Feature.fontSize,
  Feature.fontFamily,
  Feature.textAlignment,
  Feature.playPause,
  Feature.controlButtons,
  Feature.showHelpRequest,
  Feature.ephemeralScript,
];

final KeybindingMap kDefaultKeybindings = KeybindingMap(
  keybindings: List.from([
    (
      KeybindingAction.playPause,
      Keybinding(keyId: LogicalKeyboardKey.enter.keyId),
    ),
    (
      KeybindingAction.playPause,
      Keybinding(keyId: LogicalKeyboardKey.space.keyId),
    ),

    (
      KeybindingAction.scrollUpSmall,
      Keybinding(keyId: LogicalKeyboardKey.arrowUp.keyId, shift: true),
    ),

    (
      KeybindingAction.scrollDownSmall,
      Keybinding(keyId: LogicalKeyboardKey.arrowDown.keyId, shift: true),
    ),
    (
      KeybindingAction.scrollUp,
      Keybinding(keyId: LogicalKeyboardKey.arrowUp.keyId),
    ),
    (
      KeybindingAction.scrollDown,
      Keybinding(keyId: LogicalKeyboardKey.arrowDown.keyId),
    ),
    (
      KeybindingAction.pageUp,
      Keybinding(keyId: LogicalKeyboardKey.pageUp.keyId),
    ),
    (
      KeybindingAction.pageDown,
      Keybinding(keyId: LogicalKeyboardKey.pageDown.keyId),
    ),
    (
      KeybindingAction.jumpStart,
      Keybinding(keyId: LogicalKeyboardKey.home.keyId),
    ),
    (KeybindingAction.jumpEnd, Keybinding(keyId: LogicalKeyboardKey.end.keyId)),
    (
      KeybindingAction.toggleControls,
      Keybinding(keyId: LogicalKeyboardKey.tab.keyId),
    ),
    (
      KeybindingAction.speedUp,
      Keybinding(keyId: LogicalKeyboardKey.equal.keyId),
    ),
    (
      KeybindingAction.speedUp,
      Keybinding(keyId: LogicalKeyboardKey.numpadAdd.keyId),
    ),
    (
      KeybindingAction.speedDown,
      Keybinding(keyId: LogicalKeyboardKey.minus.keyId),
    ),
    (
      KeybindingAction.speedDown,
      Keybinding(keyId: LogicalKeyboardKey.numpadSubtract.keyId),
    ),
    (
      KeybindingAction.fontSizeUp,
      Keybinding(keyId: LogicalKeyboardKey.equal.keyId, ctrl: true),
    ),
    (
      KeybindingAction.fontSizeUp,
      Keybinding(keyId: LogicalKeyboardKey.numpadAdd.keyId, ctrl: true),
    ),
    (
      KeybindingAction.fontSizeDown,
      Keybinding(keyId: LogicalKeyboardKey.minus.keyId, ctrl: true),
    ),
    (
      KeybindingAction.fontSizeDown,
      Keybinding(keyId: LogicalKeyboardKey.numpadSubtract.keyId, ctrl: true),
    ),
    (
      KeybindingAction.openSettings,
      Keybinding(keyId: LogicalKeyboardKey.comma.keyId, ctrl: true),
    ),
    (
      KeybindingAction.saveSettingsFromPrompter,
      // NOTE: 115 is the KeyId for 's'.
      Keybinding(keyId: 115, ctrl: true),
    ),
  ]),
);
