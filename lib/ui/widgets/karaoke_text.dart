import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:tief_weave/markdown.dart';
import 'package:tief_weave/text_direction/inline_text_direction_detector.dart';

/// Temporary switch: while true, the prompter renders through [KaraokeText]
/// and shows [KaraokeDebugPanel]. Disable with
/// `--dart-define=KARAOKE_DEBUG=false`.
const bool kKaraokeDebugMode = bool.fromEnvironment(
  'KARAOKE_DEBUG',
  defaultValue: kDebugMode,
);

enum KaraokeBlockKind { paragraph, heading, rule }

class KaraokeRun {
  final String text;
  final bool isWord;

  /// Global index of this word, or for whitespace of the preceding word
  /// (-1 if there is none).
  final int wordIndex;

  /// Inline markdown style (italic, bold, underline) relative to the base.
  final TextStyle? style;

  const KaraokeRun(
    this.text,
    this.wordIndex,
    this.style, {
    required this.isWord,
  });
}

class KaraokeBlock {
  final KaraokeBlockKind kind;
  final int headingLevel;
  final List<KaraokeRun> runs;
  final int firstWordIndex;
  final int wordCount;
  final TextDirection? textDirection;

  const KaraokeBlock({
    required this.kind,
    required this.runs,
    required this.firstWordIndex,
    required this.wordCount,
    this.headingLevel = 0,
    this.textDirection,
  });
}

class KaraokeDocument {
  final List<KaraokeBlock> blocks;

  /// Text of every word, indexed like `activeWordIndex`.
  final List<String> words;
  final Int32List _wordBlock;
  final Int32List _wordStart;
  final Int32List _wordEnd;

  KaraokeDocument._(
    this.blocks,
    this.words,
    this._wordBlock,
    this._wordStart,
    this._wordEnd,
  );

  static final empty = KaraokeDocument._(
    const [],
    const [],
    Int32List(0),
    Int32List(0),
    Int32List(0),
  );

  int get wordCount => _wordBlock.length;

  int blockOfWord(int wordIndex) => _wordBlock[wordIndex];

  /// Character range of the word inside its block's rendered text.
  TextRange rangeOfWord(int wordIndex) =>
      TextRange(start: _wordStart[wordIndex], end: _wordEnd[wordIndex]);

  /// Plain text: every line becomes its own block so that layout matches a
  /// single multi-line [Text].
  factory KaraokeDocument.plain(String text) {
    final builder = _KaraokeDocumentBuilder();
    for (final line in text.split('\n')) {
      final cleaned = line.endsWith('\r')
          ? line.substring(0, line.length - 1)
          : line;
      builder.addTextBlock(KaraokeBlockKind.paragraph, [(cleaned, null)]);
    }
    return builder.build();
  }

  factory KaraokeDocument.markdown(MarkdownAst ast) {
    final builder = _KaraokeDocumentBuilder();
    final directionDetector = InlineTextDirectionDetector(
      const ParagraphTextDirectionResolver(),
    );
    for (final block in ast.document.blocks) {
      switch (block) {
        case Paragraph(:final inlines):
          builder.addTextBlock(
            KaraokeBlockKind.paragraph,
            _flattenInlines(inlines, null),
            textDirection: directionDetector.detect(inlines),
          );
        case Heading(:final level, :final inlines):
          builder.addTextBlock(
            KaraokeBlockKind.heading,
            _flattenInlines(inlines, null),
            headingLevel: level,
            textDirection: directionDetector.detect(inlines),
          );
        case Hrule():
          builder.addRuleBlock();
      }
    }
    return builder.build();
  }

  static List<(String, TextStyle?)> _flattenInlines(
    List<Inline> inlines,
    TextStyle? style,
  ) {
    final segments = <(String, TextStyle?)>[];
    void visit(List<Inline> inlines, TextStyle? style) {
      for (final inline in inlines) {
        switch (inline) {
          case PlainText(:final text):
            segments.add((text, style));
          case Emphasis(:final children):
            visit(children, _merge(style, _italic));
          case Strong(:final children):
            visit(children, _merge(style, _bold));
          case Underline(:final children):
            visit(children, _merge(style, _underline));
        }
      }
    }

    visit(inlines, style);
    return segments;
  }

  static const _italic = TextStyle(fontStyle: FontStyle.italic);
  static const _bold = TextStyle(fontWeight: FontWeight.bold);
  static const _underline = TextStyle(decoration: TextDecoration.underline);
}

TextStyle? _merge(TextStyle? a, TextStyle? b) => a?.merge(b) ?? b;

const _headingStyle = TextStyle(fontWeight: FontWeight.bold);

class _KaraokeDocumentBuilder {
  static final _tokenPattern = RegExp(r'\s+|\S+');

  final _blocks = <KaraokeBlock>[];
  final _words = <String>[];
  final _wordBlock = <int>[];
  final _wordStart = <int>[];
  final _wordEnd = <int>[];

  void addTextBlock(
    KaraokeBlockKind kind,
    List<(String, TextStyle?)> segments, {
    int headingLevel = 0,
    TextDirection? textDirection,
  }) {
    final blockIndex = _blocks.length;
    final firstWordIndex = _wordBlock.length;
    final runs = <KaraokeRun>[];
    var offset = 0;
    var currentWord = -1;

    // A word may span several segments, e.g. "**bold**word".
    for (final (text, style) in segments) {
      for (final match in _tokenPattern.allMatches(text)) {
        final part = match[0]!;
        final isWhitespace = part.trim().isEmpty;
        if (isWhitespace) {
          if (currentWord >= 0) {
            _wordEnd.add(offset);
            currentWord = -1;
          }
          runs.add(
            KaraokeRun(part, _wordBlock.length - 1, style, isWord: false),
          );
        } else {
          if (currentWord < 0) {
            currentWord = _wordBlock.length;
            _wordBlock.add(blockIndex);
            _wordStart.add(offset);
            _words.add(part);
          } else {
            _words[currentWord] += part;
          }
          runs.add(KaraokeRun(part, currentWord, style, isWord: true));
        }
        offset += part.length;
      }
    }
    if (currentWord >= 0) _wordEnd.add(offset);

    _blocks.add(
      KaraokeBlock(
        kind: kind,
        runs: runs,
        firstWordIndex: firstWordIndex,
        wordCount: _wordBlock.length - firstWordIndex,
        headingLevel: headingLevel,
        textDirection: textDirection,
      ),
    );
  }

  void addRuleBlock() {
    _blocks.add(
      KaraokeBlock(
        kind: KaraokeBlockKind.rule,
        runs: const [],
        firstWordIndex: _wordBlock.length,
        wordCount: 0,
      ),
    );
  }

  KaraokeDocument build() => KaraokeDocument._(
    List.unmodifiable(_blocks),
    List.unmodifiable(_words),
    Int32List.fromList(_wordBlock),
    Int32List.fromList(_wordStart),
    Int32List.fromList(_wordEnd),
  );
}

class KaraokeController extends ChangeNotifier {
  int _activeWordIndex = -1;
  KaraokeDocument _document = KaraokeDocument.empty;
  Timer? _debugTimer;
  bool _speechMode = false;
  int _seekCount = 0;
  _KaraokeTextState? _state;

  /// While true (the user drags the text) the active word is not scrolled
  /// into view and speech does not move it.
  bool isUserScrolling = false;

  /// -1 means no word has been reached yet.
  int get activeWordIndex => _activeWordIndex;

  /// Incremented by every [seek], including seeks to the current word.
  int get seekCount => _seekCount;

  int get wordCount => _document.wordCount;

  /// The document currently rendered by the attached [KaraokeText].
  KaraokeDocument get document => _document;

  bool get isDebugTimerRunning => _debugTimer != null;

  /// While true, speech recognition drives [activeWordIndex] and the debug
  /// timer does not run.
  bool get speechMode => _speechMode;

  set speechMode(bool value) {
    if (value == _speechMode) return;
    _speechMode = value;
    if (value) {
      _debugTimer?.cancel();
      _debugTimer = null;
    }
    notifyListeners();
  }

  set activeWordIndex(int index) {
    final next = _clamp(index);
    if (next == _activeWordIndex) return;
    _activeWordIndex = next;
    notifyListeners();
  }

  int _clamp(int index) => wordCount == 0 ? -1 : index.clamp(-1, wordCount - 1);

  /// Manual move of the reading position (buttons, scrolling); speech
  /// following restarts from here.
  void seek(int index) {
    _seekCount++;
    _activeWordIndex = _clamp(index);
    notifyListeners();
  }

  /// Seeks to just before the first word of the line at the reading line
  /// ([KaraokeText.revealAlignment] of the viewport), so that word is the
  /// next one to be read. Returns false while the text is not laid out.
  bool seekToReadingLine() {
    final nextWord = _state?._wordAtReadingLine();
    if (nextWord == null) return false;
    seek(nextWord - 1);
    return true;
  }

  void next() => seek(_activeWordIndex + 1);

  void previous() => seek(_activeWordIndex - 1);

  void reset() => seek(-1);

  void startDebugTimer({
    Duration interval = const Duration(milliseconds: 1000),
  }) {
    if (_speechMode) return;
    _debugTimer?.cancel();
    _debugTimer = Timer.periodic(interval, (_) {
      if (_activeWordIndex >= wordCount - 1) {
        stopDebugTimer();
      } else {
        activeWordIndex = _activeWordIndex + 1;
      }
    });
    notifyListeners();
  }

  void stopDebugTimer() {
    if (_debugTimer == null) return;
    _debugTimer!.cancel();
    _debugTimer = null;
    notifyListeners();
  }

  void toggleDebugTimer() =>
      isDebugTimerRunning ? stopDebugTimer() : startDebugTimer();

  /// Offset of a block relative to the top of the [KaraokeText].
  double? blockOffset(int blockIndex) => _state?._blockOffset(blockIndex);

  void _updateDocument(KaraokeDocument document) {
    _document = document;
    if (_activeWordIndex >= wordCount) {
      _activeWordIndex = wordCount - 1;
      // Called during a widget update, so listeners are notified afterwards.
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  @override
  void dispose() {
    _debugTimer?.cancel();
    super.dispose();
  }
}

class KaraokeText extends StatefulWidget {
  final String text;

  /// When set, the text is rendered as markdown from this AST.
  final MarkdownAst? markdownAst;
  final KaraokeController controller;
  final TextStyle? style;
  final TextAlign? textAlign;
  final double? width;

  /// Where the active word is placed in the viewport when it has to scroll
  /// (0 = top, 1 = bottom).
  final double revealAlignment;

  /// Called after the blocks have been laid out.
  final VoidCallback? onLayout;

  const KaraokeText({
    super.key,
    required this.text,
    required this.controller,
    this.markdownAst,
    this.style,
    this.textAlign,
    this.width,
    this.revealAlignment = 0.35,
    this.onLayout,
  });

  @override
  State<KaraokeText> createState() => _KaraokeTextState();
}

class _KaraokeTextState extends State<KaraokeText> {
  KaraokeDocument _document = KaraokeDocument.empty;
  List<GlobalKey> _blockKeys = const [];

  // Block widgets are cached per "block state" so that moving the active word
  // only rebuilds the blocks whose highlighting actually changed.
  List<Widget?> _blockCache = const [];
  List<int> _blockCacheState = const [];
  (TextStyle, TextStyle)? _stateStyles;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    widget.controller.addListener(_onActiveWordChanged);
    _rebuildDocument();
    _scheduleLayoutNotification();
  }

  @override
  void didUpdateWidget(covariant KaraokeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onActiveWordChanged);
      if (oldWidget.controller._state == this) {
        oldWidget.controller._state = null;
      }
      widget.controller._state = this;
      widget.controller.addListener(_onActiveWordChanged);
      widget.controller._updateDocument(_document);
    }
    if (oldWidget.text != widget.text ||
        oldWidget.markdownAst != widget.markdownAst) {
      _rebuildDocument();
    } else if (oldWidget.style != widget.style ||
        oldWidget.textAlign != widget.textAlign ||
        oldWidget.width != widget.width) {
      _clearCache();
    }
    _scheduleLayoutNotification();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onActiveWordChanged);
    if (widget.controller._state == this) widget.controller._state = null;
    super.dispose();
  }

  void _rebuildDocument() {
    final ast = widget.markdownAst;
    _document = ast != null
        ? KaraokeDocument.markdown(ast)
        : KaraokeDocument.plain(widget.text);
    _blockKeys = List.generate(_document.blocks.length, (_) => GlobalKey());
    _clearCache();
    widget.controller._updateDocument(_document);
  }

  void _clearCache() {
    _blockCache = List.filled(_document.blocks.length, null);
    _blockCacheState = List.filled(_document.blocks.length, 0);
  }

  void _scheduleLayoutNotification() {
    if (widget.onLayout == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLayout?.call();
    });
  }

  void _onActiveWordChanged() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealActiveWord());
  }

  double? _blockOffset(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= _blockKeys.length) return null;
    final root = context.findRenderObject();
    final box = _blockKeys[blockIndex].currentContext?.findRenderObject();
    if (root is! RenderBox || !root.hasSize) return null;
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero, ancestor: root).dy;
  }

  /// Index of the first word on the line at the reading line: the first word
  /// of the next block when the line falls between blocks, 0 above the text
  /// and [KaraokeDocument.wordCount] below it.
  int? _wordAtReadingLine() {
    if (!mounted || _document.wordCount == 0) return null;
    final root = context.findRenderObject();
    if (root is! RenderBox || !root.attached || !root.hasSize) return null;
    if (RenderAbstractViewport.maybeOf(root) case final RenderBox viewport
        when viewport.hasSize) {
      final lineY = viewport.size.height * widget.revealAlignment;
      final blocks = _document.blocks;
      for (var i = 0; i < blocks.length; i++) {
        final block = blocks[i];
        if (block.wordCount == 0) continue;
        final box = _blockKeys[i].currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize) return null;
        final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
        if (top > lineY) return block.firstWordIndex;
        if (top + box.size.height <= lineY) continue;

        final paragraph = _findRenderParagraph(box);
        if (paragraph == null) return block.firstWordIndex;
        final y =
            lineY - paragraph.localToGlobal(Offset.zero, ancestor: viewport).dy;
        // Word boxes are ordered top to bottom: find the first word whose
        // line ends below the reading line.
        var low = 0;
        var high = block.wordCount;
        while (low < high) {
          final mid = (low + high) >> 1;
          final range = _document.rangeOfWord(block.firstWordIndex + mid);
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: range.start, extentOffset: range.end),
          );
          if (boxes.isNotEmpty && boxes.last.bottom <= y) {
            low = mid + 1;
          } else {
            high = mid;
          }
        }
        return block.firstWordIndex + low;
      }
      return _document.wordCount;
    }
    return null;
  }

  void _revealActiveWord() {
    if (!mounted || widget.controller.isUserScrolling) return;
    final active = widget.controller.activeWordIndex;
    if (active < 0 || active >= _document.wordCount) return;

    final blockObject = _blockKeys[_document.blockOfWord(active)].currentContext
        ?.findRenderObject();
    if (blockObject == null || !blockObject.attached) return;

    final paragraph = _findRenderParagraph(blockObject);
    final target = paragraph ?? blockObject;
    Rect? wordRect;
    if (paragraph != null) {
      final range = _document.rangeOfWord(active);
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end),
      );
      if (boxes.isNotEmpty) {
        wordRect = boxes
            .map((b) => b.toRect())
            .reduce((a, b) => a.expandToInclude(b));
      }
    }

    final viewport = RenderAbstractViewport.maybeOf(target);
    final position = Scrollable.maybeOf(context)?.position;
    if (viewport == null || position == null || !position.hasPixels) return;

    final extent = position.viewportDimension;
    final topAligned = viewport.getOffsetToReveal(target, 0, rect: wordRect);
    final bottomAligned = viewport.getOffsetToReveal(target, 1, rect: wordRect);
    final rectTop = topAligned.offset - position.pixels;
    final rectBottom = bottomAligned.offset - position.pixels + extent;
    if (rectTop >= extent * 0.15 && rectBottom <= extent * 0.75) return;

    final destination = viewport
        .getOffsetToReveal(target, widget.revealAlignment, rect: wordRect)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    position.animateTo(
      destination,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  static RenderParagraph? _findRenderParagraph(RenderObject object) {
    if (object is RenderParagraph) return object;
    RenderParagraph? found;
    object.visitChildren((child) {
      found ??= _findRenderParagraph(child);
    });
    return found;
  }

  /// -1: all words unread, -2: all words read, otherwise the local index of
  /// the active word.
  int _blockState(KaraokeBlock block, int active) {
    if (block.wordCount == 0 || active < block.firstWordIndex) return -1;
    if (active >= block.firstWordIndex + block.wordCount) return -2;
    return active - block.firstWordIndex;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor =
        widget.style?.color ??
        DefaultTextStyle.of(context).style.color ??
        theme.colorScheme.onSurface;
    // Only the color changes between states, so weight, style and layout of
    // the markdown spans stay untouched.
    final styles = (
      TextStyle(color: baseColor.withValues(alpha: 0.35)),
      TextStyle(color: theme.colorScheme.primary),
    );
    if (styles != _stateStyles) {
      _stateStyles = styles;
      _clearCache();
    }

    final active = widget.controller.activeWordIndex;
    final blocks = _document.blocks;
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final state = _blockState(blocks[i], active);
      if (_blockCache[i] == null || _blockCacheState[i] != state) {
        _blockCache[i] = _buildBlock(i, active);
        _blockCacheState[i] = state;
      }
      children.add(_blockCache[i]!);
    }

    return Column(
      spacing: widget.markdownAst != null ? 32 : 0,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildBlock(int blockIndex, int active) {
    final block = _document.blocks[blockIndex];
    final Widget child;
    if (block.kind == KaraokeBlockKind.rule) {
      child = Divider(height: 30, thickness: 3, color: widget.style?.color);
    } else {
      // Span structure mirrors tief_weave's MarkdownRenderer: the root carries
      // the base style and every child carries the fully resolved style.
      final isHeading = block.kind == KaraokeBlockKind.heading;
      child = SizedBox(
        width: widget.width ?? double.infinity,
        child: Text.rich(
          TextSpan(
            style: isHeading
                ? _merge(widget.style, _headingStyle)
                : widget.style,
            children: _buildSpans(block, active),
          ),
          textAlign: widget.textAlign,
          textDirection: block.textDirection,
          textScaler: isHeading
              ? TextScaler.linear(2 + block.headingLevel / -6)
              : null,
        ),
      );
    }
    return KeyedSubtree(
      key: _blockKeys[blockIndex],
      child: RepaintBoundary(child: child),
    );
  }

  /// Adjacent runs with identical styling are merged into a single span, so
  /// only the active word and the read/unread boundary produce extra spans.
  List<InlineSpan> _buildSpans(KaraokeBlock block, int active) {
    final (readStyle, activeStyle) = _stateStyles!;
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    TextStyle? pendingStyle;

    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString(), style: pendingStyle));
      buffer.clear();
    }

    for (final run in block.runs) {
      final TextStyle? stateStyle;
      if (run.wordIndex >= 0 && run.wordIndex < active) {
        stateStyle = readStyle;
      } else if (run.isWord && run.wordIndex == active) {
        stateStyle = activeStyle;
      } else {
        stateStyle = null;
      }
      final style = _merge(_merge(widget.style, run.style), stateStyle);
      if (style != pendingStyle) {
        flush();
        pendingStyle = style;
      }
      buffer.write(run.text);
    }
    flush();
    return spans;
  }
}

class KaraokeDebugPanel extends StatelessWidget {
  final KaraokeController controller;

  /// Starts/stops speech following; the button is hidden when null.
  final VoidCallback? onToggleSpeech;

  const KaraokeDebugPanel({
    super.key,
    required this.controller,
    this.onToggleSpeech,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Material(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  '${controller.activeWordIndex}/${controller.wordCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              IconButton(
                color: Colors.white,
                tooltip: 'Previous word',
                icon: const Icon(Icons.skip_previous),
                onPressed: controller.previous,
              ),
              IconButton(
                color: Colors.white,
                tooltip: 'Auto-advance every 1000 ms',
                icon: Icon(
                  controller.isDebugTimerRunning
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
                onPressed: controller.speechMode
                    ? null
                    : controller.toggleDebugTimer,
              ),
              IconButton(
                color: Colors.white,
                tooltip: 'Next word',
                icon: const Icon(Icons.skip_next),
                onPressed: controller.next,
              ),
              IconButton(
                color: Colors.white,
                tooltip: 'Reset',
                icon: const Icon(Icons.replay),
                onPressed: () {
                  controller.stopDebugTimer();
                  controller.reset();
                },
              ),
              if (onToggleSpeech != null)
                IconButton(
                  color: controller.speechMode
                      ? Colors.greenAccent
                      : Colors.white,
                  tooltip: controller.speechMode
                      ? 'Stop following speech'
                      : 'Follow speech (STT mode)',
                  icon: Icon(
                    controller.speechMode
                        ? Icons.record_voice_over
                        : Icons.voice_over_off,
                  ),
                  onPressed: onToggleSpeech,
                ),
              IconButton(
                color: Colors.white,
                tooltip: 'Speech-to-text test',
                icon: const Icon(Icons.mic),
                onPressed: () => context.push('/speech_debug'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
