import 'package:flutter/material.dart';

/// CueLine design tokens. Screens should read spacing, radii, and type
/// from here (or from [CueLineTheme]) instead of hard-coding values.
abstract final class CueLineTokens {
  static const Color accent = Color(0xFFE8B44C);
  static const Color accentOnLight = Color(0xFFB57B12);

  static const Color darkBackground = Color(0xFF0B0C0F);
  static const Color darkSurface = Color(0xFF15171C);
  static const Color darkSurfaceAlt = Color(0xFF1C1F26);
  static const Color darkBorder = Color(0xFF2A2E37);
  static const Color darkText = Color(0xFFF4F1EA);
  static const Color darkMuted = Color(0xFF9A958C);

  static const Color lightBackground = Color(0xFFF6F4EF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEEEBE4);
  static const Color lightBorder = Color(0xFFE2DDD3);
  static const Color lightText = Color(0xFF14161A);
  static const Color lightMuted = Color(0xFF6B665C);

  static const Color error = Color(0xFFE5484D);
  static const Color warning = Color(0xFFD9A441);

  static const Color prompterBackground = Color(0xFF000000);
  static const Color prompterText = Color(0xFFF5F2EB);

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
  static const double spaceXxl = 48;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 20;
  static const double radiusFull = 999;

  static const double minTouch = 44;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;

  static const String uiFontFamily = 'Roboto';

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 240);

  /// Karaoke read-word opacity. Part of the highlight contract — do not
  /// change the matching engine to compensate for this value.
  static const double karaokeReadOpacity = 0.42;
}

@immutable
class CueLineTheme extends ThemeExtension<CueLineTheme> {
  final Color mutedText;
  final Color hairline;
  final Color chromeFill;
  final Color editorFill;
  final Color cueMark;

  const CueLineTheme({
    required this.mutedText,
    required this.hairline,
    required this.chromeFill,
    required this.editorFill,
    required this.cueMark,
  });

  factory CueLineTheme.dark() => CueLineTheme(
    mutedText: CueLineTokens.darkMuted,
    hairline: CueLineTokens.darkBorder,
    chromeFill: CueLineTokens.darkBackground.withValues(alpha: 0.78),
    editorFill: CueLineTokens.darkSurface,
    cueMark: CueLineTokens.accent,
  );

  factory CueLineTheme.light() => CueLineTheme(
    mutedText: CueLineTokens.lightMuted,
    hairline: CueLineTokens.lightBorder,
    chromeFill: CueLineTokens.lightBackground.withValues(alpha: 0.88),
    editorFill: CueLineTokens.lightSurface,
    cueMark: CueLineTokens.accentOnLight,
  );

  static CueLineTheme of(BuildContext context) {
    return Theme.of(context).extension<CueLineTheme>() ?? CueLineTheme.dark();
  }

  @override
  CueLineTheme copyWith({
    Color? mutedText,
    Color? hairline,
    Color? chromeFill,
    Color? editorFill,
    Color? cueMark,
  }) {
    return CueLineTheme(
      mutedText: mutedText ?? this.mutedText,
      hairline: hairline ?? this.hairline,
      chromeFill: chromeFill ?? this.chromeFill,
      editorFill: editorFill ?? this.editorFill,
      cueMark: cueMark ?? this.cueMark,
    );
  }

  @override
  CueLineTheme lerp(ThemeExtension<CueLineTheme>? other, double t) {
    if (other is! CueLineTheme) return this;
    return CueLineTheme(
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      chromeFill: Color.lerp(chromeFill, other.chromeFill, t)!,
      editorFill: Color.lerp(editorFill, other.editorFill, t)!,
      cueMark: Color.lerp(cueMark, other.cueMark, t)!,
    );
  }
}
