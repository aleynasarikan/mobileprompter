import 'package:drift/drift.dart' show Value;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cueline/ui/widgets/cueline_mark.dart';
import 'package:cueline/ui/theme/cueline_tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cueline/core/constants.dart';
import 'package:cueline/core/debouncer.dart';
import 'package:cueline/models/app_state.drift.dart';
import 'package:cueline/providers/database_provider.dart';
import 'package:cueline/providers/prompter_provider.dart';
import 'package:cueline/providers/script_provider.dart';
import 'package:cueline/services/floating_prompter.dart';
import 'package:cueline/services/script_service.dart';
import 'package:cueline/ui/widgets/changelog_modal.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late TextEditingController _scriptTextController;
  late TextEditingController _scriptTitleController;
  late final Debouncer _scriptChangeDebouncer;
  ProviderSubscription? _scriptListener;

  @override
  void initState() {
    super.initState();
    _scriptTextController = TextEditingController();
    _scriptTitleController = TextEditingController();
    _scriptChangeDebouncer = Debouncer(delay: Duration(milliseconds: 500));

    final script = ref.read(scriptProvider);
    _scriptTextController.text = script.text;
    _scriptTitleController.text = _displayTitle(script.title);

    LicenseRegistry.addLicense(() async* {
      final openDyslexicLicense = await rootBundle.loadString(
        'assets/licenses/openDyslexicLicense.txt',
      );
      yield LicenseEntryWithLineBreaks(['OpenDyslexic'], openDyslexicLicense);
      final exoLicense = await rootBundle.loadString(
        'assets/licenses/exoLicense.txt',
      );
      yield LicenseEntryWithLineBreaks(['Exo'], exoLicense);
      final robotoLicense = await rootBundle.loadString(
        'assets/licenses/robotoLicense.txt',
      );
      yield LicenseEntryWithLineBreaks(['roboto'], robotoLicense);
      final robotoMonoLicense = await rootBundle.loadString(
        'assets/licenses/robotoMonoLicense.txt',
      );
      yield LicenseEntryWithLineBreaks(['roboto mono'], robotoMonoLicense);
      final robotoSlabLicense = await rootBundle.loadString(
        'assets/licenses/robotoSlabLicense.txt',
      );
      yield LicenseEntryWithLineBreaks(['roboto slab'], robotoSlabLicense);
    });

    _runStartupChecks();
  }

  Future<void> _runStartupChecks() async {
    if (!mounted) return;

    final appState = await ref
        .read(databaseManagersProvider)
        .appStateModel
        .getSingle();

    await _checkChangelog(appState);
  }

  Future<void> _checkChangelog(AppStateModelData appState) async {
    final appStateVersion = appState.lastSeenVersion;
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (appStateVersion == null ||
        appStateVersion.isEmpty ||
        appStateVersion == currentVersion) {
      if (appStateVersion != currentVersion) {
        await ref
            .read(databaseManagersProvider)
            .appStateModel
            .update((o) => o(lastSeenVersion: Value(currentVersion)));
      }
      return;
    }
    if (!mounted) return;

    await showChangelogModal(context);

    await ref
        .read(databaseManagersProvider)
        .appStateModel
        .update((o) => o(lastSeenVersion: Value(currentVersion)));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _scriptListener?.close();
    _scriptListener = ref.listenManual(scriptProvider, (previous, next) {
      var scriptTextChanged =
          previous?.text != next.text &&
          _scriptTextController.text != next.text;
      var scriptTitleChanged =
          previous?.title != next.title &&
          _scriptTitleController.text != next.title;
      if ((scriptTextChanged || scriptTitleChanged) &&
          !_scriptTextController.value.composing.isValid) {
        final selection = TextSelection.collapsed(offset: next.text.length);
        _scriptTextController.value = TextEditingValue(
          text: next.text,
          selection: selection,
        );
        _scriptTitleController.value = TextEditingValue(
          text: _displayTitle(next.title),
        );
      }
    });
  }

  /// The stored default name is English; show the localized hint instead.
  static String _displayTitle(String? title) =>
      title == null || title == kNewScriptName ? "" : title;

  @override
  void dispose() {
    _scriptListener?.close();
    _scriptTextController.dispose();
    _scriptTitleController.dispose();
    _scriptChangeDebouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CueLineTheme.of(context);
    final isSaved = ref.watch(scriptProvider.select((s) => s.isSaved));
    final scriptText = ref.watch(scriptProvider.select((s) => s.text));
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final floatingSupported = ref.watch(floatingPrompterProvider).isSupported;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CueLineTokens.spaceLg,
                CueLineTokens.spaceSm,
                CueLineTokens.spaceSm,
                0,
              ),
              child: Row(
                children: [
                  const Expanded(child: CueLineMark()),
                  IconButton(
                    key: const Key("HomeScreen.ElevatedButton_Select"),
                    icon: const Icon(Icons.folder_open_outlined),
                    tooltip: context.tr("HomeScreen.ElevatedButton_Select"),
                    onPressed: _openScript,
                  ),
                  IconButton(
                    key: const Key("HomeScreen.ElevatedButton_Save"),
                    icon: Icon(
                      isSaved
                          ? Icons.bookmark_added
                          : Icons.bookmark_add_outlined,
                    ),
                    tooltip: context.tr("HomeScreen.ElevatedButton_Save"),
                    onPressed: _saveScript,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (route) => context.push(route),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        key: const Key("HomeScreen.IconButton_Settings"),
                        value: "/settings",
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.settings_outlined),
                          title: Text(
                            context.tr("HomeScreen.IconButton_Settings"),
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        key: const Key("HomeScreen.IconButton_About"),
                        value: "/about",
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.info_outline),
                          title: Text(
                            context.tr("HomeScreen.IconButton_About"),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!keyboardOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CueLineTokens.spaceLg,
                  CueLineTokens.spaceXs,
                  CueLineTokens.spaceLg,
                  CueLineTokens.spaceMd,
                ),
                child: Text(
                  context.tr("HomeScreen.Intro"),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.mutedText,
                    height: 1.4,
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CueLineTokens.spaceMd,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.editorFill,
                    borderRadius: BorderRadius.circular(CueLineTokens.radiusLg),
                    border: Border.all(color: tokens.hairline),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CueLineTokens.spaceMd,
                      CueLineTokens.spaceXs,
                      CueLineTokens.spaceMd,
                      CueLineTokens.spaceSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _titleField(theme),
                        Divider(color: tokens.hairline, height: 1),
                        Expanded(child: _scriptField(theme)),
                        _ScriptStats(text: scriptText, isSaved: isSaved),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CueLineTokens.spaceMd,
                CueLineTokens.spaceMd,
                CueLineTokens.spaceMd,
                CueLineTokens.spaceMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ModeCard(
                    key: const Key("HomeScreen.ElevatedButton_Start"),
                    primary: true,
                    icon: Icons.graphic_eq,
                    title: context.tr("HomeScreen.Mode.Live.Title"),
                    subtitle: keyboardOpen
                        ? null
                        : context.tr("HomeScreen.Mode.Live.Subtitle"),
                    onTap: () => _startPrompter(),
                  ),
                  if (floatingSupported) ...[
                    const SizedBox(height: CueLineTokens.spaceSm),
                    _ModeCard(
                      key: const Key("HomeScreen.ElevatedButton_StartFloating"),
                      primary: false,
                      icon: Icons.picture_in_picture_alt_outlined,
                      title: context.tr("HomeScreen.Mode.Apps.Title"),
                      subtitle: keyboardOpen
                          ? null
                          : context.tr("HomeScreen.Mode.Apps.Subtitle"),
                      onTap: () => _startPrompter(floating: true),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleField(ThemeData theme) {
    return TextField(
      key: const Key("HomeScreen.TitleField"),
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.next,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: context.tr("HomeScreen.TitleField_hintText"),
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: CueLineTokens.spaceMd,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      controller: _scriptTitleController,
      onChanged: (value) {
        ref.read(scriptProvider.notifier).setTitle(value);
        ref.read(scriptProvider.notifier).setIsSaved(false);
        if (ref.read(scriptProvider).ephemeral) {
          _scriptChangeDebouncer.run(_updateEphemeralScript);
        }
      },
    );
  }

  Widget _scriptField(ThemeData theme) {
    return TextField(
      key: const Key("HomeScreen.TextField"),
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.top,
      expands: true,
      maxLines: null,
      style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
      decoration: InputDecoration(
        hintText: context.tr("HomeScreen.TextField_hintText"),
        filled: false,
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: CueLineTokens.spaceMd,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      controller: _scriptTextController,
      onChanged: (value) {
        ref.read(scriptProvider.notifier).setText(value);
        ref.read(scriptProvider.notifier).setIsSaved(false);
        if (ref.read(scriptProvider).ephemeral) {
          _scriptChangeDebouncer.run(_updateEphemeralScript);
        }
      },
    );
  }

  void _openScript() {
    if (ref.read(scriptProvider).isSaved) {
      context.push('/open_file');
    } else {
      _showDiscardConfirmDialog(() => context.push('/open_file'));
    }
  }

  Future<void> _saveScript() async {
    if (ref.read(scriptProvider).ephemeral) {
      await _saveCurrentScript();
      ref.read(scriptServiceProvider.notifier).createEphemeral();
    } else {
      await _showNewOrOverrideDialog();
    }
  }

  void _startPrompter({bool floating = false}) {
    if (ref.read(scriptProvider).text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("HomeScreen.EmptyScript"))),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    ref.invalidate(prompterProvider);
    context.push(floating ? '/teleprompter?mode=floating' : '/teleprompter');
  }

  void _updateEphemeralScript() {
    final script = ref.read(scriptProvider);
    ref.read(scriptServiceProvider.notifier).saveEphemeral(script);
  }

  void _showDiscardConfirmDialog(Function() confirmAction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr("HomeScreen.DiscardConfirmDialog.Title")),
        content: Text(context.tr("HomeScreen.DiscardConfirmDialog.Body")),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(context.tr("HomeScreen.DiscardConfirmDialog.Cancel")),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              context.pop();
              confirmAction();
            },
            child: Text(context.tr("HomeScreen.DiscardConfirmDialog.Confirm")),
          ),
        ],
      ),
    );
  }

  Future<void> _showNewOrOverrideDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr("HomeScreen.NewOrOverrideDialog.Title")),
        actions: [
          TextButton(
            onPressed: () async {
              await _saveCurrentScriptAsNew();
              if (context.mounted) context.pop();
            },
            child: Text(context.tr("HomeScreen.NewOrOverrideDialog.NewScript")),
          ),
          FilledButton(
            onPressed: () async {
              await _saveCurrentScript();
              if (context.mounted) context.pop();
            },
            child: Text(
              context.tr("HomeScreen.NewOrOverrideDialog.OverrideScript"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCurrentScriptAsNew() async {
    final scriptService = ref.read(scriptServiceProvider.notifier);
    final currentScript = ref.read(scriptProvider);
    final scriptProviderNotifier = ref.read(scriptProvider.notifier);

    final savedScriptId = await scriptService.saveAsNew(currentScript);

    scriptProviderNotifier.loadScript(
      await scriptService.loadScript(savedScriptId),
    );
    scriptProviderNotifier.setEphemeral(false);
    scriptProviderNotifier.setIsSaved(true);
  }

  Future<int> _saveCurrentScript() async {
    final scriptService = ref.read(scriptServiceProvider.notifier);
    final currentScript = ref.read(scriptProvider);
    final scriptProviderNotifier = ref.read(scriptProvider.notifier);

    final savedScriptId = await scriptService.save(currentScript);

    scriptProviderNotifier.setEphemeral(false);
    scriptProviderNotifier.setIsSaved(true);
    scriptProviderNotifier.setId(savedScriptId);

    return savedScriptId;
  }
}

/// Word count and an estimated speaking time for the script.
class _ScriptStats extends StatelessWidget {
  /// Typical teleprompter pace for Turkish and English speech.
  static const _wordsPerMinute = 130;

  final String text;
  final bool isSaved;

  const _ScriptStats({required this.text, required this.isSaved});

  @override
  Widget build(BuildContext context) {
    final tokens = CueLineTheme.of(context);
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: tokens.mutedText);
    final words = text.trim().isEmpty
        ? 0
        : text.trim().split(RegExp(r'\s+')).length;
    final seconds = (words * 60 / _wordsPerMinute).round();
    final duration = seconds >= 60
        ? context.tr(
            "HomeScreen.DurationMinutes",
            namedArgs: {'m': '${seconds ~/ 60}', 's': '${seconds % 60}'},
          )
        : context.tr(
            "HomeScreen.DurationSeconds",
            namedArgs: {'s': '$seconds'},
          );

    return Padding(
      padding: const EdgeInsets.only(top: CueLineTokens.spaceSm),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 14, color: tokens.mutedText),
          const SizedBox(width: CueLineTokens.spaceXs),
          Expanded(
            child: Text(
              context.tr(
                "HomeScreen.Stats",
                namedArgs: {'words': '$words', 'duration': duration},
              ),
              style: style,
            ),
          ),
          if (!isSaved)
            Text(context.tr("HomeScreen.UnsavedHint"), style: style),
        ],
      ),
    );
  }
}

/// Large entry point for one way of speaking.
class _ModeCard extends StatelessWidget {
  final bool primary;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ModeCard({
    super.key,
    required this.primary,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tokens = CueLineTheme.of(context);
    final background = primary ? colors.primary : tokens.editorFill;
    final foreground = primary ? colors.onPrimary : colors.onSurface;
    final muted = primary
        ? colors.onPrimary.withValues(alpha: 0.72)
        : tokens.mutedText;
    final radius = BorderRadius.circular(CueLineTokens.radiusLg);

    return Material(
      color: background,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          decoration: primary
              ? null
              : BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: tokens.hairline),
                ),
          padding: const EdgeInsets.symmetric(
            horizontal: CueLineTokens.spaceMd,
            vertical: CueLineTokens.spaceMd,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary
                      ? colors.onPrimary.withValues(alpha: 0.14)
                      : colors.primary.withValues(alpha: 0.14),
                ),
                child: Icon(
                  icon,
                  color: primary ? foreground : colors.primary,
                  size: CueLineTokens.iconMd,
                ),
              ),
              const SizedBox(width: CueLineTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}
