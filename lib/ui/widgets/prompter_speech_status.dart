import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cueline/providers/prompter_provider.dart';
import 'package:cueline/providers/speech_recognition_provider.dart';
import 'package:cueline/services/speech_recognition_service.dart';
import 'package:cueline/ui/theme/cueline_tokens.dart';
import 'package:cueline/ui/widgets/scrollable_text.dart';

/// Compact, non-debug status for speech following. Hidden while idle.
class PrompterSpeechStatus extends ConsumerWidget {
  final bool controlsVisible;

  const PrompterSpeechStatus({super.key, this.controlsVisible = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(prompterProvider.select((p) => p.isPlaying));
    final userScrolling = ref.watch(userScrollingProvider);
    final snapshot = ref.watch(
      speechRecognitionProvider.select(
        (s) => (
          isActive: s.isActive,
          isListening: s.isListening,
          error: s.error,
          errorCode: s.errorCode,
          recoverable: s.errorRecoverable,
          permissionGranted: s.permissionGranted,
          recognizerMissing: s.recognizerMissing,
          sessionCount: s.sessionCount,
        ),
      ),
    );
    if (!playing && snapshot.error == null) return const SizedBox.shrink();
    final isError =
        snapshot.error != null ||
        snapshot.permissionGranted == false ||
        snapshot.recognizerMissing;
    if (!controlsVisible && !isError) return const SizedBox.shrink();

    final (:label, :icon, :tone) = _copy(
      context,
      playing: playing,
      userScrolling: userScrolling,
      snapshot: snapshot,
    );
    final colors = Theme.of(context).colorScheme;

    final Color foreground;
    final Color background;
    switch (tone) {
      case _StatusTone.ok:
        foreground = colors.primary;
        background = colors.onSurface.withValues(alpha: 0.1);
      case _StatusTone.warn:
        foreground = colors.onSurface;
        background = colors.tertiary.withValues(alpha: 0.22);
      case _StatusTone.error:
        foreground = colors.onError;
        background = colors.error;
    }

    return Semantics(
      liveRegion: true,
      label: label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(CueLineTokens.radiusFull),
        child: InkWell(
          borderRadius: BorderRadius.circular(CueLineTokens.radiusFull),
          onTap: snapshot.error != null
              ? () => ref.read(speechRecognitionProvider.notifier).start()
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CueLineTokens.spaceMd,
              vertical: CueLineTokens.spaceSm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tone == _StatusTone.ok &&
                    (snapshot.isListening || snapshot.sessionCount > 0))
                  const _ListeningDot()
                else
                  Icon(icon, size: CueLineTokens.iconSm, color: foreground),
                const SizedBox(width: CueLineTokens.spaceSm),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ({String label, IconData icon, _StatusTone tone}) _copy(
    BuildContext context, {
    required bool playing,
    required bool userScrolling,
    required ({
      bool isActive,
      bool isListening,
      String? error,
      String? errorCode,
      bool recoverable,
      bool? permissionGranted,
      bool recognizerMissing,
      int sessionCount,
    })
    snapshot,
  }) {
    final code = snapshot.errorCode;
    if (snapshot.permissionGranted == false ||
        code == SpeechRecognitionService.permissionDeniedCode ||
        code == 'error_permission' ||
        code == 'error_insufficient_permissions') {
      return (
        label: context.tr('PrompterScreen.Speech.permissionDenied'),
        icon: Icons.mic_off,
        tone: _StatusTone.error,
      );
    }
    if (snapshot.recognizerMissing ||
        code == SpeechRecognitionService.recognizerNotAvailableCode) {
      return (
        label: context.tr('PrompterScreen.Speech.unavailable'),
        icon: Icons.record_voice_over_outlined,
        tone: _StatusTone.warn,
      );
    }
    if (code == 'error_audio_error') {
      return (
        label: context.tr('PrompterScreen.Speech.microphoneBusy'),
        icon: Icons.mic_off,
        tone: _StatusTone.error,
      );
    }
    if (snapshot.error != null && !snapshot.recoverable) {
      return (
        label: context.tr('PrompterScreen.Speech.unavailable'),
        icon: Icons.error_outline,
        tone: _StatusTone.error,
      );
    }
    if (userScrolling && (snapshot.isActive || playing)) {
      return (
        label: context.tr('PrompterScreen.Speech.trackingPaused'),
        icon: Icons.pause,
        tone: _StatusTone.warn,
      );
    }
    // Silence timeouts and the restart after each sentence are routine in
    // continuous mode. Once a session has run, keep showing "listening"
    // instead of flickering through retrying/starting.
    final hasListened = snapshot.sessionCount > 0;
    if (snapshot.error != null && snapshot.recoverable && !hasListened) {
      return (
        label: context.tr('PrompterScreen.Speech.retrying'),
        icon: Icons.sync,
        tone: _StatusTone.warn,
      );
    }
    if (snapshot.isListening || (snapshot.isActive && hasListened)) {
      return (
        label: context.tr('PrompterScreen.Speech.listening'),
        icon: Icons.mic,
        tone: _StatusTone.ok,
      );
    }
    if (snapshot.isActive || playing) {
      return (
        label: context.tr('PrompterScreen.Speech.starting'),
        icon: Icons.mic_none,
        tone: _StatusTone.ok,
      );
    }
    return (
      label: context.tr('PrompterScreen.Speech.paused'),
      icon: Icons.pause,
      tone: _StatusTone.warn,
    );
  }
}

enum _StatusTone { ok, warn, error }

class _ListeningDot extends StatefulWidget {
  const _ListeningDot();

  @override
  State<_ListeningDot> createState() => _ListeningDotState();
}

class _ListeningDotState extends State<_ListeningDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
