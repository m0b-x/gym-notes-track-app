import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Represents a single line in the virtual editor with its metadata
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

/// A high-performance text editor that virtualizes line rendering.
///
/// Only renders lines that are visible in the viewport plus a small buffer,
/// making it suitable for editing very large documents (50K+ characters).
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
  });

  @override
  State<VirtualScrollingEditor> createState() => VirtualScrollingEditorState();
}

class VirtualScrollingEditorState extends State<VirtualScrollingEditor> {
  static const _defaultTextStyle = TextStyle(fontSize: 16, height: 1.5);
  static const _hiddenTextStyle = TextStyle(fontSize: 1);
  static const _defaultHintStyle = TextStyle(fontSize: 16);
  static const _horizontalPadding = EdgeInsets.symmetric(horizontal: 8);
  static const _hintPadding = EdgeInsets.all(8.0);

  late ScrollController _scrollController;
  bool _ownsScrollController = false;
  late TextEditingController _hiddenController;
  late FocusNode _focusNode;

  /// The parsed lines of the document
  List<VirtualLine> _lines = [];

  /// Cursor state
  int _cursorLine = 0;
  int _cursorColumn = 0;
  final ValueNotifier<bool> _showCursor = ValueNotifier(true);
  Timer? _cursorTimer;

  /// Debounce timer for expensive operations
  Timer? _debounceTimer;
  static const _debounceDelay = Duration(milliseconds: 16);

  /// Tracking for incremental updates
  String _previousContent = '';
  int _previousLineCount = 0;

  /// Key to force SliverList rebuild when content changes
  int _listKey = 0;

  /// Cached text style for performance
  TextStyle? _cachedTextStyle;

  /// ValueNotifier for the current cursor line - allows targeted rebuilds
  final ValueNotifier<int> _cursorLineNotifier = ValueNotifier(0);

  /// Track if we need a full rebuild or just cursor line update
  bool _needsFullRebuild = false;

  // Public getters for accessing editor state
  String get text => _hiddenController.text;

  set text(String value) {
    _hiddenController.text = value;
    _rebuildLines();
  }

  TextEditingController get controller => _hiddenController;

  @override
  void initState() {
    super.initState();

    // Initialize scroll controller
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
      _ownsScrollController = false;
    } else {
      _scrollController = ScrollController();
      _ownsScrollController = true;
    }

    // Initialize text controller and focus node
    _hiddenController = TextEditingController(text: widget.initialContent);
    _focusNode = widget.focusNode ?? FocusNode();

    // Parse initial content into lines
    _rebuildLines();
    _previousContent = _hiddenController.text;
    _previousLineCount = _lines.length;

    // Set up listeners
    _hiddenController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);

    // Start cursor blink
    _startCursorBlink();
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    _debounceTimer?.cancel();
    _showCursor.dispose();
    _cursorLineNotifier.dispose();

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

  void _rebuildLines() {
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
      offset += lines[i].length + 1; // +1 for newline
    }

    _lines = virtualLines;
    _listKey++;
  }

  /// Updates only the affected line for small edits (optimization)
  void _updateSingleLine(String content, int cursorOffset) {
    cursorOffset = cursorOffset.clamp(0, content.length);

    // Find line boundaries from actual content
    int lineStart = cursorOffset > 0
        ? content.lastIndexOf('\n', cursorOffset - 1)
        : -1;
    lineStart = lineStart == -1 ? 0 : lineStart + 1;

    int lineEnd = content.indexOf('\n', cursorOffset);
    lineEnd = lineEnd == -1 ? content.length : lineEnd;

    // Find line index by counting newlines
    int lineIndex = 0;
    for (int i = 0; i < lineStart; i++) {
      if (content[i] == '\n') lineIndex++;
    }

    if (lineIndex >= _lines.length) {
      _rebuildLines();
      return;
    }

    final lineContent = content.substring(lineStart, lineEnd);
    final oldLine = _lines[lineIndex];
    final lengthDiff = lineContent.length - oldLine.content.length;

    // Update the changed line
    _lines[lineIndex] = VirtualLine(
      lineNumber: lineIndex,
      content: lineContent,
      startOffset: lineStart,
      endOffset: lineEnd,
    );

    // Update offsets for all following lines
    if (lengthDiff != 0) {
      for (int i = lineIndex + 1; i < _lines.length; i++) {
        final line = _lines[i];
        _lines[i] = VirtualLine(
          lineNumber: line.lineNumber,
          content: line.content,
          startOffset: line.startOffset + lengthDiff,
          endOffset: line.endOffset + lengthDiff,
        );
      }
    }

    _listKey++; // Force rebuild of affected lines
  }

  /// Updates the cursor position based on selection
  void _updateCursorPosition() {
    final cursorOffset = _hiddenController.selection.baseOffset;
    if (cursorOffset < 0 || _lines.isEmpty) return;

    for (int i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final isLastLine = i == _lines.length - 1;
      final lineEndWithNewline = line.endOffset + (isLastLine ? 0 : 1);

      if (cursorOffset <= lineEndWithNewline) {
        _cursorLine = i;
        _cursorColumn = cursorOffset - line.startOffset;
        break;
      }
    }
  }

  void _onTextChanged() {
    final content = _hiddenController.text;
    final cursorOffset = _hiddenController.selection.baseOffset;
    final newLineCount = '\n'.allMatches(content).length + 1;
    final lineCountChanged = newLineCount != _previousLineCount;
    final contentLengthDiff = (content.length - _previousContent.length).abs();

    final oldCursorLine = _cursorLine;
    final oldCursorColumn = _cursorColumn;

    // Always rebuild lines to ensure fresh offsets for cursor positioning
    // This is critical for autocorrect which can change text unexpectedly
    if (!lineCountChanged &&
        contentLengthDiff <= 2 &&
        _lines.isNotEmpty &&
        cursorOffset >= 0) {
      _updateSingleLine(content, cursorOffset);
      _needsFullRebuild = false;
    } else {
      _rebuildLines();
      _needsFullRebuild = true;
    }

    _previousContent = content;
    _previousLineCount = newLineCount;

    // Update cursor position from the hidden controller's selection
    if (cursorOffset >= 0 && _lines.isNotEmpty) {
      for (int i = 0; i < _lines.length; i++) {
        final line = _lines[i];
        if (cursorOffset <= line.endOffset || i == _lines.length - 1) {
          _cursorLine = i;
          _cursorColumn = (cursorOffset - line.startOffset).clamp(
            0,
            line.content.length,
          );
          break;
        }
      }
    }

    // Rebuild if line count changed, cursor moved to different line, OR cursor column changed
    final cursorMoved =
        oldCursorLine != _cursorLine || oldCursorColumn != _cursorColumn;
    if (_needsFullRebuild || lineCountChanged || cursorMoved) {
      setState(() {});
    }
    _cursorLineNotifier.value = _cursorLine;

    // Debounce expensive operations
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      if (!mounted) return;

      _scrollCursorIntoView();
      widget.onChanged?.call(_hiddenController.text);
    });
  }

  /// Scrolls the view to ensure the cursor is visible
  void _scrollCursorIntoView() {
    if (!_scrollController.hasClients) return;

    final cursorY = _cursorLine * widget.lineHeight;
    final viewportHeight = _scrollController.position.viewportDimension;
    final currentScroll = _scrollController.offset;
    final totalContentHeight = _lines.length * widget.lineHeight;
    final maxScroll = (totalContentHeight - viewportHeight).clamp(
      0.0,
      double.infinity,
    );

    // Check if cursor is below visible area
    final bottomThreshold =
        currentScroll + viewportHeight - widget.lineHeight * 2;
    if (cursorY > bottomThreshold) {
      final targetScroll = (cursorY - viewportHeight + widget.lineHeight * 3)
          .clamp(0.0, maxScroll);
      _scrollController.jumpTo(targetScroll);
      return;
    }

    // Check if cursor is above visible area
    final topThreshold = currentScroll + widget.lineHeight;
    if (cursorY < topThreshold) {
      final targetScroll = (cursorY - widget.lineHeight).clamp(0.0, maxScroll);
      _scrollController.jumpTo(targetScroll);
    }
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _startCursorBlink() {
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _showCursor.value = !_showCursor.value;
    });
  }

  /// Handles tap on a line to position cursor
  void _handleLineTap(int lineIndex, Offset localPosition) {
    if (widget.readOnly) return;
    _focusNode.requestFocus();

    if (lineIndex >= _lines.length) return;

    final line = _lines[lineIndex];
    final tapX = (localPosition.dx - 8).clamp(0.0, double.infinity);

    if (line.content.isEmpty) {
      _cursorLine = lineIndex;
      _cursorColumn = 0;
      _hiddenController.selection = TextSelection.collapsed(
        offset: line.startOffset,
      );
    } else {
      final textStyle = widget.textStyle ?? _defaultTextStyle;
      final textPainter = TextPainter(
        text: TextSpan(text: line.content, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Build array of caret X positions for each character boundary
      final caretPositions = <double>[];
      for (int i = 0; i <= line.content.length; i++) {
        caretPositions.add(
          textPainter.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dx,
        );
      }

      // Find the closest caret position to the tap
      int charOffset = 0;
      double minDistance = (tapX - caretPositions[0]).abs();
      for (int i = 1; i < caretPositions.length; i++) {
        final distance = (tapX - caretPositions[i]).abs();
        if (distance < minDistance) {
          minDistance = distance;
          charOffset = i;
        }
      }

      _cursorLine = lineIndex;
      _cursorColumn = charOffset;
      _hiddenController.selection = TextSelection.collapsed(
        offset: line.startOffset + charOffset,
      );
    }

    setState(() {});
  }

  /// Handles keyboard navigation
  void _handleKeyEvent(KeyEvent event) {
    if (widget.readOnly) return;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final selection = _hiddenController.selection;
      final text = _hiddenController.text;

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

  /// Public method to scroll to a specific line
  void scrollToLine(int lineNumber) {
    final offset = lineNumber * widget.lineHeight;
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// Public method to scroll to the cursor position
  void scrollToCursor() {
    scrollToLine(_cursorLine);
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _hiddenController.text.isEmpty;

    return Stack(
      children: [
        // Hidden TextField for text input handling
        Positioned.fill(
          child: Opacity(
            opacity: 0.0,
            child: TextField(
              controller: _hiddenController,
              focusNode: _focusNode,
              maxLines: null,
              expands: true,
              readOnly: widget.readOnly,
              style: _hiddenTextStyle,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        // Visible virtualized content
        Positioned.fill(
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: _handleKeyEvent,
            child: GestureDetector(
              onTap: () => _focusNode.requestFocus(),
              behavior: HitTestBehavior.translucent,
              child: isEmpty && widget.hintText != null
                  ? Padding(
                      padding: _hintPadding,
                      child: Text(
                        widget.hintText!,
                        style:
                            widget.hintStyle ??
                            _defaultHintStyle.copyWith(
                              color: Theme.of(context).hintColor,
                            ),
                      ),
                    )
                  : _buildVirtualizedContent(context),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the virtualized scrollable content using SliverFixedExtentList
  Widget _buildVirtualizedContent(BuildContext context) {
    _cachedTextStyle ??= widget.textStyle ?? _defaultTextStyle;
    final textStyle = _cachedTextStyle!;
    final hasFocus = _focusNode.hasFocus;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverFixedExtentList(
          key: ValueKey(_listKey),
          itemExtent: widget.lineHeight,
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= _lines.length) return null;

              final line = _lines[index];
              // Read _cursorLine directly, not from captured variable
              final isCursorLine = index == _cursorLine && hasFocus;

              // Use RepaintBoundary for non-cursor lines to prevent unnecessary repaints
              Widget lineWidget = GestureDetector(
                onTapDown: (details) =>
                    _handleLineTap(index, details.localPosition),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: _horizontalPadding,
                  child: isCursorLine
                      ? _buildCursorLineWidget(line, textStyle)
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            line.content.isEmpty ? ' ' : line.content,
                            style: textStyle,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                ),
              );

              // Wrap non-cursor lines in RepaintBoundary for isolation
              return isCursorLine
                  ? lineWidget
                  : RepaintBoundary(child: lineWidget);
            },
            childCount: _lines.length,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
          ),
        ),
      ],
    );
  }

  /// Builds the cursor line widget with text and cursor
  Widget _buildCursorLineWidget(VirtualLine line, TextStyle textStyle) {
    return ValueListenableBuilder<int>(
      valueListenable: _cursorLineNotifier,
      builder: (context, _, _) {
        // IMPORTANT: Read fresh line data from _lines, not the captured parameter
        // This ensures we get the latest content after fast typing
        final currentLine = _cursorLine < _lines.length
            ? _lines[_cursorLine]
            : line;
        final content = currentLine.content;

        return Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                content.isEmpty ? ' ' : content,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _showCursor,
              builder: (context, showCursor, child) {
                if (!showCursor) return const SizedBox.shrink();
                return _buildCursorWidget(currentLine, textStyle);
              },
            ),
          ],
        );
      },
    );
  }

  /// Builds the cursor widget for a line
  Widget _buildCursorWidget(VirtualLine line, TextStyle textStyle) {
    final freshLine = _cursorLine < _lines.length ? _lines[_cursorLine] : line;
    final column = _cursorColumn.clamp(0, freshLine.content.length);
    double cursorX = 0;

    if (column > 0 && freshLine.content.isNotEmpty) {
      // Use getOffsetForCaret for consistency with tap handling
      final textPainter = TextPainter(
        text: TextSpan(text: freshLine.content, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      cursorX = textPainter
          .getOffsetForCaret(TextPosition(offset: column), Rect.zero)
          .dx;
    }

    return Positioned(
      left: cursorX,
      top: 2,
      bottom: 2,
      child: const _CursorWidget(),
    );
  }
}

/// Extracted cursor widget to avoid rebuilds
class _CursorWidget extends StatelessWidget {
  const _CursorWidget();

  @override
  Widget build(BuildContext context) {
    return Container(width: 2, color: Theme.of(context).colorScheme.primary);
  }
}

/// A simpler read-only virtualized text viewer
class VirtualTextViewer extends StatefulWidget {
  final String content;
  final TextStyle? textStyle;
  final double lineHeight;
  final Widget Function(String line, int lineNumber)? lineBuilder;

  const VirtualTextViewer({
    super.key,
    required this.content,
    this.textStyle,
    this.lineHeight = 24.0,
    this.lineBuilder,
  });

  @override
  State<VirtualTextViewer> createState() => _VirtualTextViewerState();
}

class _VirtualTextViewerState extends State<VirtualTextViewer> {
  static const _defaultTextStyle = TextStyle(fontSize: 16, height: 1.5);
  static const _horizontalPadding = EdgeInsets.symmetric(horizontal: 8);

  late ScrollController _scrollController;
  late List<String> _lines;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _lines = widget.content.split('\n');
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

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.textStyle ?? _defaultTextStyle;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= _lines.length) return null;

              final line = _lines[index];

              return SizedBox(
                height: widget.lineHeight,
                child:
                    widget.lineBuilder?.call(line, index) ??
                    Container(
                      padding: _horizontalPadding,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        line.isEmpty ? ' ' : line,
                        style: textStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              );
            },
            childCount: _lines.length,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
          ),
        ),
      ],
    );
  }
}
