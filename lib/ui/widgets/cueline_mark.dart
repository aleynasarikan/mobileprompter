import 'package:flutter/material.dart';
import 'package:cueline/core/constants.dart';
import 'package:cueline/ui/theme/cueline_tokens.dart';

/// Compact CueLine wordmark: a vertical cue line plus the product name.
class CueLineMark extends StatelessWidget {
  final double fontSize;
  final bool compact;

  const CueLineMark({super.key, this.fontSize = 22, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CueLineTheme.of(context);
    final height = fontSize * 0.92;

    return Semantics(
      header: true,
      label: kAppName,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 2 : 3,
            height: height,
            decoration: BoxDecoration(
              color: tokens.cueMark,
              borderRadius: BorderRadius.circular(CueLineTokens.radiusFull),
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          Text(
            kAppName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
