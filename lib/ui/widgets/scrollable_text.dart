import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tief_weave/markdown.dart';
import 'package:cueline/core/debug_flags.dart';
import 'package:cueline/providers/current_chapter_provider.dart';
import 'package:cueline/providers/prompter_provider.dart';
import 'package:cueline/providers/speech_recognition_provider.dart';
import 'package:cueline/services/creator_mode.dart';
import 'package:cueline/services/karaoke_matcher.dart';
import 'package:cueline/services/karaoke_speech_follower.dart';
import 'package:cueline/services/speech_recognition_service.dart';
import 'package:cueline/ui/widgets/karaoke_text.dart';

/// Width reserved for the karaoke debug strip in portrait, beside the text.
const double kKaraokeDebugStripWidth = 64;

const double kPortraitTextHorizontalPadding = 20;
const double kPortraitTextDebugGap = 12;

/// Where the first line rests in the scroll viewport (0 = top, 1 = bottom).
/// Matches [KaraokeText.revealAlignment].
const double kPrompterReadingLine = 0.35;

class _UserScrolling extends Notifier<bool> {
  @override
  bool build() => false;
  void setValue(bool v) => state = v;
}

final userScrollingProvider = NotifierProvider<_UserScrolling, bool>(
  _UserScrolling.new,
  isAutoDispose: false,
);

class ScrollableTextController {
  final ScrollController scrollController;
  final KaraokeController karaokeController = KaraokeController();

  ScrollableTextController({double initialScrollOffset = 0.0})
    : scrollController = ScrollController(
        initialScrollOffset: initialScrollOffset,
      );

  /// Manual jump; the reading position follows (see
  /// [KaraokeController.seekToReadingLine]).
  void jumpTo(double offset) {
    scrollController.jumpTo(offset);
    _seekAfterLayout();
  }

  void jumpRelative(double offset) {
    scrollController.jumpTo(scrollController.offset + offset);
    _seekAfterLayout();
  }

  void _seekAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => karaokeController.seekToReadingLine(),
    );
  }

  void dispose() {
    scrollController.dispose();
    karaokeController.dispose();
  }
}

class ScrollableText extends ConsumerStatefulWidget {
  final ScrollableTextController controller;
  final String text;
  final TextStyle? style;
  final double sideMargin;

  const ScrollableText({
    super.key,
    required this.text,
    this.style,
    required this.sideMargin,
    required this.controller,
  });

  @override
  ConsumerState<ScrollableText> createState() => _ScrollableTextState();
}

class _ScrollableTextState extends ConsumerState<ScrollableText>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  double _scrollSpeed = 0;
  Duration _lastElapsed = Duration.zero;
  Function? _onReachedEnd;

  MarkdownAst _ast = const MarkdownAst.empty();
  final MarkdownRendererController _markdownController =
      MarkdownRendererController();
  List<({String title, double offset})> _chapterOffsets = [];
  double _topPadding = 0;
  KaraokeSpeechFollower? _speechFollower;
  CreatorMode? _creatorMode;
  bool _userDragging = false;
  bool _alignedOpening = false;
  int _alignAttempts = 0;

  /// While the recognizer is running it owns the scroll. Speed scroll is only
  /// the fallback when speech recognition is not active.
  bool get _speechOwnsScroll => widget.controller.karaokeController.speechMode;

  void _syncPlayScroll() {
    if (!mounted) return;
    final playing = ref.read(prompterProvider).isPlaying;
    if (playing && !_speechOwnsScroll) {
      _startScrolling(ref.read(prompterProvider).config.scrollSpeed);
    } else {
      _stopScrolling();
    }
  }

  void _onKaraokeActivity() => _syncPlayScroll();

  void _startScrolling(double speed) {
    if (_ticker?.isActive == true && _scrollSpeed == speed) return;
    _stopScrolling();
    _scrollSpeed = speed;
    _lastElapsed = Duration.zero;
    _ticker?.start();
  }

  void _stopScrolling() {
    _ticker?.stop();
  }

  @override
  void initState() {
    super.initState();

    _onReachedEnd = () {
      ref.read(prompterProvider.notifier).togglePlayPause();
    };

    _ticker = createTicker((Duration elapsed) {
      _tick(elapsed);
    });

    _rebuildAst();

    final karaoke = widget.controller.karaokeController;
    _speechFollower = KaraokeSpeechFollower(
      controller: karaoke,
      events: ref.read(speechRecognitionServiceProvider).events,
    );
    // The floating prompter mirrors this controller. While the window is
    // hidden, sync() returns at once.
    final creatorMode = ref.read(creatorModeProvider);
    _creatorMode = creatorMode;
    creatorMode.attach(
      listenable: karaoke,
      words: () => karaoke.document.words,
      index: () => karaoke.activeWordIndex,
    );

    _markdownController.addListener(_recomputeChapterOffsets);
    widget.controller.scrollController.addListener(_updateCurrentChapter);
    widget.controller.karaokeController.addListener(_onKaraokeActivity);
    WidgetsBinding.instance.addPostFrameCallback((_) => _alignOpening());
  }

  /// The lead-in used to be the full screen. The scroll viewport is shorter
  /// (chrome sits outside it), so offset 0 left the script below the fold
  /// and play never brought it up once speech mode stopped the ticker.
  void _alignOpening() {
    if (_alignedOpening || !mounted) return;
    final scroll = widget.controller.scrollController;
    if (!scroll.hasClients || !scroll.position.hasContentDimensions) {
      if (_alignAttempts++ < 3) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _alignOpening());
      }
      return;
    }
    _alignedOpening = true;
    final position = scroll.position;
    final textStart = _topPadding;
    // End spacer is one viewport tall, so the script ends at maxScrollExtent.
    final scriptEnd = position.maxScrollExtent;
    final viewStart = position.pixels;
    final viewEnd = viewStart + position.viewportDimension;
    final showsScript = textStart < viewEnd - 4 && scriptEnd > viewStart + 4;
    if (showsScript || scriptEnd <= textStart + 4) return;
    final target =
        (textStart - position.viewportDimension * kPrompterReadingLine).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    if ((target - position.pixels).abs() <= 1) return;
    widget.controller.jumpTo(target);
  }

  @override
  void didUpdateWidget(covariant ScrollableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _rebuildAst();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(creatorModeProvider).sync();
      });
    }
  }

  void _rebuildAst() {
    _ast = MarkdownAstBuilder().build(MarkdownTokenizer().parse(widget.text));
    _chapterOffsets = [];
  }

  void _recomputeChapterOffsets() {
    final blocks = _ast.document.blocks;
    _chapterOffsets = [
      for (var i = 0; i < blocks.length; i++)
        if (blocks[i] case final Heading heading)
          if (_blockOffset(i) case final double offset)
            (
              title: _inlinesToText(heading.inlines),
              offset: offset + _topPadding,
            ),
    ];
    _updateCurrentChapter();
  }

  double? _blockOffset(int blockIndex) =>
      widget.controller.karaokeController.blockOffset(blockIndex);

  String _inlinesToText(List<Inline> inlines) {
    return inlines
        .map(
          (inline) => switch (inline) {
            PlainText(:final text) => text,
            Emphasis(:final children) => _inlinesToText(children),
            Strong(:final children) => _inlinesToText(children),
            Underline(:final children) => _inlinesToText(children),
          },
        )
        .join();
  }

  void _updateCurrentChapter() {
    final (:markdownEnabled, :showCurrentChapter) = ref.read(
      prompterProvider.select(
        (s) => (
          markdownEnabled: s.config.markdownEnabled,
          showCurrentChapter: s.config.showCurrentChapter,
        ),
      ),
    );
    if (!showCurrentChapter || !markdownEnabled) {
      return;
    }

    final offset = widget.controller.scrollController.offset;
    String? current;
    for (final chapter in _chapterOffsets) {
      if (chapter.offset <= offset) {
        current = chapter.title;
      } else {
        break;
      }
    }

    ref.read(currentChapterProvider.notifier).setValue(current);
  }

  void _tick(Duration elapsed) {
    final isUserScrolling = ref.read(userScrollingProvider);

    final deltaSeconds =
        (elapsed - _lastElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;

    final calculatedScrollOffset =
        _getScrollOffsetInLinesPerSecond(_scrollSpeed) * deltaSeconds;

    if (widget.controller.scrollController.hasClients && !isUserScrolling) {
      if (widget.controller.scrollController.position.pixels +
              calculatedScrollOffset >=
          widget.controller.scrollController.position.maxScrollExtent) {
        _onReachedEnd?.call();
        return;
      }
      widget.controller.scrollController.jumpTo(
        widget.controller.scrollController.position.pixels +
            calculatedScrollOffset,
      );
    }
  }

  double _getScrollOffsetInLinesPerSecond(double speed) {
    final textStyle = widget.style ?? const TextStyle(fontSize: 14);
    final lineHeight = textStyle.height ?? 1.0;
    final fontSize = textStyle.fontSize ?? 14.0;
    final lineHeightInPixels = lineHeight * fontSize;

    return speed * lineHeightInPixels;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      prompterProvider.select(
        (p) => (isPlaying: p.isPlaying, speed: p.config.scrollSpeed),
      ),
      (previous, next) => _syncPlayScroll(),
    );

    ref.listen(speechRecognitionProvider.select((s) => s.isActive), (
      _,
      active,
    ) {
      widget.controller.karaokeController.speechMode = active;
      if (active) _speechFollower?.reset();
      _syncPlayScroll();
    });

    final mediaHeight = MediaQuery.of(context).size.height;
    final mediaWidth = MediaQuery.of(context).size.width;
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    final (
      :mirroredX,
      :mirroredY,
      :markdownEnabled,
      :showCurrentChapter,
      :alignment,
    ) = ref.watch(
      prompterProvider.select(
        (p) => (
          mirroredX: p.config.mirroredX,
          mirroredY: p.config.mirroredY,
          markdownEnabled: p.config.markdownEnabled,
          showCurrentChapter: p.config.showCurrentChapter,
          alignment: p.config.alignment,
        ),
      ),
    );

    if (!markdownEnabled || !showCurrentChapter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(currentChapterProvider.notifier).setValue(null);
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : mediaHeight;
        // First line sits on the reading line at offset 0.
        _topPadding = viewport * kPrompterReadingLine;
        if (isPortrait) {
          return _portraitBody(
            reserveDebugStrip: kKaraokeDebugTools,
            mirroredX: mirroredX,
            mirroredY: mirroredY,
            markdownEnabled: markdownEnabled,
            alignment: alignment,
            leadIn: _topPadding,
            endSpacerHeight: viewport,
          );
        }

        final scrollView = _buildScrollView(
          contentWidth: mediaWidth - widget.sideMargin * 2,
          leftInset: widget.sideMargin,
          rightInset: widget.sideMargin,
          topInset: _topPadding,
          bottomInset: 0,
          endSpacerHeight: viewport,
          mirroredX: mirroredX,
          mirroredY: mirroredY,
          markdownEnabled: markdownEnabled,
          alignment: alignment,
        );
        if (!kKaraokeDebugTools) return scrollView;

        return Stack(
          fit: StackFit.expand,
          children: [
            scrollView,
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: Center(child: _debugPanel()),
            ),
            if (_speechFollower case final follower?)
              Positioned(
                top: 8,
                left: 8,
                child: IgnorePointer(
                  child: _SpeechFollowDebugInfo(
                    follower: follower,
                    controller: widget.controller.karaokeController,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Portrait keeps the debug strip in its own column so it cannot cover words.
  Widget _portraitBody({
    required bool reserveDebugStrip,
    required bool mirroredX,
    required bool mirroredY,
    required bool markdownEnabled,
    required TextAlign alignment,
    required double leadIn,
    required double endSpacerHeight,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final strip = reserveDebugStrip ? kKaraokeDebugStripWidth : 0.0;
        final textAreaWidth = constraints.maxWidth - strip;
        final rightMinimum = reserveDebugStrip
            ? kPortraitTextDebugGap
            : kPortraitTextHorizontalPadding;
        final leftInset = widget.sideMargin < kPortraitTextHorizontalPadding
            ? kPortraitTextHorizontalPadding
            : widget.sideMargin;
        final rightInset = widget.sideMargin < rightMinimum
            ? rightMinimum
            : widget.sideMargin;
        final available = textAreaWidth - leftInset - rightInset;
        final scrollView = _buildScrollView(
          contentWidth: available < 1 ? textAreaWidth : available,
          leftInset: available < 1 ? 0 : leftInset,
          rightInset: available < 1 ? 0 : rightInset,
          topInset: leadIn,
          bottomInset: 0,
          endSpacerHeight: endSpacerHeight,
          mirroredX: mirroredX,
          mirroredY: mirroredY,
          markdownEnabled: markdownEnabled,
          alignment: alignment,
        );
        if (!reserveDebugStrip) return scrollView;
        return _portraitKaraokeRow(scrollView);
      },
    );
  }

  Widget _portraitKaraokeRow(Widget scrollView) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            children: [
              if (_speechFollower case final follower?)
                IgnorePointer(
                  child: _SpeechFollowDebugInfo(
                    follower: follower,
                    controller: widget.controller.karaokeController,
                  ),
                ),
              Expanded(child: scrollView),
            ],
          ),
        ),
        SizedBox(
          width: kKaraokeDebugStripWidth,
          child: ClipRect(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  primary: false,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(child: _debugPanel()),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _debugPanel() {
    return KaraokeDebugPanel(
      controller: widget.controller.karaokeController,
      onToggleSpeech: () =>
          ref.read(speechRecognitionProvider.notifier).toggle(),
    );
  }

  String _endLabel(BuildContext context) {
    if (EasyLocalization.of(context) == null) return 'The End';
    return context.tr('PrompterScreen.TheEnd');
  }

  Widget _buildScrollView({
    required double contentWidth,
    required double leftInset,
    required double rightInset,
    required double topInset,
    required double bottomInset,
    required double endSpacerHeight,
    required bool mirroredX,
    required bool mirroredY,
    required bool markdownEnabled,
    required TextAlign alignment,
  }) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _userDragging = true;
          widget.controller.karaokeController.isUserScrolling = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(userScrollingProvider.notifier).setValue(true);
          });
        } else if (notification is ScrollEndNotification) {
          // Also reached after the fling that follows a drag.
          if (_userDragging) {
            _userDragging = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final karaoke = widget.controller.karaokeController;
              karaoke.isUserScrolling = false;
              karaoke.seekToReadingLine();
            });
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(userScrollingProvider.notifier).setValue(false);
          });
        }
        return false;
      },
      child: Transform.flip(
        flipX: mirroredX,
        flipY: mirroredY,
        child: SingleChildScrollView(
          controller: widget.controller.scrollController,
          padding: EdgeInsets.fromLTRB(
            leftInset,
            topInset,
            rightInset,
            bottomInset,
          ),
          child: Column(
            children: [
              KaraokeText(
                text: widget.text,
                markdownAst: markdownEnabled ? _ast : null,
                controller: widget.controller.karaokeController,
                textAlign: alignment,
                style: widget.style,
                width: contentWidth,
                revealAlignment: kPrompterReadingLine,
                onLayout: _recomputeChapterOffsets,
              ),
              SizedBox(
                height: endSpacerHeight,
                child: Center(
                  child: Text(_endLabel(context), style: widget.style),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopScrolling();
    widget.controller.karaokeController.removeListener(_onKaraokeActivity);
    _ticker?.dispose();
    _ticker = null;
    widget.controller.scrollController.removeListener(_updateCurrentChapter);
    _markdownController.removeListener(_recomputeChapterOffsets);
    _markdownController.dispose();
    _speechFollower?.dispose();
    _creatorMode?.detach(widget.controller.karaokeController);
    _creatorMode = null;
    super.dispose();
  }
}

class _SpeechFollowDebugInfo extends StatelessWidget {
  final KaraokeSpeechFollower follower;
  final KaraokeController controller;

  const _SpeechFollowDebugInfo({
    required this.follower,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([follower, controller]),
      builder: (context, _) {
        if (!controller.speechMode) return const SizedBox.shrink();
        final active = controller.activeWordIndex;
        final words = controller.document.words;
        final result = follower.lastResult;
        final match = result?.match ?? KaraokeMatch.none;
        final lines = [
          'STT mode · active #$active '
              '"${active >= 0 && active < words.length ? words[active] : '-'}"',
          'method: ${match.method.name} · '
              'confidence: ${match.confidence.toStringAsFixed(2)} · '
              '${result?.decision.name ?? '-'}',
          'matched: ${match.matchedText.isEmpty ? '-' : match.matchedText}',
          'partial: ${follower.lastPartial.isEmpty ? '-' : follower.lastPartial}',
          'final: ${follower.lastFinal.isEmpty ? '-' : follower.lastFinal}',
        ];
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                lines.join('\n'),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        );
      },
    );
  }
}
