import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cueline/core/constants.dart';
import 'package:cueline/providers/banner_provider.dart';
import 'package:cueline/providers/database_provider.dart';
import 'package:cueline/providers/feature_provider.dart';
import 'package:cueline/providers/router_provider.dart';
import 'package:cueline/providers/script_provider.dart';
import 'package:cueline/providers/talker_provider.dart';
import 'package:cueline/services/script_service.dart';
import 'package:cueline/ui/widgets/banner_listener.dart';
import 'package:cueline/ui/widgets/themed_app.dart';

class TeleprompterApp extends ConsumerStatefulWidget {
  const TeleprompterApp({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _TeleprompterAppState();
}

class _TeleprompterAppState extends ConsumerState<TeleprompterApp> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final talker = ref.read(talkerProvider);

      final res = await ref.read(featuresProvider.notifier).bootstrap();

      if (!res) {
        talker.warning(
          'Feature bootstrap returned false - invalidating featuresProvider',
        );
        ref.invalidate(featuresProvider);
      } else {
        talker.info('Feature bootstrap succeeded');
      }

      if (ref
          .read(featuresProvider)
          .features
          .contains(Feature.ephemeralScript)) {
        final ephemeralScriptsFilter = ref
            .read(databaseManagersProvider)
            .scriptModel
            .filter((f) => f.ephemeral.equals(true));
        final ephemeralScripts = await ephemeralScriptsFilter.get();

        final scriptService = ref.read(scriptServiceProvider.notifier);

        if (ephemeralScripts.isEmpty) {
          talker.info('No ephemeral script found - creating one');
          final newEphemeralScriptId = await scriptService.createEphemeral();
          final newEphemeralScript = await ref
              .read(scriptServiceProvider.notifier)
              .loadScript(newEphemeralScriptId);
          ref.read(scriptProvider.notifier).loadScript(newEphemeralScript);
        } else if (ephemeralScripts.length > 1) {
          talker.error(
            'Multiple ephemeral scripts found (count: ${ephemeralScripts.length}) - resetting',
          );
          if (mounted) {
            ref
                .read(bannerMessageProvider.notifier)
                .set(
                  "Multiple draft scripts were found. A new empty draft was created.",
                );
          }

          ephemeralScriptsFilter.update((o) => o(ephemeral: Value(false)));
          final newEphemeralScriptId = await scriptService.createEphemeral();
          final newEphemeralScript = await ref
              .read(scriptServiceProvider.notifier)
              .loadScript(newEphemeralScriptId);
          ref.read(scriptProvider.notifier).loadScript(newEphemeralScript);
        } else {
          final ephemeralScript = ephemeralScripts.single;
          talker.info('Ephemeral script loaded: id=${ephemeralScript.id}');
          final scriptProviderNotifier = ref.read(scriptProvider.notifier);
          scriptProviderNotifier.loadScript(ephemeralScript);
          scriptProviderNotifier.setIsSaved(ephemeralScript.scriptText == "");
        }
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ThemedApp(
      routerConfig: ref.watch(tiefPromptRouterProvider),
      builder: (context, child) => BannerListener(
        child:
            child ??
            const Center(child: CircularProgressIndicator(color: kBrandAccent)),
      ),
    );
  }
}
