import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cueline/providers/settings_provider.dart';
import 'package:cueline/ui/theme/cueline_tokens.dart';

part 'theme_provider.freezed.dart';
part 'theme_provider.g.dart';

@freezed
abstract class ThemesState with _$ThemesState {
  factory ThemesState({
    required ThemeData darkTheme,
    required ThemeData lightTheme,
    required ThemeData prompterTheme,
  }) = _ThemesState;
}

@Riverpod(keepAlive: true, dependencies: [Settings])
class Themes extends _$Themes {
  @override
  Future<ThemesState> build() async {
    final appPrimaryColor = await ref.watch(
      settingsProvider.selectAsync((s) => s.appPrimaryColor),
    );
    final prompterBackgroundColor = await ref.watch(
      settingsProvider.selectAsync((s) => s.prompterBackgroundColor),
    );
    final prompterTextColor = await ref.watch(
      settingsProvider.selectAsync((s) => s.prompterTextColor),
    );

    return ThemesState(
      darkTheme: buildCueLineTheme(
        brightness: Brightness.dark,
        primary: appPrimaryColor,
        tokens: CueLineTheme.dark(),
        background: CueLineTokens.darkBackground,
        surface: CueLineTokens.darkSurface,
        surfaceAlt: CueLineTokens.darkSurfaceAlt,
        border: CueLineTokens.darkBorder,
        onSurface: CueLineTokens.darkText,
      ),
      lightTheme: buildCueLineTheme(
        brightness: Brightness.light,
        primary: appPrimaryColor,
        tokens: CueLineTheme.light(),
        background: CueLineTokens.lightBackground,
        surface: CueLineTokens.lightSurface,
        surfaceAlt: CueLineTokens.lightSurfaceAlt,
        border: CueLineTokens.lightBorder,
        onSurface: CueLineTokens.lightText,
      ),
      prompterTheme: buildPrompterTheme(
        primary: appPrimaryColor,
        background: prompterBackgroundColor,
        onSurface: prompterTextColor,
      ),
    );
  }
}

ThemeData buildCueLineTheme({
  required Brightness brightness,
  required Color primary,
  required CueLineTheme tokens,
  required Color background,
  required Color surface,
  required Color surfaceAlt,
  required Color border,
  required Color onSurface,
}) {
  final onPrimary = _readableOn(primary);
  final muted = tokens.mutedText;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    secondary: primary,
    onSecondary: onPrimary,
    tertiary: CueLineTokens.warning,
    onTertiary: CueLineTokens.darkBackground,
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: muted,
    surfaceContainerLowest: background,
    surfaceContainerHighest: surfaceAlt,
    error: CueLineTokens.error,
    onError: Colors.white,
    outline: border,
    outlineVariant: border,
  );

  final radius = BorderRadius.circular(CueLineTokens.radiusMd);
  final shape = RoundedRectangleBorder(borderRadius: radius);

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: CueLineTokens.uiFontFamily,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    extensions: [tokens],
  );

  final textTheme = base.textTheme.copyWith(
    displaySmall: base.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.4),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    ),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: shape,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: TextStyle(color: muted),
      labelStyle: TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: CueLineTokens.spaceMd,
        vertical: CueLineTokens.spaceMd,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        minimumSize: const Size(CueLineTokens.minTouch, CueLineTokens.minTouch),
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: CueLineTokens.uiFontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: onSurface,
        side: BorderSide(color: border),
        shape: shape,
        minimumSize: const Size(CueLineTokens.minTouch, CueLineTokens.minTouch),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: onSurface,
        minimumSize: const Size(CueLineTokens.minTouch, CueLineTokens.minTouch),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(CueLineTokens.minTouch, CueLineTokens.minTouch),
        foregroundColor: onSurface,
      ),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CueLineTokens.radiusLg),
        ),
      ),
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceAlt,
      contentTextStyle: TextStyle(color: onSurface),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: shape,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: shape,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return onSurface.withValues(alpha: 0.25);
        }
        if (states.contains(WidgetState.selected)) return onPrimary;
        return onSurface.withValues(alpha: 0.7);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return onSurface.withValues(alpha: 0.1);
        }
        if (states.contains(WidgetState.selected)) return primary;
        return border;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected) ||
            states.contains(WidgetState.disabled)) {
          return Colors.transparent;
        }
        return onSurface.withValues(alpha: 0.25);
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primary,
      thumbColor: primary,
      inactiveTrackColor: border,
      overlayColor: primary.withValues(alpha: 0.12),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    listTileTheme: ListTileThemeData(
      iconColor: muted,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: CueLineTokens.spaceLg,
        vertical: CueLineTokens.spaceXs,
      ),
      titleTextStyle: textTheme.bodyLarge,
      subtitleTextStyle: textTheme.bodySmall?.copyWith(color: muted),
      minVerticalPadding: 12,
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}

ThemeData buildPrompterTheme({
  required Color primary,
  required Color background,
  required Color onSurface,
}) {
  final onPrimary = _readableOn(primary);
  final scheme = ColorScheme.highContrastDark(
    primary: primary,
    surface: background,
    onSurface: onSurface,
  ).copyWith(
    onPrimary: onPrimary,
    tertiary: CueLineTokens.warning,
    error: CueLineTokens.error,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: CueLineTokens.uiFontFamily,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    extensions: [
      CueLineTheme.dark().copyWith(
        chromeFill: background.withValues(alpha: 0.72),
        cueMark: primary,
      ),
    ],
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(CueLineTokens.minTouch, CueLineTokens.minTouch),
        foregroundColor: onSurface,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primary,
      thumbColor: primary,
      inactiveTrackColor: onSurface.withValues(alpha: 0.2),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: CueLineTokens.darkSurface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CueLineTokens.radiusLg),
        ),
      ),
    ),
  );
}

Color _readableOn(Color background) =>
    background.computeLuminance() > 0.5
    ? CueLineTokens.lightText
    : CueLineTokens.darkBackground;
