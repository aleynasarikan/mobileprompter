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
import 'package:cueline/core/debouncer.dart';
import 'package:cueline/models/app_state.drift.dart';
import 'package:cueline/providers/database_provider.dart';
import 'package:cueline/providers/prompter_provider.dart';
import 'package:cueline/providers/script_provider.dart';
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
    _scriptTitleController.text = script.title ?? "";

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
        _scriptTitleController.value = TextEditingValue(text: next.title ?? "");
      }
    });
  }

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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

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
                CueLineTokens.spaceSm,
              ),
              child: Row(
                children: [
                  const Expanded(child: CueLineMark()),
                  IconButton(
                    key: const Key("HomeScreen.IconButton_Settings"),
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.push("/settings"),
                    tooltip: context.tr("HomeScreen.IconButton_Settings"),
                  ),
                  IconButton(
                    key: const Key("HomeScreen.IconButton_About"),
                    icon: const Icon(Icons.info_outline),
                    tooltip: context.tr("HomeScreen.IconButton_About"),
                    onPressed: () => context.push('/about'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CueLineTokens.spaceLg,
                0,
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
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CueLineTokens.spaceLg,
              ),
              child: TextField(
                key: const Key("HomeScreen.TitleField"),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                style: theme.textTheme.titleLarge,
                decoration: InputDecoration(
                  hintText: context.tr("HomeScreen.TitleField_hintText"),
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: CueLineTokens.spaceSm,
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CueLineTokens.spaceLg,
              ),
              child: Divider(color: tokens.hairline, height: 1),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CueLineTokens.spaceLg,
                  CueLineTokens.spaceSm,
                  CueLineTokens.spaceLg,
                  CueLineTokens.spaceSm,
                ),
                child: TextField(
                  key: const Key("HomeScreen.TextField"),
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  expands: true,
                  maxLines: null,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  decoration: InputDecoration(
                    hintText: context.tr("HomeScreen.TextField_hintText"),
                    filled: false,
                    alignLabelWithHint: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: CueLineTokens.spaceSm,
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
                ),
              ),
            ),
            if (!isSaved)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CueLineTokens.spaceLg,
                  0,
                  CueLineTokens.spaceLg,
                  CueLineTokens.spaceXs,
                ),
                child: Text(
                  context.tr("HomeScreen.UnsavedHint"),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tokens.mutedText,
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                CueLineTokens.spaceLg,
                CueLineTokens.spaceSm,
                CueLineTokens.spaceLg,
                CueLineTokens.spaceMd + (bottomInset > 0 ? 0 : 4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    key: const Key("HomeScreen.ElevatedButton_Start"),
                    onPressed: _startPrompter,
                    icon: const Icon(Icons.graphic_eq),
                    label: Text(
                      context.tr("HomeScreen.ElevatedButton_Start"),
                    ),
                  ),
                  const SizedBox(height: CueLineTokens.spaceSm),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          key: const Key("HomeScreen.ElevatedButton_Select"),
                          onPressed: () {
                            if (ref.read(scriptProvider).isSaved) {
                              context.push('/open_file');
                            } else {
                              _showDiscardConfirmDialog(
                                () => context.push('/open_file'),
                              );
                            }
                          },
                          child: Text(
                            context.tr("HomeScreen.ElevatedButton_Select"),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          key: const Key("HomeScreen.ElevatedButton_Save"),
                          onPressed: () async {
                            if (ref.read(scriptProvider).ephemeral) {
                              _saveCurrentScript();
                              ref
                                  .read(scriptServiceProvider.notifier)
                                  .createEphemeral();
                            } else {
                              await _showNewOrOverrideDialog();
                            }
                          },
                          child: Text(
                            context.tr('HomeScreen.ElevatedButton_Save'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startPrompter() {
    if (ref.read(scriptProvider).text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("HomeScreen.EmptyScript"))),
      );
      return;
    }
    ref.invalidate(prompterProvider);
    context.push('/teleprompter');
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
