import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cueline/core/constants.dart';
import 'package:cueline/providers/combining_provider.dart';
import 'package:cueline/providers/fonts_provider.dart';
import 'package:cueline/providers/settings_provider.dart';
import 'package:cueline/providers/theme_provider.dart';
import 'package:cueline/ui/screens/reset_settings_screen.dart';

class ThemedApp extends ConsumerWidget {
  final RouterConfig<Object> routerConfig;
  final TransitionBuilder? builder;
  final bool debugShowCheckedModeBanner;

  const ThemedApp({
    super.key,
    required this.routerConfig,
    this.builder,
    this.debugShowCheckedModeBanner = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delegates = context.localizationDelegates;
    final supportedLocales = context.supportedLocales;
    final locale = context.locale;

    ref.watch(fontsProvider);

    final themeMode = ref.watch(
      settingsProvider.select((s) => s.whenData((d) => d.themeMode)),
    );
    final lightTheme = ref.watch(
      themesProvider.select((t) => t.whenData((d) => d.lightTheme)),
    );
    final darkTheme = ref.watch(
      themesProvider.select((t) => t.whenData((d) => d.darkTheme)),
    );
    final combined = ref.watch(
      combinedAsyncDataProvider.call([themeMode, lightTheme, darkTheme]),
    );

    if (combined case AsyncError(:final error)) {
      return MaterialApp(
        title: kAppName,
        localizationsDelegates: delegates,
        supportedLocales: supportedLocales,
        locale: locale,
        home: ResetSettingsScreen(
          title: "Couldn't load CueLine",
          message:
              "Settings could not be loaded. Resetting them should restore the app.",
          error: error,
        ),
      );
    }

    final combinedValue = combined.asData?.value;
    final resolvedLightTheme = combinedValue?.states[1] as ThemeData?;
    final resolvedDarkTheme = combinedValue?.states[2] as ThemeData?;
    final resolvedThemeMode =
        combinedValue?.states[0] as ThemeMode? ?? ThemeMode.system;

    return MaterialApp.router(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: delegates,
      supportedLocales: supportedLocales,
      locale: locale,
      routerConfig: routerConfig,
      builder: builder,
      theme: resolvedLightTheme,
      darkTheme: resolvedDarkTheme,
      themeMode: resolvedThemeMode,
    );
  }
}
