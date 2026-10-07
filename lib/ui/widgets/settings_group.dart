import 'package:flutter/material.dart';
import 'package:cueline/ui/theme/cueline_tokens.dart';

/// Section header + grouped rows for Settings.
class SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsGroup({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CueLineTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        top: CueLineTokens.spaceLg,
        bottom: CueLineTokens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CueLineTokens.spaceLg,
              CueLineTokens.spaceSm,
              CueLineTokens.spaceLg,
              CueLineTokens.spaceSm,
            ),
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: tokens.mutedText,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class SettingsListScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;

  const SettingsListScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + CueLineTokens.spaceXxl,
        ),
        children: children,
      ),
    );
  }
}
