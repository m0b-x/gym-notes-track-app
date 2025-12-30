import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VirtualLine {
  final int lineNumber;
  final String content;
  final int startOffset;
  final int endOffset;

  const VirtualLine({
    required this.lineNumber,
    required this.content,
    required this.startOffset,
    required this.endOffset,
  });
}

class VirtualScrollingEditor extends StatefulWidget {
  final String initialContent;
  final ValueChanged<String>? onChanged;
  final TextStyle? textStyle;
  final String? hintText;
  final TextStyle? hintStyle;
  final FocusNode? focusNode;
  final ScrollController? scrollController;
  final bool readOnly;
  final double lineHeight;
  final int visibleLinesBuffer;

  const VirtualScrollingEditor({
    super.key,
    required this.initialContent,
    this.onChanged,
    this.textStyle,
    this.hintText,
    this.hintStyle,
    this.focusNode,
    this.scrollController,
    this.readOnly = false,
    this.lineHeight = 24.0,
    this.visibleLinesBuffer = 10,
  });

  @override
  State<VirtualScrollingEditor> createState() => VirtualScrollingEditorState();
}

class VirtualScrollingEditorState extends State<VirtualScrollingEditor> {
  late ScrollController _scrollController;
  bool _ownsScrollController = false;
  late TextEditingController _hiddenController;
  late FocusNode _focusNode;
  List<VirtualLine> _lines = [];

  int _firstVisibleLine = 0;
  int _lastVisibleLine = 0;
  int _cursorLine = 0;
  int _cursorColumn = 0;
  bool _showCursor = true;
  Timer? _cursorTimer;
  Timer? _debounceTimer;

  // Debounce delay for large text updates
  static const _debounceDelay = Duration(milliseconds: 16);

  String get text => _hiddenController.text;

  set text(String value) {
    _hiddenController.text = value;
    _updateLinesImmediate();
  }

  TextEditingController get controller => _hiddenController;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
      _ownsScrollController = false;
    } else {
      _scrollController = ScrollController();
      _ownsScrollController = true;
    }
    _hiddenController = TextEditingController(text: widget.initialContent);
    _focusNode = widget.focusNode ?? FocusNode();

    _updateLinesImmediate();

    _hiddenController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(_onFocusChanged);

    _startCursorBlink();
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    _debounceTimer?.cancel();
    if (_ownsScrollController) {
      _scrollController.dispose();
    }
    _hiddenController.removeListener(_onTextChanged);
    _hiddenController.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  /// Immediate update for programmatic changes
  void _updateLinesImmediate() {
    final content = _hiddenController.text;
    final lines = content.split('\n');
    final virtualLines = <VirtualLine>[];

    int offset = 0;
    for (int i = 0; i < lines.length; i++) {
      virtualLines.add(
        VirtualLine(
          lineNumber: i,
          content: lines[i],
          startOffset: offset,
          endOffset: offset + lines[i].length,
        ),
      );
      offset += lines[i].length + 1;
    }

    _lines = virtualLines;
    _updateCursorPosition();
  }

  void _updateCursorPosition() {
    final cursorOffset = _hiddenController.selection.baseOffset;
    if (cursorOffset < 0) return;

    for (int i = 0; i < _lines.length; i++) {
      if (cursorOffset <=
          _lines[i].endOffset + (i < _lines.length - 1 ? 1 : 0)) {
        _cursorLine = i;
        _cursorColumn = cursorOffset - _lines[i].startOffset;
        break;
      }
    }
  }

  void _onTextChanged() {
    // Debounce updates for large text changes (like paste)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      if (!mounted) return;
      _updateLinesImmediate();
      _scrollCursorIntoView();
      widget.onChanged?.call(_hiddenController.text);
      setState(() {});
    });
  }

  void _scrollCursorIntoView() {
    if (!_scrollController.hasClients) return;

    final cursorY = _cursorLine * widget.lineHeight;
    final viewportHeight = _scrollController.position.viewportDimension;
    final currentScroll = _scrollController.offset;

    // Calculate max scroll based on total content, not the current maxScrollExtent
    // (which may not have updated yet after a paste)
    final totalContentHeight = _lines.length * widget.lineHeight;
    final maxScroll = (totalContentHeight - viewportHeight).clamp(
      0.0,
      double.infinity,
    );

    // Check if cursor is below the visible area
    final bottomThreshold =
        currentScroll + viewportHeight - widget.lineHeight * 2;
    if (cursorY > bottomThreshold) {
      // Position cursor near the bottom of the viewport with some padding
      final targetScroll = (cursorY - viewportHeight + widget.lineHeight * 3)
          .clamp(0.0, maxScroll);
      _scrollController.jumpTo(targetScroll);
      return;
    }

    // Check if cursor is above the visible area
    final topThreshold = currentScroll + widget.lineHeight;
    if (cursorY < topThreshold) {
      final targetScroll = (cursorY - widget.lineHeight).clamp(0.0, maxScroll);
      _scrollController.jumpTo(targetScroll);
    }
  }

  void _onScroll() {
    if (!mounted) return;
    _calculateVisibleLines();
    setState(() {});
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _calculateVisibleLines() {
    if (!_scrollController.hasClients) {
      _firstVisibleLine = 0;
      _lastVisibleLine = (widget.visibleLinesBuffer * 2).clamp(
        0,
        _lines.isEmpty ? 0 : _lines.length - 1,
      );
      return;
    }

    final viewportHeight = _scrollController.position.viewportDimension;
    final scrollOffset = _scrollController.offset;

    _firstVisibleLine = (scrollOffset / widget.lineHeight).floor();
    _firstVisibleLine = (_firstVisibleLine - widget.visibleLinesBuffer).clamp(
      0,
      _lines.isEmpty ? 0 : _lines.length - 1,
    );

    final visibleCount = (viewportHeight / widget.lineHeight).ceil();
    _lastVisibleLine =
        _firstVisibleLine + visibleCount + widget.visibleLinesBuffer * 2;
    _lastVisibleLine = _lastVisibleLine.clamp(
      0,
      _lines.isEmpty ? 0 : _lines.length - 1,
    );
  }

  void _startCursorBlink() {
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _showCursor = !_showCursor;
      });
    });
  }

  void _handleTap(int lineIndex, Offset localPosition) {
    if (widget.readOnly) return;
    _focusNode.requestFocus();

    final line = _lines[lineIndex];
    if (line.content.isEmpty) {
      _hiddenController.selection = TextSelection.collapsed(
        offset: line.startOffset,
      );
    } else {
      final textPainter = TextPainter(
        text: TextSpan(
          text: line.content,
          style: widget.textStyle ?? const TextStyle(fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final tapX = localPosition.dx - 8;
      final offset = textPainter.getPositionForOffset(
        Offset(tapX.clamp(0, double.infinity), 0),
      );
      _hiddenController.selection = TextSelection.collapsed(
        offset: line.startOffset + offset.offset,
      );
    }
    _updateCursorPosition();
    setState(() {});
  }

  void _handleKeyEvent(KeyEvent event) {
    if (widget.readOnly) return;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final selection = _hiddenController.selection;
      final text = _hiddenController.text;

      // Handle only navigation keys - text input is handled by the TextField
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _moveCursorVertically(-1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _moveCursorVertically(1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (selection.baseOffset > 0) {
          _hiddenController.selection = TextSelection.collapsed(
            offset: selection.baseOffset - 1,
          );
          _updateCursorPosition();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (selection.baseOffset < text.length) {
          _hiddenController.selection = TextSelection.collapsed(
            offset: selection.baseOffset + 1,
          );
          _updateCursorPosition();
        }
      }
    }
  }

  void _moveCursorVertically(int direction) {
    final targetLine = (_cursorLine + direction).clamp(0, _lines.length - 1);
    if (targetLine == _cursorLine) return;

    final line = _lines[targetLine];
    final newColumn = _cursorColumn.clamp(0, line.content.length);
    final newOffset = line.startOffset + newColumn;

    _hiddenController.selection = TextSelection.collapsed(offset: newOffset);
    _updateCursorPosition();
    setState(() {});
  }

  void scrollToLine(int lineNumber) {
    final offset = lineNumber * widget.lineHeight;
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void scrollToCursor() {
    scrollToLine(_cursorLine);
  }

  @override
  Widget build(BuildContext context) {
    final totalHeight = _lines.length * widget.lineHeight;
    final isEmpty = _hiddenController.text.isEmpty;

    return Stack(
      children: [
        // Invisible TextField that handles all text input including paste
        Positioned.fill(
          child: Opacity(
            opacity: 0.0,
            child: TextField(
              controller: _hiddenController,
              focusNode: _focusNode,
              maxLines: null,
              expands: true,
              readOnly: widget.readOnly,
              style: const TextStyle(fontSize: 1),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        // Visible layer with virtualized rendering
        Positioned.fill(
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: _handleKeyEvent,
            child: GestureDetector(
              onTap: () => _focusNode.requestFocus(),
              behavior: HitTestBehavior.translucent,
              child: Container(
                color: Colors.transparent,
                child: isEmpty && widget.hintText != null
                    ? Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          widget.hintText!,
                          style:
                              widget.hintStyle ??
                              TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: 16,
                              ),
                        ),
                      )
                    : CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: totalHeight,
                              child: Stack(
                                children: [
                                  ..._buildVisibleLines(context),
                                  if (_focusNode.hasFocus && _showCursor)
                                    _buildCursor(context),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildVisibleLines(BuildContext context) {
    _calculateVisibleLines();

    final widgets = <Widget>[];
    final textStyle =
        widget.textStyle ?? const TextStyle(fontSize: 16, height: 1.5);

    for (
      int i = _firstVisibleLine;
      i <= _lastVisibleLine && i < _lines.length;
      i++
    ) {
      final line = _lines[i];
      final lineIndex = i;

      widgets.add(
        Positioned(
          top: i * widget.lineHeight,
          left: 0,
          right: 0,
          height: widget.lineHeight,
          child: GestureDetector(
            onTapDown: (details) =>
                _handleTap(lineIndex, details.localPosition),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerLeft,
              child: Text(
                line.content.isEmpty ? ' ' : line.content,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildCursor(BuildContext context) {
    if (_lines.isEmpty || _cursorLine >= _lines.length) {
      return const SizedBox.shrink();
    }

    final line = _lines[_cursorLine];

    final textPainter = TextPainter(
      text: TextSpan(
        text: line.content.substring(
          0,
          _cursorColumn.clamp(0, line.content.length),
        ),
        style: widget.textStyle ?? const TextStyle(fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final cursorX = textPainter.width + 8;
    final cursorY = _cursorLine * widget.lineHeight;

    return Positioned(
      left: cursorX,
      top: cursorY + 2,
      child: Container(
        width: 2,
        height: widget.lineHeight - 4,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class VirtualTextViewer extends StatefulWidget {
  final String content;
  final TextStyle? textStyle;
  final double lineHeight;
  final int visibleLinesBuffer;
  final Widget Function(String line, int lineNumber)? lineBuilder;

  const VirtualTextViewer({
    super.key,
    required this.content,
    this.textStyle,
    this.lineHeight = 24.0,
    this.visibleLinesBuffer = 10,
    this.lineBuilder,
  });

  @override
  State<VirtualTextViewer> createState() => _VirtualTextViewerState();
}

class _VirtualTextViewerState extends State<VirtualTextViewer> {
  late ScrollController _scrollController;
  late List<String> _lines;

  int _firstVisibleLine = 0;
  int _lastVisibleLine = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _lines = widget.content.split('\n');
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(VirtualTextViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _lines = widget.content.split('\n');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    _calculateVisibleLines();
    setState(() {});
  }

  void _calculateVisibleLines() {
    if (!_scrollController.hasClients) return;

    final viewportHeight = _scrollController.position.viewportDimension;
    final scrollOffset = _scrollController.offset;

    _firstVisibleLine = (scrollOffset / widget.lineHeight).floor();
    _firstVisibleLine = (_firstVisibleLine - widget.visibleLinesBuffer).clamp(
      0,
      _lines.length - 1,
    );

    final visibleCount = (viewportHeight / widget.lineHeight).ceil();
    _lastVisibleLine =
        _firstVisibleLine + visibleCount + widget.visibleLinesBuffer * 2;
    _lastVisibleLine = _lastVisibleLine.clamp(0, _lines.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final totalHeight = _lines.length * widget.lineHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _calculateVisibleLines();
        });

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: totalHeight,
                child: Stack(children: _buildVisibleLines()),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildVisibleLines() {
    final widgets = <Widget>[];

    for (
      int i = _firstVisibleLine;
      i <= _lastVisibleLine && i < _lines.length;
      i++
    ) {
      final line = _lines[i];

      widgets.add(
        Positioned(
          top: i * widget.lineHeight,
          left: 0,
          right: 0,
          height: widget.lineHeight,
          child:
              widget.lineBuilder?.call(line, i) ??
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                child: Text(
                  line.isEmpty ? ' ' : line,
                  style:
                      widget.textStyle ??
                      const TextStyle(fontSize: 16, height: 1.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        ),
      );
    }

    return widgets;
  }
}
