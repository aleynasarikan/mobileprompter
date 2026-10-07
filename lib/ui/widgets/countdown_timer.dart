import 'package:flutter/material.dart';
import 'package:cueline/ui/theme/cueline_tokens.dart';

class CountdownTimer extends StatefulWidget {
  final int duration;

  const CountdownTimer({super.key, required this.duration});

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late int remainingTime;
  late double progress;

  @override
  void initState() {
    super.initState();
    remainingTime = widget.duration;
    progress = 1.0;
    startCountdown();
  }

  void startCountdown() {
    Future.delayed(const Duration(seconds: 1), tick);
  }

  void tick() {
    if (!mounted) return;
    if (remainingTime > 0) {
      setState(() {
        remainingTime--;
        progress = remainingTime / widget.duration;
      });
      startCountdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox(
        width: 128,
        height: 128,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 128,
              height: 128,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 3,
                backgroundColor: colors.onSurface.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
            Text(
              '$remainingTime',
              key: ValueKey<int>(remainingTime),
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w500,
                letterSpacing: -1,
                color: colors.onSurface,
                fontFamily: CueLineTokens.uiFontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
