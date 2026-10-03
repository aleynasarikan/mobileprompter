import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tiefprompt/services/karaoke_matcher.dart';
import 'package:tiefprompt/services/speech_recognition_service.dart';
import 'package:tiefprompt/ui/widgets/karaoke_text.dart';

/// Moves [KaraokeController.activeWordIndex] along with recognized speech
/// while [KaraokeController.speechMode] is on. Notifies for debug output.
///
/// The controller is the source of truth: any change of the active word that
/// this follower did not make (seek, buttons, scrolling) resets the spoken
/// context, so matching continues from the new position.
class KaraokeSpeechFollower extends ChangeNotifier {
  final KaraokeController controller;
  late final StreamSubscription<SpeechRecognitionEvent> _subscription;

  KaraokeDocument? _document;
  KaraokeSpeechTracker? _tracker;

  /// The active word as last written or acknowledged by this follower.
  late int _expectedIndex;
  late int _seenSeekCount;
  bool _writing = false;

  /// Latest partial of the running utterance, also while not tracking.
  String _utterancePartial = '';

  /// The running utterance started before a seek; its results are dropped
  /// until its final or a new listening session.
  bool _ignoreUtterance = false;

  String lastPartial = '';
  String lastFinal = '';
  KaraokeTrackResult? lastResult;

  KaraokeSpeechFollower({
    required this.controller,
    required Stream<SpeechRecognitionEvent> events,
  }) {
    _acknowledgePosition();
    controller.addListener(_onControllerChanged);
    _subscription = events.listen(_onEvent);
  }

  /// Clears the spoken context, e.g. when a new listening run starts.
  void reset() {
    _tracker?.reset();
    _acknowledgePosition();
    _utterancePartial = '';
    lastPartial = '';
    lastFinal = '';
    lastResult = null;
    notifyListeners();
  }

  void _acknowledgePosition() {
    _expectedIndex = controller.activeWordIndex;
    _seenSeekCount = controller.seekCount;
  }

  void _onControllerChanged() {
    if (_writing) return;
    if (controller.seekCount == _seenSeekCount &&
        controller.activeWordIndex == _expectedIndex) {
      return;
    }
    _acknowledgePosition();
    _ignoreUtterance = _utterancePartial.isNotEmpty;
    _trackerForCurrentDocument()?.resetContext(
      pendingPartial: _utterancePartial,
    );
    lastResult = null;
    notifyListeners();
  }

  void _onEvent(SpeechRecognitionEvent event) {
    if (event case SpeechListeningChanged(isListening: true)) {
      _utterancePartial = '';
      _ignoreUtterance = false;
      _tracker?.onSessionStart();
      return;
    }
    if (!controller.speechMode || event is! SpeechResult) return;
    _utterancePartial = event.isFinal ? '' : event.text;
    if (event.isFinal) {
      lastFinal = event.text;
      lastPartial = '';
    } else {
      lastPartial = event.text;
    }
    if (_ignoreUtterance) {
      if (event.isFinal) _ignoreUtterance = false;
      notifyListeners();
      return;
    }
    // The drag ends with a seek that resets the context anyway.
    if (controller.isUserScrolling) {
      notifyListeners();
      return;
    }

    final tracker = _trackerForCurrentDocument();
    if (tracker == null) return;

    final active = controller.activeWordIndex;
    final result = event.isFinal
        ? tracker.onFinal(event.text, active)
        : tracker.onPartial(event.text, active);

    if (result != null) {
      lastResult = result;
      if (result.wordIndex case final index?) {
        _writing = true;
        controller.activeWordIndex = index;
        _writing = false;
        _expectedIndex = controller.activeWordIndex;
      }
    }
    notifyListeners();
  }

  KaraokeSpeechTracker? _trackerForCurrentDocument() {
    final document = controller.document;
    if (document.wordCount == 0) return null;
    if (!identical(document, _document)) {
      _document = document;
      _tracker = KaraokeSpeechTracker(KaraokeMatcher(document.words));
    }
    return _tracker;
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    _subscription.cancel();
    super.dispose();
  }
}
