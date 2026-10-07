import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cueline/providers/script_provider.dart';
import 'package:cueline/providers/speech_recognition_provider.dart';
import 'package:cueline/services/creator_mode.dart';
import 'package:cueline/ui/widgets/karaoke_text.dart';
import 'package:cueline/ui/widgets/safe_scaffold.dart';

/// Temporary screen to verify speech-to-text in isolation.
class SpeechDebugScreen extends ConsumerStatefulWidget {
  const SpeechDebugScreen({super.key});

  @override
  ConsumerState<SpeechDebugScreen> createState() => _SpeechDebugScreenState();
}

class _SpeechDebugScreenState extends ConsumerState<SpeechDebugScreen> {
  bool _creatorOverlayBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(speechRecognitionProvider.notifier).initialize();
      if (!mounted || defaultTargetPlatform != TargetPlatform.android) return;
      try {
        await ref.read(creatorModeProvider).adoptIfRunning();
      } on PlatformException {
        // Overlay channel is not available.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final speech = ref.watch(speechRecognitionProvider);
    final theme = Theme.of(context);

    return SafeScaffold(
      appBar: AppBar(title: const Text('Speech-to-Text Debug')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text('Creator overlay', style: theme.textTheme.titleMedium),
            Text(
              'Shows the open teleprompter script over other apps. '
              'Speech following keeps moving the active word after you leave.',
              style: theme.textTheme.bodySmall,
            ),
            ListenableBuilder(
              listenable: ref.watch(creatorModeProvider),
              builder: (context, _) {
                final visible = ref.read(creatorModeProvider).isVisible;
                return FilledButton.icon(
                  onPressed: _creatorOverlayBusy ? null : _toggleCreatorOverlay,
                  icon: Icon(visible ? Icons.close : Icons.subtitles),
                  label: Text(
                    visible
                        ? 'Hide floating teleprompter'
                        : 'Show floating teleprompter',
                  ),
                );
              },
            ),
            const Divider(),
            Text(
              '🎤 Listening: ${speech.isListening ? 'ON' : 'OFF'}',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: speech.isListening ? theme.colorScheme.primary : null,
              ),
            ),
            _InfoLine('Session active', speech.isActive ? 'yes' : 'no'),
            _InfoLine('Status', speech.status.isEmpty ? '-' : speech.status),
            _InfoLine(
              'Available',
              speech.initialized ? (speech.available ? 'yes' : 'no') : '…',
            ),
            _InfoLine('Mic permission', switch (speech.permissionGranted) {
              null => '…',
              true => 'granted ✓',
              false => 'DENIED — enable Microphone in app settings',
            }, isError: speech.permissionGranted == false),
            _InfoLine(
              'RecognitionService',
              speech.recognizerMissing
                  ? 'NOT FOUND — install/enable Google speech services'
                  : speech.available
                  ? 'found ✓'
                  : '…',
              isError: speech.recognizerMissing,
            ),
            _InfoLine(
              'Locale',
              '${speech.localeId ?? '-'}'
                  '${speech.isPreferredLocale ? ' ✓' : ''}'
                  ' (device reports ${speech.availableLocaleCount} locales)',
            ),
            if (speech.localeWarning != null)
              Text(
                speech.localeWarning!,
                style: TextStyle(color: theme.colorScheme.tertiary),
              ),
            FilledButton.icon(
              onPressed: speech.initialized && !speech.available
                  ? null
                  : () => ref.read(speechRecognitionProvider.notifier).toggle(),
              icon: Icon(speech.isActive ? Icons.stop : Icons.mic),
              label: Text(speech.isActive ? 'Stop' : 'Start'),
            ),
            _InfoLine('Sessions', '${speech.sessionCount}'),
            _InfoLine(
              'Audio level',
              speech.soundLevel == null
                  ? '- (0 events)'
                  : '${speech.soundLevel!.toStringAsFixed(1)} dB  '
                        'min ${speech.minSoundLevel!.toStringAsFixed(1)} / '
                        'max ${speech.maxSoundLevel!.toStringAsFixed(1)}  '
                        '(${speech.soundLevelEvents} events)',
            ),
            _InfoLine(
              'Audio input',
              _audioInputDiagnosis(speech),
              isError:
                  speech.sessionCount > 0 &&
                  (speech.soundLevelEvents == 0 || speech.isSignalFlat),
            ),
            _TextBox(label: 'Partial', text: speech.partialText),
            _TextBox(label: 'Final', text: speech.finalText),
            if (speech.error != null)
              Text(
                'Error [${speech.errorCode ?? '?'}]: ${speech.error}'
                '${speech.errorRecoverable ? ' (restarting)' : ''}',
                style: TextStyle(
                  color: speech.errorRecoverable
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.error,
                ),
              ),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Event log'),
              child: Text(
                speech.log.isEmpty ? '—' : speech.log.join('\n'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleCreatorOverlay() async {
    final mode = ref.read(creatorModeProvider);
    if (defaultTargetPlatform != TargetPlatform.android) {
      _showOverlayMessage('Floating overlay runs on Android only.');
      return;
    }

    setState(() => _creatorOverlayBusy = true);
    try {
      if (mode.isVisible) {
        await mode.hide();
        return;
      }

      final allowed = await mode.canDrawOverlays();
      if (!mounted) return;
      if (!allowed) {
        await mode.openOverlaySettings();
        if (mounted) {
          _showOverlayMessage(
            'Allow display over other apps, then tap the button again.',
          );
        }
        return;
      }

      var speech = ref.read(speechRecognitionProvider);
      if (!speech.initialized) {
        await ref.read(speechRecognitionProvider.notifier).initialize();
        if (!mounted) return;
        speech = ref.read(speechRecognitionProvider);
      }
      final mic = speech.permissionGranted == true;
      if (mic && !speech.isActive) {
        await ref.read(speechRecognitionProvider.notifier).start();
        if (!mounted) return;
      }

      mode.setFallbackWords(
        KaraokeDocument.plain(ref.read(scriptProvider).text).words,
      );
      await mode.show(useMicrophone: mic);
      if (mounted && !mic) {
        _showOverlayMessage(
          'Microphone is off, so the overlay will not follow speech.',
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        _showOverlayMessage(error.message ?? error.code);
      }
    } finally {
      if (mounted) setState(() => _creatorOverlayBusy = false);
    }
  }

  void _showOverlayMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static String _audioInputDiagnosis(SpeechRecognitionState speech) {
    if (speech.sessionCount == 0) return '-';
    if (speech.soundLevelEvents == 0) {
      return 'no level events — recognizer is not capturing audio';
    }
    if (speech.isSignalFlat) {
      return 'flat signal (silence) — emulator is not receiving host mic';
    }
    if (speech.maxSoundLevel! < SpeechRecognitionState.speechLevel) {
      return 'audio received, but below speech level — speak louder/closer';
    }
    return 'speech-level audio received ✓';
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isError;

  const _InfoLine(this.label, this.value, {this.isError = false});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: value,
            style: isError
                ? TextStyle(color: Theme.of(context).colorScheme.error)
                : null,
          ),
        ],
      ),
    );
  }
}

class _TextBox extends StatelessWidget {
  final String label;
  final String text;

  const _TextBox({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(text.isEmpty ? '—' : text),
    );
  }
}
