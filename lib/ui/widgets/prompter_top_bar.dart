import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cueline/core/constants.dart';
import 'package:cueline/providers/script_provider.dart';
import 'package:cueline/ui/theme/cueline_tokens.dart';
import 'package:cueline/ui/widgets/floating_prompter_button.dart';

/// Height of the portrait top bar below the status-bar inset.
const double kPortraitTopBarBodyHeight = 48;

class PrompterTopBar extends ConsumerWidget {
  const PrompterTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (MediaQuery.orientationOf(context) == Orientation.portrait) {
      return _bar(context, ref, portrait: true);
    }
    return _bar(context, ref, portrait: false);
  }

  Widget _bar(BuildContext context, WidgetRef ref, {required bool portrait}) {
    final script = ref.watch(scriptProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final tokens = CueLineTheme.of(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    // The stored default name is English; show the localized one instead.
    final title = script.title == null || script.title == kNewScriptName
        ? context.tr("empty_title")
        : script.title!;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(color: tokens.chromeFill),
        child: Padding(
          padding: EdgeInsets.only(
            top: topInset,
            left: CueLineTokens.spaceXs,
            right: CueLineTokens.spaceMd,
          ),
          child: SizedBox(
            height: kPortraitTopBarBodyHeight,
            child: Row(
              children: [
                IconButton(
                  iconSize: CueLineTokens.iconMd,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: Icon(Icons.close, color: onSurface),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: portrait ? 16 : 18,
                      fontWeight: FontWeight.w500,
                      color: onSurface,
                    ),
                  ),
                ),
                const FloatingPrompterButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
