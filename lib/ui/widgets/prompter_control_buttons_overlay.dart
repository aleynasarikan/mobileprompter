import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cueline/core/control_buttons.dart';
import 'package:cueline/providers/prompter_provider.dart';
import 'package:cueline/ui/theme/cueline_tokens.dart';

const double kPrompterControlButtonsOverlayIconSize = 36;

class PrompterControlButtonsOverlay extends ConsumerWidget {
  const PrompterControlButtonsOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controlButtonsPosition = ref.watch(
      prompterProvider.select((p) => p.config.controlButtonsPosition),
    );
    final tokens = CueLineTheme.of(context);

    return SafeArea(
      child: Container(
        alignment: ControlButtonsPositionResolver.getAlignment(
          controlButtonsPosition,
        ),
        padding: EdgeInsets.all(kControlButtonMargin),
        child: Material(
          color: tokens.chromeFill,
          borderRadius: BorderRadius.circular(CueLineTokens.radiusLg),
          child: const _ControlButtons(),
        ),
      ),
    );
  }
}

class _ControlButtons extends ConsumerWidget {
  const _ControlButtons();

  List<Widget> _getButtons(WidgetRef ref, Color foreground) {
    final playing = ref.watch(prompterProvider.select((p) => p.isPlaying));
    return [
      IconButton(
        iconSize: kPrompterControlButtonsOverlayIconSize,
        tooltip: playing ? 'Pause' : 'Play',
        onPressed: () => ref.read(prompterProvider.notifier).togglePlayPause(),
        icon: Icon(
          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: foreground,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controlButtonsPosition = ref.watch(
      prompterProvider.select((p) => p.config.controlButtonsPosition),
    );
    final foreground = Theme.of(context).colorScheme.onSurface;
    final buttons = _getButtons(ref, foreground);

    switch (controlButtonsPosition) {
      case ControlButtonsPosition.left:
      case ControlButtonsPosition.right:
        return Column(mainAxisSize: MainAxisSize.min, children: buttons);
      case ControlButtonsPosition.bottom:
      case ControlButtonsPosition.top:
        return Row(mainAxisSize: MainAxisSize.min, children: buttons);
    }
  }
}
