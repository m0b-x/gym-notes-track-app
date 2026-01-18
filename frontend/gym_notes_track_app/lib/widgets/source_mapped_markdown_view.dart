import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../constants/markdown_constants.dart';
import '../utils/markdown_span_builder.dart';
import 'full_markdown_view.dart';

typedef LinkTapCallback = void Function(String url);

class SourceMappedMarkdownView extends StatefulWidget {
  final String data;
  final double fontSize;
  final Function(CheckboxToggleInfo)? onCheckboxToggle;
  final ScrollController? scrollController;
  final EdgeInsets? padding;
  final List<TextRange>? searchHighlights;
  final int? currentHighlightIndex;
  final LinkTapCallback? onTapLink;

  const SourceMappedMarkdownView({
    super.key,
    required this.data,
    this.fontSize = 16.0,
    this.onCheckboxToggle,
    this.scrollController,
    this.padding,
    this.searchHighlights,
    this.currentHighlightIndex,
    this.onTapLink,
  });

  @override
  @override
  State<SourceMappedMarkdownView> createState() =>
      SourceMappedMarkdownViewState();

  /// Helper to access state for imperative actions (e.g., scroll to highlight)
  static SourceMappedMarkdownViewState? of(BuildContext context) {
    return context.findAncestorStateOfType<SourceMappedMarkdownViewState>();
  }
}

class SourceMappedMarkdownViewState extends State<SourceMappedMarkdownView> {
  final List<List<int>> _blockOffsets = [];
  final List<GlobalKey> _blockKeys = [];

  /// Scrolls to the block containing the given source offset (e.g., search highlight start).
  /// Returns true if a block was found and scrolled to.
  /// Binary search for the block containing the given source offset.
  int _findBlockIndexForOffset(int sourceOffset) {
    int low = 0;
    int high = _blockOffsets.length - 1;
    while (low <= high) {
      int mid = (low + high) >> 1;
      final start = _blockOffsets[mid][0];
      final end = _blockOffsets[mid][1];
      if (sourceOffset < start) {
        high = mid - 1;
      } else if (sourceOffset >= end) {
        low = mid + 1;
      } else {
        return mid;
      }
    }
    return -1;
  }

  Future<bool> scrollToSourceOffset(
    int sourceOffset, {
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    if (_lazyBlocks == null || _blockOffsets.isEmpty) {
      return false;
    }
    final blockIndex = _findBlockIndexForOffset(sourceOffset);
    if (blockIndex == -1 || blockIndex >= _blockKeys.length) return false;
    final key = _blockKeys[blockIndex];
    final context = key.currentContext;
    if (context == null) return false;
    await Scrollable.ensureVisible(
      context,
      duration: duration,
      curve: Curves.easeInOut,
      alignment: 0.1, // Show block near top
    );
    return true;
  }

  String _extractTextFromSpans(List<InlineSpan> spans) {
    final buffer = StringBuffer();
    void extract(InlineSpan span) {
      if (span is TextSpan) {
        if (span.text != null) buffer.write(span.text);
        if (span.children != null) {
          for (final child in span.children!) {
            extract(child);
          }
        }
      }
      // WidgetSpan is ignored for text extraction
    }

    for (final span in spans) {
      extract(span);
    }
    return buffer.toString();
  }

  LazyMarkdownBlocks? _lazyBlocks;
  String? _lastData;
  double? _lastFontSize;
  List<TextRange>? _lastHighlights;
  int? _lastHighlightIndex;
  ThemeData? _lastTheme;
  Set<int> _extraBlankLineIndices = {};

  bool _shouldRebuild(ThemeData theme) {
    return _lazyBlocks == null ||
        _lastData != widget.data ||
        _lastFontSize != widget.fontSize ||
        _lastHighlights != widget.searchHighlights ||
        _lastHighlightIndex != widget.currentHighlightIndex ||
        _lastTheme?.brightness != theme.brightness;
  }

  /// Detects extra blank lines between blocks and records the block indices after which they occur.
  void _detectExtraBlankLines(String source) {
    _extraBlankLineIndices = {};
    final lines = source.split('\n');
    List<int> blockStartLines = [];
    int lineCount = lines.length;
    // Find the start line of each block (paragraph/list/code block)
    // We'll use a simple heuristic: a non-blank line after a blank line is a new block
    for (int i = 0; i < lineCount; i++) {
      if (lines[i].trim().isEmpty) {
      } else {
        blockStartLines.add(i);
      }
    }
    // Now, for each block, check how many blank lines precede it
    int blockIdx = 0;
    int prevBlockLine = -1;
    for (final blockLine in blockStartLines) {
      if (prevBlockLine >= 0) {
        int blanks = 0;
        for (int i = prevBlockLine + 1; i < blockLine; i++) {
          if (i < lineCount && lines[i].trim().isEmpty) blanks++;
        }
        if (blanks > 1) {
          // Insert extra space after previous block
          _extraBlankLineIndices.add(blockIdx - 1);
        }
      }
      prevBlockLine = blockLine;
      blockIdx++;
    }
  }

  void _buildCache(BuildContext context) {
    final theme = Theme.of(context);

    if (!_shouldRebuild(theme)) {
      return;
    }

    _lastData = widget.data;
    _lastFontSize = widget.fontSize;
    _lastHighlights = widget.searchHighlights;
    _lastHighlightIndex = widget.currentHighlightIndex;
    _lastTheme = theme;

    final mdStyle = MarkdownStyle.fromTheme(theme, widget.fontSize);

    final builder = MarkdownSpanBuilder(
      style: mdStyle,
      onLinkTap: _handleLinkTap,
      onCheckboxTap: _handleCheckboxTap,
      searchHighlights: widget.searchHighlights,
      currentHighlightIndex: widget.currentHighlightIndex,
    );

    // Use lazy building - only parses AST upfront, builds spans on demand
    _lazyBlocks = builder.buildLazy(widget.data);
    _detectExtraBlankLines(widget.data);

    // Build block offset mapping using source positions for accurate search scroll
    _blockOffsets.clear();
    _blockKeys.clear();
    _buildSourceOffsets(widget.data);
  }

  /// Builds source-based block offsets by finding each block's text in the original source.
  /// This ensures search highlights (which use source offsets) map correctly to blocks.
  void _buildSourceOffsets(String source) {
    if (_lazyBlocks == null) return;

    // Split source into lines for block boundary detection
    final lines = source.split('\n');
    int lineOffset = 0;
    final lineOffsets = <int>[0]; // Start of each line in source
    for (final line in lines) {
      lineOffset += line.length + 1; // +1 for newline
      lineOffsets.add(lineOffset);
    }

    // For each block, estimate its source range
    // We use line-based mapping since markdown blocks correspond to source lines
    int currentLine = 0;

    for (int i = 0; i < _lazyBlocks!.length; i++) {
      final blockSpans = _lazyBlocks![i];
      final blockText = _extractTextFromSpans(blockSpans);

      // Skip empty blocks (nbsp placeholders)
      if (blockText.trim().isEmpty || blockText == '\u00A0') {
        // Blank line block - advance one line
        final start = currentLine < lineOffsets.length - 1
            ? lineOffsets[currentLine]
            : source.length;
        final end = start + 1;
        _blockOffsets.add([start, end]);
        _blockKeys.add(GlobalKey());
        currentLine++;
        continue;
      }

      // Find the first significant text in this block
      final firstText = _getFirstWord(blockText);
      if (firstText.isEmpty) {
        _blockOffsets.add([
          lineOffsets[currentLine],
          lineOffsets[currentLine] + 1,
        ]);
        _blockKeys.add(GlobalKey());
        currentLine++;
        continue;
      }

      // Search for this text in source starting from current line
      int blockStart = -1;
      for (int j = currentLine; j < lines.length && blockStart == -1; j++) {
        final idx = source.indexOf(firstText, lineOffsets[j]);
        if (idx != -1 &&
            idx <
                (j + 1 < lineOffsets.length
                    ? lineOffsets[j + 1]
                    : source.length)) {
          blockStart = lineOffsets[j];
          currentLine = j;
          break;
        }
      }

      if (blockStart == -1) {
        blockStart = currentLine < lineOffsets.length
            ? lineOffsets[currentLine]
            : source.length;
      }

      // Estimate block end by counting newlines in rendered text
      final newlineCount = '\n'.allMatches(blockText).length;
      final blockEndLine = (currentLine + newlineCount + 1).clamp(
        0,
        lines.length,
      );
      final blockEnd = blockEndLine < lineOffsets.length
          ? lineOffsets[blockEndLine]
          : source.length;

      _blockOffsets.add([blockStart, blockEnd]);
      _blockKeys.add(GlobalKey());
      currentLine = blockEndLine;
    }
  }

  /// Extracts the first word/token from text for matching purposes.
  String _getFirstWord(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    // Skip bullet points and list markers
    var start = 0;
    while (start < trimmed.length &&
        (trimmed[start] == '•' ||
            trimmed[start] == '-' ||
            trimmed[start] == '*' ||
            trimmed[start] == ' ' ||
            trimmed[start] == '\t' ||
            (trimmed[start].codeUnitAt(0) >= 0x30 &&
                trimmed[start].codeUnitAt(0) <= 0x39))) {
      start++;
      // Skip "1. " style markers
      if (start < trimmed.length && trimmed[start] == '.') {
        start++;
        while (start < trimmed.length && trimmed[start] == ' ') {
          start++;
        }
      }
    }

    // Get first word (up to 20 chars for efficiency)
    final end = trimmed.indexOf(' ', start);
    final wordEnd = end == -1 ? trimmed.length : end;
    final maxEnd = (start + 20).clamp(start, wordEnd);
    return trimmed.substring(start, maxEnd);
  }

  void _handleLinkTap(String url) {
    widget.onTapLink?.call(url);
  }

  void _handleCheckboxTap(int start, int end, bool isChecked) {
    if (widget.onCheckboxToggle == null) return;

    widget.onCheckboxToggle!(
      CheckboxToggleInfo(
        start: start,
        end: end,
        replacement: isChecked ? '[ ]' : '[x]',
      ),
    );
  }

  @override
  void dispose() {
    // Clear cache to free memory when widget is disposed
    _lazyBlocks?.clearCache();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _buildCache(context);

    final baseStyle = TextStyle(
      fontSize: widget.fontSize,
      height: MarkdownConstants.lineHeight,
    );

    final blockCount = _lazyBlocks?.length ?? 0;
    return ListView.builder(
      controller: widget.scrollController,
      padding: widget.padding ?? const EdgeInsets.all(AppSpacing.lg),
      itemCount: blockCount,
      itemBuilder: (context, index) {
        final blockSpans = _lazyBlocks![index];
        final children = <Widget>[];
        children.add(
          Text.rich(TextSpan(style: baseStyle, children: blockSpans)),
        );
        if (_extraBlankLineIndices.contains(index)) {
          children.add(SizedBox(height: widget.fontSize * 1.0));
        }
        return Column(
          key: _blockKeys.length > index ? _blockKeys[index] : null,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}
