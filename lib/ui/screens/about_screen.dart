import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cueline/core/constants.dart';
import 'package:cueline/ui/theme/cueline_tokens.dart';
import 'package:cueline/ui/widgets/cueline_mark.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CueLineTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('AboutScreen.title'))),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          final version = info == null
              ? ''
              : '${info.version} (${info.buildNumber})';

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              CueLineTokens.spaceLg,
              CueLineTokens.spaceMd,
              CueLineTokens.spaceLg,
              CueLineTokens.spaceXxl,
            ),
            children: [
              const CueLineMark(fontSize: 28),
              const SizedBox(height: CueLineTokens.spaceSm),
              Text(
                context.tr('AboutScreen.tagline'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: tokens.mutedText,
                  height: 1.4,
                ),
              ),
              if (version.isNotEmpty) ...[
                const SizedBox(height: CueLineTokens.spaceMd),
                Text(
                  context.tr('AboutScreen.version', args: [version]),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.mutedText,
                  ),
                ),
              ],
              const SizedBox(height: CueLineTokens.spaceXl),
              Text(
                context.tr('AboutDialog.Text_PrivacyText'),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
              const SizedBox(height: CueLineTokens.spaceLg),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(context.tr('AboutDialog.ElevatedButton_Privacy')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/privacy'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.article_outlined),
                title: Text(context.tr('AboutScreen.licenses')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: kAppName,
                  applicationVersion: version,
                  applicationLegalese:
                      '${context.tr('copyright')}\n${context.tr('credits')}',
                ),
              ),
              const SizedBox(height: CueLineTokens.spaceXl),
              Text(
                context.tr('copyright'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.mutedText,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: CueLineTokens.spaceMd),
              Text(
                context.tr('credits'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.mutedText,
                  height: 1.45,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CueLineTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('AboutDialog.ElevatedButton_Privacy')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          CueLineTokens.spaceLg,
          CueLineTokens.spaceMd,
          CueLineTokens.spaceLg,
          CueLineTokens.spaceXxl,
        ),
        children: [
          Text(
            context.tr('AboutDialog.Text_PrivacyBody'),
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: CueLineTokens.spaceXl),
          Text(
            context.tr('copyright'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.mutedText,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
