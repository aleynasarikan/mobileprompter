import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tief_weave/markdown.dart';
import 'package:tiefprompt/providers/current_chapter_provider.dart';
import 'package:tiefprompt/providers/prompter_provider.dart';
import 'package:tiefprompt/providers/speech_recognition_provider.dart';
import 'package:tiefprompt/services/karaoke_matcher.dart';
import 'package:tiefprompt/services/karaoke_speech_follower.dart';
import 'package:tiefprompt/services/speech_recognition_service.dart';
import 'package:tiefprompt/ui/widgets/karaoke_text.dart';

class _UserScrolling extends Notifier<bool> {
  @override
  bool build() => false;
  void setValue(bool v) => state = v;
}

final _userScrollingProvider = NotifierProvider<_UserScrolling, bool>(
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
  bool _userDragging = false;

  void _startScrolling(double speed) {
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

    if (kKaraokeDebugMode) {
      _speechFollower = KaraokeSpeechFollower(
        controller: widget.controller.karaokeController,
        events: ref.read(speechRecognitionServiceProvider).events,
      );
    }

    _markdownController.addListener(_recomputeChapterOffsets);
    widget.controller.scrollController.addListener(_updateCurrentChapter);
  }

  @override
  void didUpdateWidget(covariant ScrollableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _rebuildAst();
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

  double? _blockOffset(int blockIndex) => kKaraokeDebugMode
      ? widget.controller.karaokeController.blockOffset(blockIndex)
      : _markdownController.offsetOf(blockIndex);

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
    final isUserScrolling = ref.read(_userScrollingProvider);

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
      (previous, next) {
        if (next.isPlaying) {
          _startScrolling(next.speed);
        } else {
          _stopScrolling();
        }
      },
    );

    final mediaHeight = MediaQuery.of(context).size.height;
    final mediaWidth = MediaQuery.of(context).size.width;
    final renderWidth = mediaWidth - widget.sideMargin * 2;
    _topPadding = mediaHeight;

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

    final scrollView = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _userDragging = true;
          widget.controller.karaokeController.isUserScrolling = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(_userScrollingProvider.notifier).setValue(true);
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
            ref.read(_userScrollingProvider.notifier).setValue(false);
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
            widget.sideMargin,
            mediaHeight,
            widget.sideMargin,
            0,
          ),
          child: Column(
            children: [
              if (kKaraokeDebugMode)
                KaraokeText(
                  text: widget.text,
                  markdownAst: markdownEnabled ? _ast : null,
                  controller: widget.controller.karaokeController,
                  textAlign: alignment,
                  style: widget.style,
                  width: renderWidth,
                  onLayout: _recomputeChapterOffsets,
                )
              else if (markdownEnabled)
                Markdown(
                  widget.text,
                  controller: _markdownController,
                  textAlign: alignment,
                  style: widget.style,
                  width: renderWidth,
                )
              else
                Text(widget.text, style: widget.style, textAlign: alignment),
              SizedBox(
                height: mediaHeight,
                child: Center(child: Text("The End", style: widget.style)),
              ),
            ],
          ),
        ),
      ),
    );

    if (!kKaraokeDebugMode) return scrollView;

    ref.listen(speechRecognitionProvider.select((s) => s.isActive), (
      _,
      active,
    ) {
      widget.controller.karaokeController.speechMode = active;
      if (active) _speechFollower?.reset();
    });

    return Stack(
      fit: StackFit.expand,
      children: [
        scrollView,
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          child: Center(
            child: KaraokeDebugPanel(
              controller: widget.controller.karaokeController,
              onToggleSpeech: () =>
                  ref.read(speechRecognitionProvider.notifier).toggle(),
            ),
          ),
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
  }

  @override
  void dispose() {
    _stopScrolling();
    _ticker?.dispose();
    _ticker = null;
    widget.controller.scrollController.removeListener(_updateCurrentChapter);
    _markdownController.removeListener(_recomputeChapterOffsets);
    _markdownController.dispose();
    _speechFollower?.dispose();
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
