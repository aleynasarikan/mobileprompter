import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:cueline/ui/widgets/async_settings_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cueline/core/constants.dart';
import 'package:cueline/core/debug_flags.dart';
import 'package:cueline/providers/feature_provider.dart';
import 'package:cueline/providers/settings_provider.dart';
import 'package:cueline/ui/widgets/app_settings.dart';
import 'package:cueline/ui/widgets/changelog_modal.dart';
import 'package:cueline/ui/widgets/settings_group.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final featureKind = ref.watch(featuresProvider).featureKind;
    final title = context.tr("SettingsScreen.title");

    return AsyncSettingsBuilder(
      state: settings,
      screenTitle: title,
      builder: (ref, value) => SettingsListScaffold(
        title: title,
        children: [
          SettingsGroup(
            title: context.tr("SettingsScreen.Section_Appearance"),
            children: [
              DropdownAppSetting<Locale>(
                key: const Key(
                  "SettingsScreen.DropdownAppSetting_DefaultLanguage",
                ),
                feature: Feature.appLanguage,
                value: context.locale,
                displayText: context.tr(
                  "SettingsScreen.DropdownAppSetting_DefaultLanguage",
                ),
                onValueChanged: (updatedValue) {
                  context.setLocale(updatedValue);
                },
                values: kSupportedLocales,
              ),
              DropdownAppSetting<ThemeMode>(
                key: const Key("SettingsScreen.DropdownAppSetting_Theme"),
                feature: Feature.appTheme,
                value: value.themeMode,
                displayText: context.tr(
                  "SettingsScreen.DropdownAppSetting_Theme",
                ),
                onValueChanged: (updatedValue) {
                  ref
                      .read(settingsProvider.notifier)
                      .setThemeMode(updatedValue);
                },
                values: ThemeMode.values
                    .map(
                      (mode) => (
                        context.tr("SettingsScreen.ThemeMode.${mode.name}"),
                        mode,
                      ),
                    )
                    .toList(),
              ),
              ColorAppSetting(
                key: const Key(
                  "SettingsScreen.ColorAppSetting_AppPrimaryColor",
                ),
                feature: Feature.primaryAppColor,
                value: value.appPrimaryColor,
                displayText: context.tr(
                  "SettingsScreen.ColorAppSetting_AppPrimaryColor",
                ),
                onValueChanged: (updatedValue) => ref
                    .read(settingsProvider.notifier)
                    .setAppPrimaryColor(updatedValue),
              ),
              LinkAppSetting(
                key: const Key("SettingsScreen.TextSettings"),
                displayText: context.tr("SettingsScreen.TextSettings"),
                feature: Feature.textSettings,
                value: "/settings/text",
              ),
              LinkAppSetting(
                key: const Key("SettingsScreen.DisplaySettings"),
                displayText: context.tr("SettingsScreen.DisplaySettings"),
                feature: Feature.displaySettings,
                value: "/settings/display",
              ),
            ],
          ),
          SettingsGroup(
            title: context.tr("SettingsScreen.Section_Prompter"),
            children: [
              LinkAppSetting(
                key: const Key("SettingsScreen.KeybindingsSettings"),
                displayText: context.tr(
                  "SettingsScreen.KeybindingsSettings.Title",
                ),
                feature: Feature.keybindings,
                value: "/settings/keybindings",
              ),
              LinkAppSetting(
                key: const Key("SettingsScreen.SettingsRestore"),
                displayText: context.tr(
                  "SettingsScreen.SettingsRestore.Title",
                ),
                feature: Feature.settingsRestore,
                value: "/settings/settingsrestore",
              ),
            ],
          ),
          SettingsGroup(
            title: context.tr("SettingsScreen.Section_About"),
            children: [
              ListTile(
                key: const Key("SettingsScreen.ShowPrivacy"),
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(context.tr("AboutDialog.ElevatedButton_Privacy")),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/privacy'),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(context.tr("AboutScreen.title")),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/about'),
              ),
              ListTile(
                key: const Key("SettingsScreen.ShowChangelog"),
                leading: const Icon(Icons.notes_outlined),
                title: Text(context.tr("SettingsScreen.ShowChangelog")),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showChangelogModal(context),
              ),
              if (kKaraokeDebugTools)
                ListTile(
                  key: const Key("SettingsScreen.ViewLogs"),
                  leading: const Icon(Icons.bug_report_outlined),
                  title: Text(context.tr("SettingsScreen.ViewLogs")),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/logs'),
                ),
              if (featureKind == FeatureKind.freeVersion ||
                  featureKind == FeatureKind.paidVersion)
                ListTile(
                  key: const Key("SettingsScreen.RestorePurchases"),
                  title: Text(context.tr("SettingsScreen.RestorePurchases")),
                  leading: const Icon(Icons.restore),
                  onTap: () {
                    ref.read(featuresProvider.notifier).restorePurchase();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.tr(
                            "SettingsScreen.RestorePurchases_Snackbar",
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ListTile(
                key: const Key("SettingsScreen.ListTile_Reset"),
                leading: Icon(
                  Icons.restart_alt,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  context.tr("SettingsScreen.ListTile_Reset"),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(context.tr("SettingsScreen.Reset_Warning")),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.tr("SettingsScreen.Abort")),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                          onPressed: () {
                            ref
                                .read(settingsProvider.notifier)
                                .resetSettings();
                            Navigator.pop(context);
                          },
                          child: Text(context.tr("SettingsScreen.Confirm")),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
