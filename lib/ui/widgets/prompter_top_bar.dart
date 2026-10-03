import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiefprompt/providers/script_provider.dart';

/// Height of the portrait top bar below the status-bar inset.
const double kPortraitTopBarBodyHeight = 48;

class PrompterTopBar extends ConsumerWidget {
  const PrompterTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (MediaQuery.orientationOf(context) == Orientation.portrait) {
      return _portraitBar(context, ref);
    }

    final script = ref.watch(scriptProvider);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
        child: SafeArea(
          bottom: false,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  script.title ?? context.tr("empty_title"),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _portraitBar(BuildContext context, WidgetRef ref) {
    final script = ref.watch(scriptProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final topInset = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: topInset + kPortraitTopBarBodyHeight,
        clipBehavior: Clip.hardEdge,
        color: onSurface.withAlpha(120),
        padding: EdgeInsets.only(top: topInset, left: 4, right: 8),
        child: Row(
          children: [
            IconButton(
              iconSize: 22,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              icon: Icon(Icons.close, color: onSurface),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Text(
                script.title ?? context.tr("empty_title"),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, color: onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
