import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cueline/ui/widgets/async_settings_builder.dart';
import 'package:cueline/ui/widgets/settings_group.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cueline/core/constants.dart';
import 'package:cueline/models/keybinding.dart';
import 'package:cueline/providers/keybinding_provider.dart';
import 'package:cueline/ui/widgets/app_settings.dart';

class KeybindingsSettingsScreen extends ConsumerWidget {
  const KeybindingsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keybindings = ref.watch(keybindingsProvider);

    return AsyncSettingsBuilder(
      state: keybindings,
      screenTitle: context.tr("SettingsScreen.KeybindingsSettings.Title"),
      builder: (ref, value) => SettingsListScaffold(
        title: context.tr("SettingsScreen.KeybindingsSettings.Title"),
        children: [
            ...KeybindingAction.values.map((b) {
              return KeybindingAppSetting(
                key: Key("KeybindingsSettingsScreen.KeybindingAppSetting_${b.name}"),
                feature: Feature.keybindings,
                displayText: context.tr(
                  "SettingsScreen.KeybindingsSettings.${b.name}",
                ),
                bindings: value.keybindings
                    .where((k) => k.$1 == b)
                    .map((e) => e.$2)
                    .toList(),
                bindingAction: b,
              );
            }),
            ListTile(
              title: Text(
                context.tr("SettingsScreen.KeybindingsSettings.ResetBindings"),
              ),
              onTap: () {
                ref.read(keybindingsProvider.notifier).resetToDefaults();
              },
            ),
          ],
      ),
    );
  }
}
