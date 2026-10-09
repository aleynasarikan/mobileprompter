import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cueline/services/floating_prompter.dart';
import 'package:cueline/ui/theme/cueline_tokens.dart';

/// Starts or stops the Android floating prompter. Hidden where it cannot
/// work (iOS, desktop).
class FloatingPrompterButton extends ConsumerWidget {
  const FloatingPrompterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floating = ref.watch(floatingPrompterProvider);
    if (!floating.isSupported) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: floating,
      builder: (context, _) {
        final colors = Theme.of(context).colorScheme;
        final active = floating.isActive;
        final busy = floating.status == FloatingPrompterStatus.starting;
        return IconButton(
          iconSize: CueLineTokens.iconMd,
          tooltip: context.tr(
            active
                ? 'PrompterScreen.Floating.stop'
                : 'PrompterScreen.Floating.button',
          ),
          icon: Icon(
            active
                ? Icons.picture_in_picture_alt
                : Icons.picture_in_picture_alt_outlined,
            color: active ? colors.primary : colors.onSurface,
          ),
          onPressed: busy
              ? null
              : () => toggleFloatingPrompter(context, floating),
        );
      },
    );
  }
}

Future<void> toggleFloatingPrompter(
  BuildContext context,
  FloatingPrompter floating,
) async {
  if (floating.isActive) {
    await floating.close();
    return;
  }
  await startFloatingPrompter(context, floating);
}

/// Opens the floating window over other apps, explaining the overlay
/// permission first when it is missing. Messages failures in a snackbar.
Future<void> startFloatingPrompter(
  BuildContext context,
  FloatingPrompter floating,
) async {
  await floating.request(labels: _labels(context));
  if (!context.mounted) return;
  switch (floating.status) {
    case FloatingPrompterStatus.permissionRequired:
      await _explainPermission(context, floating);
    case FloatingPrompterStatus.failed:
      _showMessage(
        context,
        floating.errorCode == 'microphone_permission_denied'
            ? 'PrompterScreen.Floating.microphoneRequired'
            : 'PrompterScreen.Floating.failed',
      );
    case FloatingPrompterStatus.unsupported:
      _showMessage(context, 'PrompterScreen.Floating.unsupported');
    default:
      break;
  }
}

/// Shown once per tap, never on its own. "Not now" keeps the prompter.
Future<void> _explainPermission(
  BuildContext context,
  FloatingPrompter floating,
) async {
  final allow = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.tr('PrompterScreen.Floating.permissionTitle')),
      content: Text(context.tr('PrompterScreen.Floating.permissionBody')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(context.tr('PrompterScreen.Floating.notNow')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(context.tr('PrompterScreen.Floating.openSettings')),
        ),
      ],
    ),
  );
  if (allow == true) {
    // Continues in FloatingPrompter.onAppResumed when the user is back.
    await floating.openPermissionSettings();
  } else {
    floating.declinePermission();
  }
}

void _showMessage(BuildContext context, String key) {
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(context.tr(key))));
}

Map<String, String> _labels(BuildContext context) => {
  for (final key in const [
    'notificationTitle',
    'notificationText',
    'play',
    'pause',
    'close',
  ])
    key: context.tr('PrompterScreen.Floating.$key'),
};
