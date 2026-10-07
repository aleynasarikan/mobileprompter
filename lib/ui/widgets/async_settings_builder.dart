import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cueline/core/constants.dart';
import 'package:cueline/providers/settings_provider.dart';
import 'package:cueline/ui/screens/reset_settings_screen.dart';

class AsyncSettingsBuilder<T> extends ConsumerWidget {
  final AsyncValue<T> state;
  final Widget Function(WidgetRef ref, T value) builder;
  final String screenTitle;

  const AsyncSettingsBuilder({
    super.key,
    required this.state,
    required this.builder,
    required this.screenTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (state) {
      AsyncData(:final value) => builder(ref, value),
      AsyncLoading() => Scaffold(
        appBar: AppBar(title: Text(screenTitle)),
        body: Center(
          child: CircularProgressIndicator(
            color:
                ref.read(settingsProvider).value?.appPrimaryColor ??
                kBrandAccent,
          ),
        ),
      ),
      _ => const ResetSettingsScreen(),
    };
  }
}
