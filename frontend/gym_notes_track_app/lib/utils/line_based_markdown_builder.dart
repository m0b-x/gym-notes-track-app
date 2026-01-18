import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../constants/markdown_constants.dart';

typedef LinkTapCallback = void Function(String url);
typedef CheckboxTapCallback = void Function(int start, int end, bool isChecked);

/// Style configuration for line-based markdown rendering.
class LineMarkdownStyle {
  final double baseFontSize;
  final Color textColor;
  final Color primaryColor;
  final Color codeBackground;
  final Color blockquoteColor;
  final Color highlightColor;
  final Color currentHighlightColor;

  const LineMarkdownStyle({
    required this.baseFontSize,
    required this.textColor,
    required this.primaryColor,
    required this.codeBackground,
    required this.blockquoteColor,
    required this.highlightColor,
    required this.currentHighlightColor,
  });

  factory LineMarkdownStyle.fromTheme(ThemeData theme, double fontSize) {
    final isDark = theme.brightness == Brightness.dark;
    return LineMarkdownStyle(
      baseFontSize: fontSize,
      textColor: theme.textTheme.bodyLarge?.color ?? Colors.black,
      primaryColor: theme.colorScheme.primary,
      codeBackground: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
      blockquoteColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
      highlightColor: theme.colorScheme.primaryContainer,
      currentHighlightColor: theme.colorScheme.primary.withValues(alpha: 0.5),
    );
  }
}

/// Renders markdown line-by-line for precise scroll positioning.
/// Lines are grouped into chunks for better performance with large documents.
///
/// Performance optimizations for large documents (100k+ lines):
/// - LRU cache limits memory usage for chunk spans
/// - Lazy code block detection (computed per-chunk, not upfront)
/// - Adaptive chunk sizing based on document size
/// - Line offsets computed once, lines split lazily
class LineBasedMarkdownBuilder {
  final LineMarkdownStyle style;
  final LinkTapCallback? onLinkTap;
  final CheckboxTapCallback? onCheckboxTap;
  final List<TextRange>? searchHighlights;
  final int? currentHighlightIndex;

  /// Number of lines per chunk - configurable for balance between precision and performance
  final int linesPerChunk;

  /// Maximum number of chunks to keep in cache (LRU eviction)
  static const int _maxCachedChunks = 50;

  /// Threshold for "large document" optimizations
  static const int _largeDocumentThreshold = 10000;

  // Precomputed line offsets for fast lookup
  List<int> _lineOffsets = [];
  String _source = '';

  /// Lazily populated lines - only extracted when needed
  List<String>? _lines;
  int _lineCount = 0;

  /// LRU cache for built chunk spans (chunkIndex -> spans)
  /// Uses a simple LRU by tracking access order
  final Map<int, List<InlineSpan>> _chunkCache = {};
  final List<int> _cacheAccessOrder = [];

  /// Cache for gesture recognizers to prevent memory leaks
  final Map<String, TapGestureRecognizer> _linkRecognizers = {};
  final Map<int, TapGestureRecognizer> _checkboxRecognizers = {};

  /// Lazy code block state - computed per chunk on demand
  /// Key: chunk index, Value: map of lineIndex -> isInsideCodeBlock
  final Map<int, Map<int, bool>> _codeBlockStateCache = {};

  /// Track code block state at chunk boundaries for continuity
  /// Key: chunk index, Value: whether code block is open at START of chunk
  final Map<int, bool> _chunkStartsInCodeBlock = {};

  LineBasedMarkdownBuilder({
    required this.style,
    this.onLinkTap,
    this.onCheckboxTap,
    this.searchHighlights,
    this.currentHighlightIndex,
    this.linesPerChunk = 10,
  });

  /// Precompute line offsets for the source text.
  /// For large documents, lines are extracted lazily to reduce memory pressure.
  /// Returns list of lines for rendering.
  List<String> prepare(String source) {
    _source = source;
    clearCache(); // Also disposes recognizers and clears code block cache

    // Compute line offsets in a single pass without splitting
    // This is O(n) but doesn't allocate 100k string objects
    _lineOffsets = [0];
    _lineCount = 0;

    for (int i = 0; i < source.length; i++) {
      if (source.codeUnitAt(i) == 10) {
        // '\n'
        _lineOffsets.add(i + 1);
        _lineCount++;
      }
    }
    // Account for last line if no trailing newline
    if (source.isEmpty || source.codeUnitAt(source.length - 1) != 10) {
      _lineCount++;
    }

    // For small documents, pre-split lines (faster access)
    // For large documents, extract lazily to save memory
    if (_lineCount < _largeDocumentThreshold) {
      _lines = source.split('\n');
    } else {
      _lines = null; // Will extract on demand
    }

    return _lines ?? [];
  }

  /// Get a specific line by index (lazy extraction for large docs)
  String _getLine(int lineIndex) {
    if (_lines != null) {
      return lineIndex < _lines!.length ? _lines![lineIndex] : '';
    }

    // Lazy extraction from source
    if (lineIndex < 0 || lineIndex >= _lineCount) return '';

    final start = _lineOffsets[lineIndex];
    final end = lineIndex + 1 < _lineOffsets.length
        ? _lineOffsets[lineIndex + 1] -
              1 // -1 to exclude newline
        : _source.length;

    if (start >= _source.length) return '';
    return _source.substring(start, end.clamp(start, _source.length));
  }

  /// Check if a line is inside a code block (lazy computation)
  bool _isLineInCodeBlock(int lineIndex, int chunkIndex) {
    // Check chunk cache first
    final chunkState = _codeBlockStateCache[chunkIndex];
    if (chunkState != null && chunkState.containsKey(lineIndex)) {
      return chunkState[lineIndex]!;
    }

    // Need to compute code block state for this chunk
    _computeCodeBlockStateForChunk(chunkIndex);
    return _codeBlockStateCache[chunkIndex]?[lineIndex] ?? false;
  }

  /// Compute code block state for a specific chunk
  void _computeCodeBlockStateForChunk(int chunkIndex) {
    if (_codeBlockStateCache.containsKey(chunkIndex)) return;

    // Determine starting state by scanning previous chunks if needed
    bool inCodeBlock = _getCodeBlockStateAtChunkStart(chunkIndex);

    final startLine = chunkIndex * linesPerChunk;
    final endLine = ((chunkIndex + 1) * linesPerChunk).clamp(0, _lineCount);

    final chunkState = <int, bool>{};

    for (int i = startLine; i < endLine; i++) {
      final line = _getLine(i);
      final trimmed = line.trimLeft();

      if (trimmed.startsWith('```')) {
        if (inCodeBlock) {
          chunkState[i] = true; // Closing fence is inside
          inCodeBlock = false;
        } else {
          chunkState[i] = true; // Opening fence starts block
          inCodeBlock = true;
        }
      } else {
        chunkState[i] = inCodeBlock;
      }
    }

    _codeBlockStateCache[chunkIndex] = chunkState;
    // Store state at end for next chunk
    _chunkStartsInCodeBlock[chunkIndex + 1] = inCodeBlock;
  }

  /// Get whether a code block is open at the start of a chunk
  bool _getCodeBlockStateAtChunkStart(int chunkIndex) {
    if (chunkIndex == 0) return false;

    // Check if we have cached state
    if (_chunkStartsInCodeBlock.containsKey(chunkIndex)) {
      return _chunkStartsInCodeBlock[chunkIndex]!;
    }

    // Need to compute previous chunks to know state
    // This will recursively compute back to chunk 0 if needed
    _computeCodeBlockStateForChunk(chunkIndex - 1);
    return _chunkStartsInCodeBlock[chunkIndex] ?? false;
  }

  /// Get the number of chunks
  int get chunkCount => (_lineCount / linesPerChunk).ceil();

  /// Whether this is a large document with lazy optimizations
  bool get isLargeDocument => _lineCount >= _largeDocumentThreshold;

  /// Total line count
  int get lineCount => _lineCount;

  /// Get chunk index for a given source offset.
  /// Uses binary search for O(log n) performance.
  int getChunkIndexForOffset(int sourceOffset) {
    final lineIndex = getLineIndexForOffset(sourceOffset);
    return lineIndex ~/ linesPerChunk;
  }

  /// Get line index for a given source offset.
  int getLineIndexForOffset(int sourceOffset) {
    if (_lineOffsets.isEmpty) return 0;

    int low = 0;
    int high = _lineOffsets.length - 2;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final lineStart = _lineOffsets[mid];
      final lineEnd = _lineOffsets[mid + 1];

      if (sourceOffset < lineStart) {
        high = mid - 1;
      } else if (sourceOffset >= lineEnd) {
        low = mid + 1;
      } else {
        return mid;
      }
    }

    return low.clamp(0, _lineOffsets.length - 2);
  }

  /// Get the source offset range for a given line index.
  List<int> getLineOffsetRange(int lineIndex) {
    if (lineIndex < 0 || lineIndex >= _lineOffsets.length - 1) {
      return [0, 0];
    }
    return [_lineOffsets[lineIndex], _lineOffsets[lineIndex + 1]];
  }

  /// Get the source offset range for a given chunk index.
  List<int> getChunkOffsetRange(int chunkIndex) {
    final startLine = chunkIndex * linesPerChunk;
    final endLine = ((chunkIndex + 1) * linesPerChunk).clamp(0, _lineCount);

    if (startLine >= _lineOffsets.length - 1) return [0, 0];

    final startOffset = _lineOffsets[startLine];
    final endOffset = endLine < _lineOffsets.length
        ? _lineOffsets[endLine]
        : _lineOffsets.last;

    return [startOffset, endOffset];
  }

  /// Build spans for a chunk of lines (cached with LRU eviction).
  List<InlineSpan> buildChunk(int chunkIndex) {
    // Check cache first and update LRU order
    if (_chunkCache.containsKey(chunkIndex)) {
      _updateCacheAccess(chunkIndex);
      return _chunkCache[chunkIndex]!;
    }

    final startLine = chunkIndex * linesPerChunk;
    final endLine = ((chunkIndex + 1) * linesPerChunk).clamp(0, _lineCount);

    final spans = <InlineSpan>[];

    for (int i = startLine; i < endLine; i++) {
      if (i >= _lineCount) break;

      final line = _getLine(i);
      final lineSpan = buildLine(line, i, chunkIndex);
      spans.add(lineSpan);

      // Add newline between lines (except after last line in chunk)
      if (i < endLine - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    // Cache with LRU eviction
    _addToCache(chunkIndex, spans);
    return spans;
  }

  /// Add chunk to cache with LRU eviction
  void _addToCache(int chunkIndex, List<InlineSpan> spans) {
    // Evict oldest if at capacity
    while (_cacheAccessOrder.length >= _maxCachedChunks) {
      final oldestChunk = _cacheAccessOrder.removeAt(0);
      _chunkCache.remove(oldestChunk);
      // Also clean up related recognizers for this chunk
      _cleanupChunkRecognizers(oldestChunk);
    }

    _chunkCache[chunkIndex] = spans;
    _cacheAccessOrder.add(chunkIndex);
  }

  /// Update LRU access order
  void _updateCacheAccess(int chunkIndex) {
    _cacheAccessOrder.remove(chunkIndex);
    _cacheAccessOrder.add(chunkIndex);
  }

  /// Clean up recognizers for a specific chunk
  void _cleanupChunkRecognizers(int chunkIndex) {
    final startLine = chunkIndex * linesPerChunk;
    final endLine = ((chunkIndex + 1) * linesPerChunk).clamp(0, _lineCount);

    // Remove checkbox recognizers for this chunk's lines
    for (int i = startLine; i < endLine; i++) {
      final recognizer = _checkboxRecognizers.remove(i);
      recognizer?.dispose();
    }

    // Remove link recognizers for this chunk (they have chunk-based keys)
    _linkRecognizers.removeWhere((key, recognizer) {
      if (key.startsWith('$chunkIndex:') || key.startsWith('img:')) {
        // Check if the offset falls within this chunk
        final parts = key.split(':');
        if (parts.length >= 2) {
          final offset = int.tryParse(parts[1]);
          if (offset != null) {
            final chunkStart = _lineOffsets[startLine];
            final chunkEnd = endLine < _lineOffsets.length
                ? _lineOffsets[endLine]
                : _source.length;
            if (offset >= chunkStart && offset < chunkEnd) {
              recognizer.dispose();
              return true;
            }
          }
        }
      }
      return false;
    });
  }

  /// Clear the span cache and dispose gesture recognizers
  void clearCache() {
    _chunkCache.clear();
    _cacheAccessOrder.clear();
    _codeBlockStateCache.clear();
    _chunkStartsInCodeBlock.clear();
    // Dispose all gesture recognizers to prevent memory leaks
    for (final recognizer in _linkRecognizers.values) {
      recognizer.dispose();
    }
    _linkRecognizers.clear();
    for (final recognizer in _checkboxRecognizers.values) {
      recognizer.dispose();
    }
    _checkboxRecognizers.clear();
  }

  /// Dispose all resources - call when builder is no longer needed
  void dispose() {
    clearCache();
  }

  /// Build a TextSpan for a single line with inline markdown formatting.
  TextSpan buildLine(String line, int lineIndex, [int? chunkIndex]) {
    final lineStart = lineIndex < _lineOffsets.length - 1
        ? _lineOffsets[lineIndex]
        : 0;
    final lineEnd = lineIndex + 1 < _lineOffsets.length
        ? _lineOffsets[lineIndex + 1] -
              1 // -1 to exclude newline
        : _source.length;

    final baseStyle = TextStyle(
      fontSize: style.baseFontSize,
      height: MarkdownConstants.lineHeight,
      color: style.textColor,
    );

    // Detect line type and apply appropriate styling
    final trimmed = line.trimLeft();
    final indent = line.length - trimmed.length;

    // Check if line is inside a code block (lazy computation)
    final effectiveChunkIndex = chunkIndex ?? (lineIndex ~/ linesPerChunk);
    if (_isLineInCodeBlock(lineIndex, effectiveChunkIndex)) {
      return _buildCodeBlockLine(line, trimmed, lineStart, lineEnd);
    }

    // Check for different markdown patterns
    if (trimmed.isEmpty) {
      // Empty line - render as minimal height spacer
      return TextSpan(
        text: ' ',
        style: baseStyle.copyWith(fontSize: style.baseFontSize * 0.5),
      );
    }

    // Image detection (before links since they have similar syntax)
    final imageMatch = _MarkdownPatterns.image.firstMatch(trimmed);
    if (imageMatch != null) {
      return _buildImage(
        imageMatch.group(1) ?? '',
        imageMatch.group(2) ?? '',
        lineStart,
        lineEnd,
      );
    }

    // Table row detection
    if (_MarkdownPatterns.tableRow.hasMatch(trimmed)) {
      return _buildTableRow(trimmed, lineStart, lineEnd);
    }

    // Heading detection - calculate content offset accounting for # and space
    if (trimmed.startsWith('######')) {
      final contentOffset =
          lineStart +
          indent +
          6 +
          (trimmed.length > 6 && trimmed[6] == ' ' ? 1 : 0);
      return _buildHeading(
        trimmed.substring(6).trim(),
        6,
        contentOffset,
        lineEnd,
      );
    } else if (trimmed.startsWith('#####')) {
      final contentOffset =
          lineStart +
          indent +
          5 +
          (trimmed.length > 5 && trimmed[5] == ' ' ? 1 : 0);
      return _buildHeading(
        trimmed.substring(5).trim(),
        5,
        contentOffset,
        lineEnd,
      );
    } else if (trimmed.startsWith('####')) {
      final contentOffset =
          lineStart +
          indent +
          4 +
          (trimmed.length > 4 && trimmed[4] == ' ' ? 1 : 0);
      return _buildHeading(
        trimmed.substring(4).trim(),
        4,
        contentOffset,
        lineEnd,
      );
    } else if (trimmed.startsWith('###')) {
      final contentOffset =
          lineStart +
          indent +
          3 +
          (trimmed.length > 3 && trimmed[3] == ' ' ? 1 : 0);
      return _buildHeading(
        trimmed.substring(3).trim(),
        3,
        contentOffset,
        lineEnd,
      );
    } else if (trimmed.startsWith('##')) {
      final contentOffset =
          lineStart +
          indent +
          2 +
          (trimmed.length > 2 && trimmed[2] == ' ' ? 1 : 0);
      return _buildHeading(
        trimmed.substring(2).trim(),
        2,
        contentOffset,
        lineEnd,
      );
    } else if (trimmed.startsWith('#')) {
      final contentOffset =
          lineStart +
          indent +
          1 +
          (trimmed.length > 1 && trimmed[1] == ' ' ? 1 : 0);
      return _buildHeading(
        trimmed.substring(1).trim(),
        1,
        contentOffset,
        lineEnd,
      );
    }

    // Checkbox list item
    final checkboxMatch = _MarkdownPatterns.checkbox.firstMatch(line);
    if (checkboxMatch != null) {
      // Content offset: indent + "- [x] " = indent + 6
      final contentOffset = lineStart + indent + 6;
      return _buildCheckboxLine(
        checkboxMatch.group(3) ?? '',
        checkboxMatch.group(2)?.toLowerCase() == 'x',
        indent,
        lineStart,
        contentOffset,
        lineEnd,
        lineIndex,
      );
    }

    // Unordered list item
    if (trimmed.startsWith('- ') ||
        trimmed.startsWith('* ') ||
        trimmed.startsWith('+ ')) {
      final contentOffset = lineStart + indent + 2; // prefix is 2 chars: "- "
      return _buildListItem(
        trimmed.substring(2),
        indent,
        contentOffset,
        lineEnd,
        false,
      );
    }

    // Ordered list item
    final orderedMatch = _MarkdownPatterns.orderedList.firstMatch(trimmed);
    if (orderedMatch != null) {
      final number = orderedMatch.group(1) ?? '1';
      final contentOffset =
          lineStart + indent + number.length + 2; // "N. " where N is the number
      return _buildOrderedListItem(
        orderedMatch.group(2) ?? '',
        number,
        indent,
        contentOffset,
        lineEnd,
      );
    }

    // Blockquote
    if (trimmed.startsWith('>')) {
      // Calculate content offset: skip indent + '>' + optional space
      final afterArrow = trimmed.substring(1);
      final spaceAfter = afterArrow.startsWith(' ') ? 1 : 0;
      final contentOffset = lineStart + indent + 1 + spaceAfter;
      return _buildBlockquote(afterArrow.trim(), contentOffset, lineEnd);
    }

    // Horizontal rule
    if (_MarkdownPatterns.horizontalRule.hasMatch(trimmed)) {
      return _buildHorizontalRule();
    }

    // Code block marker (```)
    if (trimmed.startsWith('```')) {
      return TextSpan(
        text: line,
        style: baseStyle.copyWith(
          fontFamily: 'monospace',
          color: style.textColor.withValues(alpha: 0.6),
        ),
      );
    }

    // Regular paragraph - apply inline formatting
    return _buildInlineFormatted(line, baseStyle, lineStart, lineEnd);
  }

  TextSpan _buildHeading(
    String text,
    int level,
    int contentStart,
    int lineEnd,
  ) {
    final scale = switch (level) {
      1 => MarkdownConstants.h1Scale,
      2 => MarkdownConstants.h2Scale,
      3 => MarkdownConstants.h3Scale,
      4 => MarkdownConstants.h4Scale,
      5 => MarkdownConstants.h5Scale,
      _ => MarkdownConstants.h6Scale,
    };

    final headingStyle = TextStyle(
      fontSize: style.baseFontSize * scale,
      fontWeight: FontWeight.bold,
      height: MarkdownConstants.lineHeight,
      color: style.textColor,
    );

    return _buildInlineFormatted(text, headingStyle, contentStart, lineEnd);
  }

  TextSpan _buildCheckboxLine(
    String text,
    bool isChecked,
    int indent,
    int lineStart,
    int contentStart,
    int lineEnd,
    int lineIndex,
  ) {
    final indentStr = '  ' * (indent ~/ 2);
    final checkboxChar = isChecked ? '☒' : '☐';

    final baseStyle = TextStyle(
      fontSize: style.baseFontSize,
      height: MarkdownConstants.lineHeight,
      color: style.textColor,
    );

    final contentStyle = isChecked
        ? baseStyle.copyWith(
            color: style.textColor.withValues(alpha: 0.5),
            decoration: TextDecoration.lineThrough,
          )
        : baseStyle;

    // Find checkbox bracket position in source
    final bracketStart =
        lineStart + indent + 2; // "- [" = 3 chars, but index starts at 2
    final bracketEnd = bracketStart + 3; // "[x]" or "[ ]"

    // Cache checkbox recognizer by line index to prevent memory leaks
    TapGestureRecognizer? checkboxRecognizer;
    if (onCheckboxTap != null) {
      _checkboxRecognizers[lineIndex] ??= TapGestureRecognizer()
        ..onTap = () => onCheckboxTap!(bracketStart, bracketEnd, isChecked);
      checkboxRecognizer = _checkboxRecognizers[lineIndex];
    }

    // Add formatted content - use contentStart for correct highlighting
    final contentSpan = _buildInlineFormatted(
      text,
      contentStyle,
      contentStart,
      lineEnd,
    );

    // Use WidgetSpan to create hanging indent for wrapped lines
    return TextSpan(
      children: [
        if (indentStr.isNotEmpty) TextSpan(text: indentStr, style: baseStyle),
        WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: checkboxRecognizer?.onTap,
                child: Text(
                  '$checkboxChar ',
                  style: baseStyle.copyWith(
                    color: isChecked
                        ? style.primaryColor
                        : style.textColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Expanded(child: Text.rich(contentSpan, style: contentStyle)),
            ],
          ),
        ),
      ],
    );
  }

  TextSpan _buildListItem(
    String text,
    int indent,
    int contentStart,
    int lineEnd,
    bool ordered,
  ) {
    final indentStr = '  ' * (indent ~/ 2);
    final bullet = (indent ~/ 2) == 0 ? '•' : ((indent ~/ 2) == 1 ? '◦' : '▪');

    final baseStyle = TextStyle(
      fontSize: style.baseFontSize,
      height: MarkdownConstants.lineHeight,
      color: style.textColor,
    );

    final contentSpan = _buildInlineFormatted(
      text,
      baseStyle,
      contentStart,
      lineEnd,
    );

    // Use WidgetSpan to create hanging indent for wrapped lines
    return TextSpan(
      children: [
        if (indentStr.isNotEmpty) TextSpan(text: indentStr, style: baseStyle),
        WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$bullet ',
                style: baseStyle.copyWith(
                  color: style.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(child: Text.rich(contentSpan, style: baseStyle)),
            ],
          ),
        ),
      ],
    );
  }

  TextSpan _buildOrderedListItem(
    String text,
    String number,
    int indent,
    int contentStart,
    int lineEnd,
  ) {
    final indentStr = '  ' * (indent ~/ 2);

    final baseStyle = TextStyle(
      fontSize: style.baseFontSize,
      height: MarkdownConstants.lineHeight,
      color: style.textColor,
    );

    final contentSpan = _buildInlineFormatted(
      text,
      baseStyle,
      contentStart,
      lineEnd,
    );

    // Use WidgetSpan to create hanging indent for wrapped lines
    return TextSpan(
      children: [
        if (indentStr.isNotEmpty) TextSpan(text: indentStr, style: baseStyle),
        WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$number. ',
                style: baseStyle.copyWith(
                  color: style.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(child: Text.rich(contentSpan, style: baseStyle)),
            ],
          ),
        ),
      ],
    );
  }

  TextSpan _buildBlockquote(String text, int contentStart, int lineEnd) {
    final quoteStyle = TextStyle(
      fontSize: style.baseFontSize,
      height: MarkdownConstants.lineHeight,
      fontStyle: FontStyle.italic,
      color: style.textColor.withValues(alpha: 0.8),
    );

    final children = <InlineSpan>[
      TextSpan(
        text: '┃ ',
        style: quoteStyle.copyWith(
          color: style.blockquoteColor,
          fontStyle: FontStyle.normal,
        ),
      ),
    ];

    final contentSpan = _buildInlineFormatted(
      text,
      quoteStyle,
      contentStart,
      lineEnd,
    );
    if (contentSpan.children != null) {
      children.addAll(contentSpan.children!);
    } else if (contentSpan.text != null) {
      children.add(contentSpan);
    }

    return TextSpan(children: children);
  }

  TextSpan _buildHorizontalRule() {
    return TextSpan(
      text: '─' * 40,
      style: TextStyle(
        fontSize: style.baseFontSize * 0.5,
        color: style.textColor.withValues(alpha: 0.3),
        letterSpacing: 2,
      ),
    );
  }

  /// Build a code block line (content inside ``` fences)
  TextSpan _buildCodeBlockLine(
    String line,
    String trimmed,
    int lineStart,
    int lineEnd,
  ) {
    final codeStyle = TextStyle(
      fontSize: style.baseFontSize * 0.9,
      height: MarkdownConstants.lineHeight,
      fontFamily: 'monospace',
      color: style.textColor,
      backgroundColor: style.codeBackground,
    );

    // If this is a fence line (``` with optional language), style it differently
    if (trimmed.startsWith('```')) {
      final language = trimmed.length > 3 ? trimmed.substring(3).trim() : '';
      return TextSpan(
        text: language.isNotEmpty ? '// $language' : '',
        style: codeStyle.copyWith(
          color: style.textColor.withValues(alpha: 0.5),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Regular code content - apply highlighting for search
    return _applyHighlighting(line, codeStyle, lineStart);
  }

  /// Build an image placeholder (since TextSpan can't render actual images)
  /// Format: ![alt text](url)
  TextSpan _buildImage(String altText, String url, int lineStart, int lineEnd) {
    final imageStyle = TextStyle(
      fontSize: style.baseFontSize,
      height: MarkdownConstants.lineHeight,
      color: style.primaryColor,
      fontStyle: FontStyle.italic,
    );

    // Alt text starts at lineStart + 2 (after "![")
    final altTextOffset = lineStart + 2;
    final displayText = altText.isNotEmpty ? altText : 'Image';

    // Apply highlighting to alt text
    final highlightedAltText = _applyHighlighting(
      displayText,
      imageStyle.copyWith(decoration: TextDecoration.underline),
      altText.isNotEmpty
          ? altTextOffset
          : lineStart, // Use actual offset only if we have real alt text
    );

    // Wrap with tap recognizer if we have a link tap callback
    final children = <InlineSpan>[
      TextSpan(
        text: '🖼 ',
        style: imageStyle.copyWith(fontStyle: FontStyle.normal),
      ),
    ];

    if (onLinkTap != null) {
      // We need to wrap the highlighted text span with a recognizer
      // Create a new span that includes the recognizer
      _linkRecognizers['img:$lineStart:$url'] ??= TapGestureRecognizer()
        ..onTap = () => onLinkTap!(url);

      if (highlightedAltText.children != null &&
          highlightedAltText.children!.isNotEmpty) {
        // Has highlighting - need to add recognizer to each child
        for (final child in highlightedAltText.children!) {
          if (child is TextSpan) {
            children.add(
              TextSpan(
                text: child.text,
                style:
                    child.style ??
                    imageStyle.copyWith(decoration: TextDecoration.underline),
                recognizer: _linkRecognizers['img:$lineStart:$url'],
                children: child.children,
              ),
            );
          } else {
            children.add(child);
          }
        }
      } else {
        // No highlighting, simple text
        children.add(
          TextSpan(
            text: highlightedAltText.text ?? displayText,
            style: imageStyle.copyWith(decoration: TextDecoration.underline),
            recognizer: _linkRecognizers['img:$lineStart:$url'],
          ),
        );
      }
    } else {
      // No tap callback, just add the highlighted text
      if (highlightedAltText.children != null) {
        children.addAll(highlightedAltText.children!.cast<InlineSpan>());
      } else {
        children.add(highlightedAltText);
      }
    }

    return TextSpan(children: children);
  }

  /// Build a table row with proper cell offset tracking for search highlighting
  TextSpan _buildTableRow(String line, int lineStart, int lineEnd) {
    final baseStyle = TextStyle(
      fontSize: style.baseFontSize,
      height: MarkdownConstants.lineHeight,
      color: style.textColor,
    );

    // Check if this is a separator row (|---|---|)
    if (_MarkdownPatterns.tableSeparator.hasMatch(line)) {
      return TextSpan(
        text: '─' * 30,
        style: baseStyle.copyWith(
          color: style.textColor.withValues(alpha: 0.3),
          letterSpacing: 1,
        ),
      );
    }

    // Parse table cells while tracking their positions in the source
    final children = <InlineSpan>[];
    bool isFirst = true;

    // Split by | but track positions
    int searchStart = 0;
    while (searchStart < line.length) {
      // Find next |
      int pipePos = line.indexOf('|', searchStart);
      if (pipePos == -1) {
        // No more pipes, handle remaining content
        if (searchStart < line.length) {
          final remaining = line.substring(searchStart).trim();
          if (remaining.isNotEmpty) {
            if (!isFirst) {
              children.add(
                TextSpan(
                  text: ' │ ',
                  style: baseStyle.copyWith(
                    color: style.textColor.withValues(alpha: 0.4),
                  ),
                ),
              );
            }
            children.add(
              _buildInlineFormatted(
                remaining,
                baseStyle,
                lineStart +
                    searchStart +
                    (line.substring(searchStart).length -
                        line.substring(searchStart).trimLeft().length),
                lineEnd,
              ),
            );
          }
        }
        break;
      }

      // Content before this pipe
      if (pipePos > searchStart) {
        final cellContent = line.substring(searchStart, pipePos).trim();
        if (cellContent.isNotEmpty) {
          if (!isFirst) {
            children.add(
              TextSpan(
                text: ' │ ',
                style: baseStyle.copyWith(
                  color: style.textColor.withValues(alpha: 0.4),
                ),
              ),
            );
          }
          // Calculate where the trimmed content actually starts
          final rawContent = line.substring(searchStart, pipePos);
          final leadingSpaces =
              rawContent.length - rawContent.trimLeft().length;
          final cellOffset = lineStart + searchStart + leadingSpaces;

          children.add(
            _buildInlineFormatted(cellContent, baseStyle, cellOffset, lineEnd),
          );
          isFirst = false;
        }
      }

      searchStart = pipePos + 1;
    }

    if (children.isEmpty) {
      return TextSpan(text: line, style: baseStyle);
    }

    return TextSpan(style: baseStyle, children: children);
  }

  /// Build inline formatted text with bold, italic, code, links, and highlighting.
  ///
  /// The contentStart parameter is the source offset where 'text' begins.
  /// This is critical for correct search highlighting - the offset must match
  /// the actual position in the source document.
  TextSpan _buildInlineFormatted(
    String text,
    TextStyle baseStyle,
    int contentStart,
    int lineEnd,
  ) {
    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    final children = <InlineSpan>[];
    int pos = 0;

    // Use pre-compiled regex for inline markdown
    final matches = _MarkdownPatterns.inline.allMatches(text).toList();

    for (final match in matches) {
      // Add text before this match
      if (match.start > pos) {
        final beforeText = text.substring(pos, match.start);
        children.add(
          _applyHighlighting(beforeText, baseStyle, contentStart + pos),
        );
      }

      // Determine match type and apply styling
      // For each type, we need to calculate where the actual content starts
      // accounting for the markdown delimiters
      if (match.group(1) != null) {
        // Bold + Italic: ***content*** or ___content___
        final delimiter = match.group(1)!; // *** or ___
        final content = match.group(2)!;
        final contentOffset = contentStart + match.start + delimiter.length;
        children.add(
          _applyHighlighting(
            content,
            baseStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
            contentOffset,
          ),
        );
      } else if (match.group(3) != null) {
        // Bold: **content** or __content__
        final delimiter = match.group(3)!; // ** or __
        final content = match.group(4)!;
        final contentOffset = contentStart + match.start + delimiter.length;
        children.add(
          _applyHighlighting(
            content,
            baseStyle.copyWith(fontWeight: FontWeight.bold),
            contentOffset,
          ),
        );
      } else if (match.group(5) != null) {
        // Italic: *content* or _content_
        final delimiter = match.group(5)!; // * or _
        final content = match.group(6)!;
        final contentOffset = contentStart + match.start + delimiter.length;
        children.add(
          _applyHighlighting(
            content,
            baseStyle.copyWith(fontStyle: FontStyle.italic),
            contentOffset,
          ),
        );
      } else if (match.group(7) != null) {
        // Strikethrough: ~~content~~
        final delimiter = match.group(7)!; // ~~
        final content = match.group(8)!;
        final contentOffset = contentStart + match.start + delimiter.length;
        children.add(
          _applyHighlighting(
            content,
            baseStyle.copyWith(decoration: TextDecoration.lineThrough),
            contentOffset,
          ),
        );
      } else if (match.group(9) != null) {
        // Inline code: `content`
        final delimiter = match.group(9)!; // `
        final content = match.group(10)!;
        final contentOffset = contentStart + match.start + delimiter.length;
        children.add(
          _applyHighlighting(
            content,
            baseStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor: style.codeBackground,
              fontSize: baseStyle.fontSize! * 0.9,
            ),
            contentOffset,
          ),
        );
      } else if (match.group(11) != null) {
        // Link: [text](url)
        final linkText = match.group(11)!;
        final url = match.group(12)!;
        // Link text starts after '[', so +1
        final linkTextOffset = contentStart + match.start + 1;
        children.add(_buildLink(linkText, url, baseStyle, linkTextOffset));
      }

      pos = match.end;
    }

    // Add remaining text after last match
    if (pos < text.length) {
      final afterText = text.substring(pos);
      children.add(
        _applyHighlighting(afterText, baseStyle, contentStart + pos),
      );
    }

    if (children.isEmpty) {
      return _applyHighlighting(text, baseStyle, contentStart);
    }

    return TextSpan(style: baseStyle, children: children);
  }

  TextSpan _buildLink(
    String text,
    String url,
    TextStyle baseStyle,
    int sourceOffset,
  ) {
    final linkStyle = baseStyle.copyWith(
      color: style.primaryColor,
      decoration: TextDecoration.underline,
    );

    // Apply highlighting to link text
    final highlightedSpan = _applyHighlighting(text, linkStyle, sourceOffset);

    if (onLinkTap != null) {
      // Cache recognizer by URL to prevent memory leaks
      final cacheKey = '$sourceOffset:$url';
      _linkRecognizers[cacheKey] ??= TapGestureRecognizer()
        ..onTap = () => onLinkTap!(url);

      // If highlighting produced children, wrap them; otherwise use text directly
      if (highlightedSpan.children != null &&
          highlightedSpan.children!.isNotEmpty) {
        return TextSpan(
          style: linkStyle,
          children: highlightedSpan.children,
          recognizer: _linkRecognizers[cacheKey],
        );
      }

      return TextSpan(
        text: text,
        style: linkStyle,
        recognizer: _linkRecognizers[cacheKey],
      );
    }

    return highlightedSpan;
  }

  /// Apply search highlighting to text.
  TextSpan _applyHighlighting(
    String text,
    TextStyle baseStyle,
    int sourceOffset,
  ) {
    if (searchHighlights == null || searchHighlights!.isEmpty || text.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final sourceEnd = sourceOffset + text.length;

    // Find overlapping highlights
    final overlapping = <_HighlightRange>[];
    for (int i = 0; i < searchHighlights!.length; i++) {
      final h = searchHighlights![i];
      if (h.start < sourceEnd && h.end > sourceOffset) {
        final relStart = (h.start - sourceOffset).clamp(0, text.length);
        final relEnd = (h.end - sourceOffset).clamp(0, text.length);
        overlapping.add(
          _HighlightRange(
            start: relStart,
            end: relEnd,
            isCurrent: i == currentHighlightIndex,
          ),
        );
      }
    }

    if (overlapping.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    overlapping.sort((a, b) => a.start.compareTo(b.start));

    final children = <TextSpan>[];
    int pos = 0;

    for (final range in overlapping) {
      if (range.start > pos) {
        children.add(TextSpan(text: text.substring(pos, range.start)));
      }

      final bgColor = range.isCurrent
          ? style.currentHighlightColor
          : style.highlightColor;
      children.add(
        TextSpan(
          text: text.substring(range.start, range.end),
          style: TextStyle(backgroundColor: bgColor),
        ),
      );

      pos = range.end;
    }

    if (pos < text.length) {
      children.add(TextSpan(text: text.substring(pos)));
    }

    return TextSpan(style: baseStyle, children: children);
  }
}

class _HighlightRange {
  final int start;
  final int end;
  final bool isCurrent;

  _HighlightRange({
    required this.start,
    required this.end,
    required this.isCurrent,
  });
}

/// Pre-compiled regex patterns for inline markdown (compiled once, reused)
class _MarkdownPatterns {
  static final checkbox = RegExp(r'^(\s*)-\s*\[([xX\s])\]\s*(.*)$');
  static final orderedList = RegExp(r'^(\d+)\.\s+(.*)$');
  static final horizontalRule = RegExp(r'^[-*_]{3,}\s*$');

  /// Image pattern: ![alt text](url)
  static final image = RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)$');

  /// Table row pattern: | cell | cell | or |cell|cell|
  static final tableRow = RegExp(r'^\|.*\|$');

  /// Table separator pattern: |---|---| or | --- | --- |
  static final tableSeparator = RegExp(r'^\|[\s:-]+\|[\s:|+-]*$');

  static final inline = RegExp(
    r'(\*\*\*|___)(.*?)\1|' // Bold+Italic
    r'(\*\*|__)(.*?)\3|' // Bold
    r'(\*|_)(.*?)\5|' // Italic
    r'(~~)(.*?)\7|' // Strikethrough
    r'(`)(.*?)\9|' // Inline code
    r'\[([^\]]+)\]\(([^)]+)\)', // Links
  );
}
