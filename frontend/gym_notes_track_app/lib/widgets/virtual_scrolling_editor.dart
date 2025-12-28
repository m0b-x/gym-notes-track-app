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
    this.readOnly = false,
    this.lineHeight = 24.0,
    this.visibleLinesBuffer = 10,
  });

  @override
  State<VirtualScrollingEditor> createState() => VirtualScrollingEditorState();
}

class VirtualScrollingEditorState extends State<VirtualScrollingEditor> {
  late ScrollController _scrollController;
  late TextEditingController _hiddenController;
  late FocusNode _focusNode;
  late List<VirtualLine> _lines;

  int _firstVisibleLine = 0;
  int _lastVisibleLine = 0;
  int _cursorLine = 0;
  int _cursorColumn = 0;
  bool _showCursor = true;

  String get text => _hiddenController.text;

  set text(String value) {
    _hiddenController.text = value;
    _updateLines();
  }

  TextEditingController get controller => _hiddenController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _hiddenController = TextEditingController(text: widget.initialContent);
    _focusNode = widget.focusNode ?? FocusNode();

    _updateLines();

    _hiddenController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(_onFocusChanged);

    _startCursorBlink();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _hiddenController.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _updateLines() {
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
    _updateLines();
    widget.onChanged?.call(_hiddenController.text);
    setState(() {});
  }

  void _onScroll() {
    _calculateVisibleLines();
    setState(() {});
  }

  void _onFocusChanged() {
    setState(() {});
  }

  void _calculateVisibleLines() {
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

  void _startCursorBlink() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return false;
      setState(() {
        _showCursor = !_showCursor;
      });
      return true;
    });
  }

  void _handleTap(int lineIndex, Offset localPosition) {
    if (widget.readOnly) return;

    _focusNode.requestFocus();

    final line = _lines[lineIndex];
    final textPainter = TextPainter(
      text: TextSpan(
        text: line.content,
        style: widget.textStyle ?? const TextStyle(fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final offset = textPainter.getPositionForOffset(localPosition);
    final newCursorOffset = line.startOffset + offset.offset;

    _hiddenController.selection = TextSelection.collapsed(
      offset: newCursorOffset,
    );
    _updateCursorPosition();
    setState(() {});
  }

  void _handleKeyEvent(KeyEvent event) {
    if (widget.readOnly) return;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final selection = _hiddenController.selection;
      final text = _hiddenController.text;

      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (selection.isCollapsed && selection.baseOffset > 0) {
          final newText =
              text.substring(0, selection.baseOffset - 1) +
              text.substring(selection.baseOffset);
          _hiddenController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(
              offset: selection.baseOffset - 1,
            ),
          );
        }
      } else if (event.logicalKey == LogicalKeyboardKey.delete) {
        if (selection.isCollapsed && selection.baseOffset < text.length) {
          final newText =
              text.substring(0, selection.baseOffset) +
              text.substring(selection.baseOffset + 1);
          _hiddenController.value = TextEditingValue(
            text: newText,
            selection: selection,
          );
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
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
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        _insertText('\n');
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

  void _insertText(String text) {
    final selection = _hiddenController.selection;
    final currentText = _hiddenController.text;

    final newText =
        currentText.substring(0, selection.baseOffset) +
        text +
        currentText.substring(selection.extentOffset);

    _hiddenController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.baseOffset + text.length,
      ),
    );
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

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Container(
          color: Colors.transparent,
          child: _lines.isEmpty && widget.hintText != null
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
    );
  }

  List<Widget> _buildVisibleLines(BuildContext context) {
    _calculateVisibleLines();

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
          child: GestureDetector(
            onTapDown: (details) => _handleTap(i, details.localPosition),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerLeft,
              child: Text(
                line.content.isEmpty ? ' ' : line.content,
                style:
                    widget.textStyle ??
                    const TextStyle(fontSize: 16, height: 1.5),
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
    final line = _lines.isNotEmpty && _cursorLine < _lines.length
        ? _lines[_cursorLine]
        : null;

    if (line == null) return const SizedBox.shrink();

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
