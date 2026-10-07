import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cueline/providers/current_chapter_provider.dart';
import 'package:cueline/providers/prompter_provider.dart';
import 'package:cueline/ui/theme/cueline_tokens.dart';

class CurrentChapterBanner extends ConsumerWidget {
  final EdgeInsets? offset;

  const CurrentChapterBanner({super.key, this.offset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapter = ref.watch(currentChapterProvider);
    final (:mirroredX, :mirroredY, :sideMargin, :fontFamily, :alignment) = ref
        .watch(
          prompterProvider.select(
            (p) => (
              mirroredX: p.config.mirroredX,
              mirroredY: p.config.mirroredY,
              sideMargin: p.config.sideMargin,
              fontFamily: p.config.fontFamily,
              alignment: p.config.alignment,
            ),
          ),
        );

    if (chapter == null) return const SizedBox.shrink();

    final onSurface = Theme.of(context).colorScheme.onSurface;
    final tokens = CueLineTheme.of(context);

    return Positioned(
      top: mirroredY ? null : (offset?.top ?? 0),
      bottom: mirroredY ? (offset?.top ?? 0) : null,
      left: 0,
      right: 0,
      child: ColoredBox(
        color: tokens.chromeFill,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal:
                  CueLineTokens.spaceMd +
                  (MediaQuery.of(context).size.width / 2) * (sideMargin / 100),
              vertical: CueLineTokens.spaceSm,
            ),
            child: Transform.flip(
              flipX: mirroredX,
              flipY: mirroredY,
              child: Text(
                chapter,
                style: TextStyle(
                  color: onSurface,
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: alignment,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
