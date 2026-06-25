import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../constants/markdown_constants.dart';
import 'ghost_text.dart';
import 'markdown_chunker.dart';
import 'markdown_line_height_calculator.dart';
import 'markdown_link_patterns.dart';
import 'markdown_list_syntax.dart';

typedef LinkTapCallback = void Function(String url);
typedef CheckboxTapCallback = void Function(int start, int end, bool isChecked);

/// Invoked when a ghost-text run is engaged in the preview. [start] and
/// [end] are absolute source offsets covering the whole `{{ … }}` run
/// (markers included) so the caller can delete it and navigate.
typedef GhostTapCallback = void Function(int start, int end);

/// Invoked when a `#tag` is tapped in the preview. [tag] is the full
/// matched token including the leading `#`, so the caller can search for
/// it verbatim across notes.
typedef TagTapCallback = void Function(String tag);

/// Trailing characters trimmed from bare autolinks (GFM-style) so a
/// sentence like `see https://example.com.` doesn't include the period.
const _trailingPunctuation = {
  '.',
  ',',
  ';',
  ':',
  '!',
  '?',
  ')',
  ']',
  '\'',
  '"',
};

/// Style configuration for line-based markdown rendering.
class LineMarkdownStyle {
  final double baseFontSize;
  final Color textColor;
  final Color primaryColor;
  final Color codeBackground;
  final Color blockquoteColor;
  final Color highlightColor;
  final Color currentHighlightColor;

  /// Colour for ghost-text placeholders (`{{ … }}`), rendered dimmed.
  final Color ghostColor;

  /// Background colour for `==highlighted==` ("marker"/highlighter) text.
  /// Distinct from [highlightColor] (search) so the two never read the
  /// same.
  final Color markColor;

  const LineMarkdownStyle({
    required this.baseFontSize,
    required this.textColor,
    required this.primaryColor,
    required this.codeBackground,
    required this.blockquoteColor,
    required this.highlightColor,
    required this.currentHighlightColor,
    required this.ghostColor,
    required this.markColor,
  });

  factory LineMarkdownStyle.fromTheme(ThemeData theme, double fontSize) {
    final isDark = theme.brightness == Brightness.dark;
    final base = theme.textTheme.bodyLarge?.color ?? Colors.black;
    return LineMarkdownStyle(
      baseFontSize: fontSize,
      textColor: base,
      primaryColor: theme.colorScheme.primary,
      codeBackground: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
      blockquoteColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
      highlightColor: theme.colorScheme.primaryContainer,
      currentHighlightColor: theme.colorScheme.primary.withValues(alpha: 0.5),
      ghostColor: base.withValues(alpha: 0.45),
      // Theme-matched highlighter amber that keeps the (light/dark) text
      // colour readable on top.
      markColor: isDark ? const Color(0xFF5A4B1C) : const Color(0xFFFFF176),
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
  final GhostTapCallback? onGhostTap;
  final TagTapCallback? onTagTap;
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

  /// Sparse, sorted, non-overlapping list of multi-line blocks (e.g.
  /// fenced code). Single-line content is represented implicitly (any
  /// line not covered by a span is its own one-line block), so this
  /// stays O(number of multi-line blocks) regardless of document size.
  ///
  /// Drives two things: (1) code-fence membership lookups (replacing
  /// the old per-chunk code-block state caches) and (2) block-aligned
  /// chunk boundaries so an atomic block is never bisected by a chunk.
  List<MarkdownBlock> _multiLineBlocks = const [];

  /// Start line (inclusive) of each chunk. Chunk `i` spans
  /// `[_chunkStartLines[i], _chunkStartLines[i + 1])` with the final
  /// chunk ending at [_lineCount]. Built once in [prepare] by walking
  /// blocks so boundaries land on block edges (atomic blocks are kept
  /// whole; splittable blocks like code fences may still be divided).
  List<int> _chunkStartLines = const [];

  LineBasedMarkdownBuilder({
    required this.style,
    this.onLinkTap,
    this.onCheckboxTap,
    this.onGhostTap,
    this.onTagTap,
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

    // Classify multi-line blocks (fenced code today) and compute
    // block-aligned chunk boundaries via the shared chunker so the
    // editor's debug overlay can reproduce identical boundaries.
    _buildChunkLayout();

    return _lines ?? [];
  }

  /// Delegates to [MarkdownChunker] to classify multi-line blocks and
  /// compute the block-aligned chunk table. [linesPerChunk] is already
  /// the adaptive size chosen by [MarkdownRenderService], so it is used
  /// directly as the chunk target here.
  void _buildChunkLayout() {
    final layout = MarkdownChunker.computeLayout(
      lineCount: _lineCount,
      chunkSize: linesPerChunk,
      lineAt: _getLine,
    );
    _multiLineBlocks = layout.blocks;
    _chunkStartLines = layout.chunkStartLines;
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

  /// Returns the multi-line block covering [lineIndex], or `null` when
  /// the line is plain single-line content. O(log n) binary search
  /// over the sparse [_multiLineBlocks] list.
  MarkdownBlock? _blockForLine(int lineIndex) {
    final blocks = _multiLineBlocks;
    if (blocks.isEmpty) return null;
    int low = 0;
    int high = blocks.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final b = blocks[mid];
      if (lineIndex < b.startLine) {
        high = mid - 1;
      } else if (lineIndex >= b.endLine) {
        low = mid + 1;
      } else {
        return b;
      }
    }
    return null;
  }

  /// Whether [lineIndex] is part of a fenced code block (including the
  /// opening and closing fence lines). Replaces the former per-chunk
  /// code-block state caches with a single block lookup.
  bool _lineInCodeFence(int lineIndex) {
    final block = _blockForLine(lineIndex);
    return block != null && block.kind == MarkdownBlockKind.codeFence;
  }

  /// The number of chunks. Driven by the block-aligned chunk table.
  int get chunkCount => _chunkStartLines.length;

  /// First source line (inclusive) of [chunkIndex].
  int chunkStartLine(int chunkIndex) {
    if (chunkIndex < 0 || chunkIndex >= _chunkStartLines.length) return 0;
    return _chunkStartLines[chunkIndex];
  }

  /// Number of source lines contained in [chunkIndex].
  int chunkLineCount(int chunkIndex) {
    if (chunkIndex < 0 || chunkIndex >= _chunkStartLines.length) return 0;
    final start = _chunkStartLines[chunkIndex];
    final end = chunkIndex + 1 < _chunkStartLines.length
        ? _chunkStartLines[chunkIndex + 1]
        : _lineCount;
    return end - start;
  }

  /// The chunk index that contains [lineIndex]. O(log n) binary search
  /// over [_chunkStartLines] — replaces the former
  /// `lineIndex ~/ linesPerChunk` assumption now that chunks are
  /// block-aligned and may hold variable line counts.
  int chunkIndexForLine(int lineIndex) {
    final starts = _chunkStartLines;
    if (starts.length <= 1) return 0;
    int low = 0;
    int high = starts.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lineIndex < starts[mid]) {
        high = mid - 1;
      } else if (mid + 1 < starts.length && lineIndex >= starts[mid + 1]) {
        low = mid + 1;
      } else {
        return mid;
      }
    }
    return (low).clamp(0, starts.length - 1);
  }

  /// Whether this is a large document with lazy optimizations
  bool get isLargeDocument => _lineCount >= _largeDocumentThreshold;

  /// Total line count
  int get lineCount => _lineCount;

  /// Get chunk index for a given source offset.
  /// Uses binary search for O(log n) performance.
  int getChunkIndexForOffset(int sourceOffset) {
    final lineIndex = getLineIndexForOffset(sourceOffset);
    return chunkIndexForLine(lineIndex);
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
    final startLine = chunkStartLine(chunkIndex);
    final endLine = startLine + chunkLineCount(chunkIndex);

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

    final startLine = chunkStartLine(chunkIndex);
    final endLine = startLine + chunkLineCount(chunkIndex);

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
    final startLine = chunkStartLine(chunkIndex);
    final endLine = startLine + chunkLineCount(chunkIndex);

    // Remove checkbox recognizers for this chunk's lines
    for (int i = startLine; i < endLine; i++) {
      final recognizer = _checkboxRecognizers.remove(i);
      recognizer?.dispose();
    }

    // Remove link/tag/ghost recognizers whose source offset falls inside
    // this chunk. For 'img:'/'tag:'/'ghost:' keys (and chunk-prefixed
    // ones) parts[1] is the numeric source offset used for the range test.
    _linkRecognizers.removeWhere((key, recognizer) {
      if (key.startsWith('$chunkIndex:') ||
          key.startsWith('img:') ||
          key.startsWith('tag:') ||
          key.startsWith('ghost:')) {
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

  /// Get the relative height scale for each line in a chunk.
  /// Returns a list of scales representing actual rendered height ratios.
  /// Normal text = 1.0, H1 = 2.0, empty lines = 0.5, etc.
  /// These are actual height ratios, not font size multipliers.
  /// Used for accurate double-tap line detection.
  List<double> getLineHeightScales(int chunkIndex) {
    final startLine = chunkStartLine(chunkIndex);
    final endLine = startLine + chunkLineCount(chunkIndex);
    final scales = <double>[];

    for (int i = startLine; i < endLine; i++) {
      if (i >= _lineCount) break;
      final line = _getLine(i);
      final isInCodeBlock = _lineInCodeFence(i);
      scales.add(
        MarkdownLineHeightCalculator.getLineHeightScale(
          line,
          isInsideCodeBlock: isInCodeBlock,
        ),
      );
    }

    return scales;
  }

  /// Build a TextSpan for a single line with inline markdown formatting.
  TextSpan buildLine(String line, int lineIndex, [int? chunkIndex]) {
    // [_lineOffsets] holds one start offset per line. The final line of a
    // document with no trailing newline is still a valid index here, so
    // the guard is `< length` (mirroring [lineEnd]'s `+ 1 < length`); an
    // earlier `< length - 1` dropped the last line's offset to 0, which
    // corrupted search-highlight and tap offsets on that line.
    final lineStart = lineIndex < _lineOffsets.length
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

    // Check if line is inside a fenced code block (block lookup).
    // The optional [chunkIndex] is retained for call-site compatibility
    // but no longer needed for fence detection.
    if (_lineInCodeFence(lineIndex)) {
      return _buildCodeBlockLine(line, trimmed, lineStart, lineEnd);
    }

    // Check for different markdown patterns
    if (trimmed.isEmpty) {
      // Empty line - render as minimal height spacer
      return TextSpan(
        text: ' ',
        style: baseStyle.copyWith(
          fontSize: style.baseFontSize * MarkdownConstants.emptyLineScale,
        ),
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

    // ATX heading: 1–6 leading '#' that must be followed by a space or
    // be the entire line. `#tag` (no space) and `#######` (7+) are NOT
    // headings — they fall through to paragraph rendering (CommonMark).
    if (trimmed.startsWith('#')) {
      int hashes = 0;
      while (hashes < trimmed.length && trimmed.codeUnitAt(hashes) == 0x23) {
        hashes++;
      }
      final followedBySpaceOrEol =
          hashes == trimmed.length || trimmed.codeUnitAt(hashes) == 0x20;
      if (hashes <= 6 && followedBySpaceOrEol) {
        final hasSpace = hashes < trimmed.length;
        final contentOffset = lineStart + indent + hashes + (hasSpace ? 1 : 0);
        return _buildHeading(
          trimmed.substring(hashes).trim(),
          hashes,
          contentOffset,
          lineEnd,
        );
      }
    }

    // List items (bullet / ordered / task) via the shared syntax so the
    // preview and the editor agree on exactly what is a list. Offsets are
    // line-relative, so add [lineStart] for absolute source positions.
    final listItem = MarkdownListSyntax.parse(line);
    if (listItem != null) {
      switch (listItem.kind) {
        case MarkdownListKind.task:
          return _buildCheckboxLine(
            listItem.content,
            listItem.checked,
            listItem.level,
            lineStart + listItem.bracketStart,
            lineStart + listItem.contentStart,
            lineEnd,
            lineIndex,
          );
        case MarkdownListKind.bullet:
          return _buildListItem(
            listItem.content,
            listItem.level,
            lineStart + listItem.contentStart,
            lineEnd,
          );
        case MarkdownListKind.ordered:
          return _buildOrderedListItem(
            listItem.content,
            listItem.marker,
            listItem.delimiter,
            listItem.level,
            lineStart + listItem.contentStart,
            lineEnd,
          );
      }
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
    int level,
    int bracketStart,
    int contentStart,
    int lineEnd,
    int lineIndex,
  ) {
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

    // The bracket span "[x]" / "[ ]" is always 3 source chars wide.
    final bracketEnd = bracketStart + 3;

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

    // WidgetSpan gives a hanging indent so wrapped lines align under the
    // content; nesting is a left padding proportional to [level].
    return TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: Padding(
            padding: EdgeInsets.only(left: _listIndent(level)),
            child: DefaultTextStyle(
              style: baseStyle,
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
          ),
        ),
      ],
    );
  }

  TextSpan _buildListItem(
    String text,
    int level,
    int contentStart,
    int lineEnd,
  ) {
    final bullet = _bulletForLevel(level);

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

    return TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: Padding(
            padding: EdgeInsets.only(left: _listIndent(level)),
            child: DefaultTextStyle(
              style: baseStyle,
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
          ),
        ),
      ],
    );
  }

  TextSpan _buildOrderedListItem(
    String text,
    String number,
    String delimiter,
    int level,
    int contentStart,
    int lineEnd,
  ) {
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

    return TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: Padding(
            padding: EdgeInsets.only(left: _listIndent(level)),
            child: DefaultTextStyle(
              style: baseStyle,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number$delimiter ',
                    style: baseStyle.copyWith(
                      color: style.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(child: Text.rich(contentSpan, style: baseStyle)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Visual left-indent (in logical pixels) for a list item at the given
  /// nesting [level]. One em per level keeps nesting readable at any font
  /// size; this is decorative only and never affects source offsets.
  double _listIndent(int level) => level * style.baseFontSize;

  /// The bullet glyph for an unordered item at [level], cycling
  /// `•` → `◦` → `▪` so nesting depth is visually distinguishable.
  String _bulletForLevel(int level) {
    switch (level % 3) {
      case 0:
        return '•';
      case 1:
        return '◦';
      default:
        return '▪';
    }
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
        fontSize: style.baseFontSize * MarkdownConstants.horizontalRuleScale,
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
      fontSize: style.baseFontSize * MarkdownConstants.codeBlockScale,
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
          color: style.textColor.withValues(
            alpha: MarkdownConstants.checkedTextOpacity,
          ),
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

  /// Build inline formatted text with bold, italic, code, links, and
  /// highlighting. [contentStart] is the source offset where [text]
  /// begins — critical so search highlighting lands on the right
  /// characters. Delegates to the recursive [_parseInline] scanner.
  ///
  /// [lineEnd] is retained for call-site compatibility and is unused.
  TextSpan _buildInlineFormatted(
    String text,
    TextStyle baseStyle,
    int contentStart,
    int lineEnd,
  ) {
    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }
    return _parseInline(text, baseStyle, contentStart);
  }

  /// Recursively parses inline markdown in [text] whose first character
  /// sits at source offset [contentStart]. Every leaf text run is routed
  /// through [_applyHighlighting] with its exact offset, so search
  /// highlighting stays aligned at any nesting depth.
  ///
  /// Improvements over the former single-pass regex:
  ///   * Nested emphasis (`**bold _italic_**`, `[**x**](url)`).
  ///   * Backslash escaping (`\*literal\*`).
  ///   * Intra-word underscores are not emphasis (`snake_case_word`).
  ///   * Inline code is literal (its content is never re-parsed).
  TextSpan _parseInline(String text, TextStyle baseStyle, int contentStart) {
    final children = <InlineSpan>[];
    final length = text.length;
    int i = 0;
    int runStart = 0;

    void flushRun(int end) {
      if (end > runStart) {
        children.add(
          _applyHighlighting(
            text.substring(runStart, end),
            baseStyle,
            contentStart + runStart,
          ),
        );
      }
    }

    while (i < length) {
      final c = text.codeUnitAt(i);

      // Backslash escape: emit the next punctuation char literally.
      if (c == _kBackslash &&
          i + 1 < length &&
          _isEscapablePunctuation(text.codeUnitAt(i + 1))) {
        flushRun(i);
        children.add(
          _applyHighlighting(
            text.substring(i + 1, i + 2),
            baseStyle,
            contentStart + i + 1,
          ),
        );
        i += 2;
        runStart = i;
        continue;
      }

      // Ghost text: {{ inner }} — dimmed placeholder, markers hidden.
      // Detected before other inline syntax so `{{` is never mistaken
      // for prose. Renders even without a tap handler (e.g. dialog
      // previews); the tap recognizer is attached only when engageable.
      if (c == _kOpenBrace) {
        final ghost = GhostText.matchAt(text, i);
        if (ghost != null) {
          flushRun(i);
          children.add(_buildGhostSpan(text, ghost, baseStyle, contentStart));
          i = ghost.end;
          runStart = i;
          continue;
        }
      }

      // Inline code span: `code` / ``co`de`` — literal, no nesting.
      if (c == _kBacktick) {
        final fence = _countRun(text, i, _kBacktick);
        final close = _findClosingBacktick(text, i + fence, fence);
        if (close != -1) {
          flushRun(i);
          final contentBegin = i + fence;
          children.add(
            _applyHighlighting(
              text.substring(contentBegin, close),
              baseStyle.copyWith(
                fontFamily: 'monospace',
                backgroundColor: style.codeBackground,
                fontSize: baseStyle.fontSize! * 0.9,
              ),
              contentStart + contentBegin,
            ),
          );
          i = close + fence;
          runStart = i;
          continue;
        }
      }

      // Link: [text](url) — link text is parsed recursively.
      if (c == _kOpenBracket) {
        final link = _tryParseLinkAt(text, i);
        if (link != null) {
          flushRun(i);
          final inner = _parseInline(
            text.substring(link.textStart, link.textEnd),
            baseStyle.copyWith(
              color: style.primaryColor,
              decoration: TextDecoration.underline,
            ),
            contentStart + link.textStart,
          );
          children.add(_wrapLinkSpan(inner, link.url, contentStart + i));
          i = link.end;
          runStart = i;
          continue;
        }
      }

      // Emphasis / strong / strikethrough / highlight (`*`, `_`, `~`, `==`).
      if (c == _kStar || c == _kUnderscore || c == _kTilde || c == _kEquals) {
        final emphasis = _tryParseEmphasisAt(text, i);
        if (emphasis != null) {
          flushRun(i);
          children.add(
            _parseInline(
              text.substring(emphasis.contentStart, emphasis.contentEnd),
              _applyEmphasisStyle(baseStyle, emphasis.kind),
              contentStart + emphasis.contentStart,
            ),
          );
          i = emphasis.end;
          runStart = i;
          continue;
        }
      }

      // Tag: #identifier (letter-led, at a word boundary) — tappable,
      // searches across notes. Letter-led so `#3` / `set #1` and `C#`
      // are never tags.
      if (c == _kHash && _isWordBoundaryBefore(text, i)) {
        final tagEnd = _tryParseTagAt(text, i);
        if (tagEnd != null) {
          flushRun(i);
          children.add(_buildTagSpan(text, i, tagEnd, baseStyle, contentStart));
          i = tagEnd;
          runStart = i;
          continue;
        }
      }

      // Bare autolink: http://… https://… www.…
      if ((c == _kLowerH || c == _kLowerW) && _isWordBoundaryBefore(text, i)) {
        final auto = _tryParseBareUrlAt(text, i);
        if (auto != null) {
          flushRun(i);
          final inner = _applyHighlighting(
            text.substring(i, auto.end),
            baseStyle.copyWith(
              color: style.primaryColor,
              decoration: TextDecoration.underline,
            ),
            contentStart + i,
          );
          children.add(_wrapLinkSpan(inner, auto.url, contentStart + i));
          i = auto.end;
          runStart = i;
          continue;
        }
      }

      i++;
    }

    flushRun(length);

    if (children.isEmpty) {
      return _applyHighlighting(text, baseStyle, contentStart);
    }
    return TextSpan(style: baseStyle, children: children);
  }

  /// Applies the style delta for an emphasis [kind] on top of [base],
  /// so nested emphasis composes (e.g. strikethrough + bold).
  TextStyle _applyEmphasisStyle(TextStyle base, _EmphasisKind kind) {
    switch (kind) {
      case _EmphasisKind.boldItalic:
        return base.copyWith(
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        );
      case _EmphasisKind.bold:
        return base.copyWith(fontWeight: FontWeight.bold);
      case _EmphasisKind.italic:
        return base.copyWith(fontStyle: FontStyle.italic);
      case _EmphasisKind.strikethrough:
        return base.copyWith(decoration: TextDecoration.lineThrough);
      case _EmphasisKind.highlight:
        return base.copyWith(backgroundColor: style.markColor);
    }
  }

  /// Wraps a parsed link [inner] span with a cached tap recognizer.
  /// The recognizer is attached to every leaf so taps register even
  /// when the link text was split by nesting or search highlighting.
  InlineSpan _wrapLinkSpan(TextSpan inner, String url, int sourceOffset) {
    if (onLinkTap == null) return inner;
    final cacheKey = '$sourceOffset:$url';
    final recognizer = _linkRecognizers[cacheKey] ??= TapGestureRecognizer()
      ..onTap = () => onLinkTap!(url);
    return _attachRecognizer(inner, recognizer);
  }

  /// Returns a copy of [span] with [recognizer] set on every [TextSpan]
  /// node so hit-testing resolves to it at any leaf.
  InlineSpan _attachRecognizer(
    InlineSpan span,
    TapGestureRecognizer recognizer,
  ) {
    if (span is TextSpan) {
      return TextSpan(
        text: span.text,
        style: span.style,
        recognizer: recognizer,
        children: span.children
            ?.map((s) => _attachRecognizer(s, recognizer))
            .toList(),
      );
    }
    return span;
  }

  /// Tries to parse a `[text](url)` link starting at the `[` at [open].
  /// Mirrors the previous regex (`[^\]]+` text, `[^)]+` url), so nested
  /// brackets/parens still terminate at the first match.
  _InlineLink? _tryParseLinkAt(String text, int open) {
    final closeBracket = text.indexOf(']', open + 1);
    if (closeBracket <= open + 1) return null; // empty or missing text
    if (closeBracket + 1 >= text.length ||
        text.codeUnitAt(closeBracket + 1) != _kOpenParen) {
      return null;
    }
    final closeParen = text.indexOf(')', closeBracket + 2);
    if (closeParen <= closeBracket + 2) return null; // empty or missing url
    return _InlineLink(
      textStart: open + 1,
      textEnd: closeBracket,
      url: text.substring(closeBracket + 2, closeParen),
      end: closeParen + 1,
    );
  }

  /// Tries to parse an emphasis run (`*`, `_`, `~`) opening at [i].
  /// Applies CommonMark-style flanking so underscores never match
  /// intra-word and a run must wrap non-space content.
  _InlineEmphasis? _tryParseEmphasisAt(String text, int i) {
    final marker = text.codeUnitAt(i);
    final runLen = _countRun(text, i, marker);

    final int use;
    final _EmphasisKind kind;
    if (marker == _kTilde) {
      if (runLen < 2) return null; // single ~ is literal
      use = 2;
      kind = _EmphasisKind.strikethrough;
    } else if (marker == _kEquals) {
      if (runLen < 2) return null; // single = is literal
      use = 2;
      kind = _EmphasisKind.highlight;
    } else if (runLen >= 3) {
      use = 3;
      kind = _EmphasisKind.boldItalic;
    } else if (runLen == 2) {
      use = 2;
      kind = _EmphasisKind.bold;
    } else {
      use = 1;
      kind = _EmphasisKind.italic;
    }

    if (!_canOpenEmphasis(text, i, marker, use)) return null;

    final contentStart = i + use;
    int j = contentStart;
    while (j < text.length) {
      if (text.codeUnitAt(j) == marker) {
        final closeRun = _countRun(text, j, marker);
        if (closeRun >= use &&
            j > contentStart &&
            _canCloseEmphasis(text, j, marker, use)) {
          return _InlineEmphasis(
            kind: kind,
            contentStart: contentStart,
            contentEnd: j,
            end: j + use,
          );
        }
        j += closeRun;
      } else {
        j++;
      }
    }
    return null; // no valid closing run
  }

  /// Whether an emphasis run of [use] [marker]s at [i] can open: it must
  /// be followed by a non-space char, and underscores must sit at a left
  /// word boundary (so `a_b_` stays literal).
  bool _canOpenEmphasis(String text, int i, int marker, int use) {
    final afterIdx = i + use;
    if (afterIdx >= text.length) return false;
    if (_isSpace(text.codeUnitAt(afterIdx))) return false;
    if (marker == _kUnderscore &&
        i > 0 &&
        _isAlphaNumeric(text.codeUnitAt(i - 1))) {
      return false;
    }
    return true;
  }

  /// Whether an emphasis run of [use] [marker]s at [j] can close: it must
  /// be preceded by a non-space char, and underscores must sit at a right
  /// word boundary.
  bool _canCloseEmphasis(String text, int j, int marker, int use) {
    if (j == 0) return false;
    if (_isSpace(text.codeUnitAt(j - 1))) return false;
    if (marker == _kUnderscore) {
      final afterIdx = j + use;
      if (afterIdx < text.length &&
          _isAlphaNumeric(text.codeUnitAt(afterIdx))) {
        return false;
      }
    }
    return true;
  }

  /// Tries to match a bare URL at [i], trimming GFM trailing punctuation.
  _InlineAutoLink? _tryParseBareUrlAt(String text, int i) {
    final match = MarkdownLinkPatterns.bareUrl.matchAsPrefix(text, i);
    if (match == null) return null;
    int end = match.end;
    while (end > i && _trailingPunctuation.contains(text[end - 1])) {
      end--;
    }
    if (end <= i) return null;
    final raw = text.substring(i, end);
    final href = raw.toLowerCase().startsWith('www.') ? 'https://$raw' : raw;
    return _InlineAutoLink(end: end, url: href);
  }

  /// Counts how many consecutive [marker] code units start at [i].
  static int _countRun(String text, int i, int marker) {
    int n = 0;
    while (i + n < text.length && text.codeUnitAt(i + n) == marker) {
      n++;
    }
    return n;
  }

  /// Finds a backtick run of exactly [fence] length at/after [from],
  /// returning its start index, or -1. CommonMark requires the closing
  /// run to match the opening length.
  static int _findClosingBacktick(String text, int from, int fence) {
    int j = from;
    while (j < text.length) {
      if (text.codeUnitAt(j) == _kBacktick) {
        final run = _countRun(text, j, _kBacktick);
        if (run == fence) return j;
        j += run;
      } else {
        j++;
      }
    }
    return -1;
  }

  /// Whether the character before [i] is a word boundary, so an inline
  /// token (`#tag`) or a bare autolink may start here. ASCII
  /// alphanumerics AND Unicode letters count as word characters, so a `#`
  /// glued to an accented word (`café#x`) is not a tag — matching the
  /// Unicode-aware tag body in [_isTagChar].
  bool _isWordBoundaryBefore(String text, int i) {
    if (i == 0) return true;
    final prev = text.codeUnitAt(i - 1);
    return !_isAlphaNumeric(prev) && !_isLetter(prev);
  }

  static bool _isSpace(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

  static bool _isAlphaNumeric(int c) =>
      (c >= 0x30 && c <= 0x39) || // 0-9
      (c >= 0x41 && c <= 0x5A) || // A-Z
      (c >= 0x61 && c <= 0x7A); // a-z

  /// Matches a single Unicode letter (any script). Used so `#tag` accepts
  /// accented / non-Latin letters — de: ä ö ü ß, ro: ă â î ș ț, etc. — not
  /// just ASCII a–z. ASCII is fast-pathed in [_isLetter]; this regex only
  /// runs for non-ASCII code units, and a lone surrogate simply yields no
  /// match (BMP letters cover every supported language).
  static final RegExp _unicodeLetterRe = RegExp(r'\p{L}', unicode: true);

  static bool _isLetter(int c) =>
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A) ||
      (c > 0x7F && _unicodeLetterRe.hasMatch(String.fromCharCode(c)));

  /// Matches one Unicode "tag-body" code unit: a letter (`L`), combining
  /// mark (`M`), or number (`N`) of any script. Beyond [_unicodeLetterRe]
  /// this also keeps NFD-decomposed accents (base letter + combining mark,
  /// e.g. `a` + U+0301) and non-ASCII digits inside a tag. ASCII is
  /// fast-pathed in [_isTagChar]; this only runs for non-ASCII code units.
  static final RegExp _unicodeTagBodyRe = RegExp(
    r'[\p{L}\p{M}\p{N}]',
    unicode: true,
  );

  /// Characters allowed in a `#tag` body (after the letter-led start):
  /// ASCII letters/digits, `_`, `-`, and any Unicode letter / combining
  /// mark / number (so accented, NFD, and non-Latin tags stay intact).
  static bool _isTagChar(int c) =>
      _isAlphaNumeric(c) ||
      c == 0x5F /* _ */ ||
      c == 0x2D /* - */ ||
      (c > 0x7F && _unicodeTagBodyRe.hasMatch(String.fromCharCode(c)));

  /// Returns the end index (exclusive) of a `#tag` starting at the `#`
  /// at [i], or `null` when it is not a tag. The first body character
  /// must be a letter so `#3` / `set #1` are never tags.
  int? _tryParseTagAt(String text, int i) {
    final firstIdx = i + 1;
    if (firstIdx >= text.length) return null;
    if (!_isLetter(text.codeUnitAt(firstIdx))) return null;
    int j = firstIdx + 1;
    while (j < text.length && _isTagChar(text.codeUnitAt(j))) {
      j++;
    }
    return j;
  }

  /// ASCII-punctuation test for backslash escaping (CommonMark allows
  /// escaping any ASCII punctuation).
  static bool _isEscapablePunctuation(int c) =>
      (c >= 0x21 && c <= 0x2F) ||
      (c >= 0x3A && c <= 0x40) ||
      (c >= 0x5B && c <= 0x60) ||
      (c >= 0x7B && c <= 0x7E);

  // Inline-scanner code-unit constants.
  static const int _kBackslash = 0x5C; // \
  static const int _kBacktick = 0x60; // `
  static const int _kStar = 0x2A; // *
  static const int _kUnderscore = 0x5F; // _
  static const int _kTilde = 0x7E; // ~
  static const int _kEquals = 0x3D; // =
  static const int _kHash = 0x23; // #
  static const int _kOpenBracket = 0x5B; // [
  static const int _kOpenParen = 0x28; // (
  static const int _kOpenBrace = 0x7B; // {
  static const int _kLowerH = 0x68; // h
  static const int _kLowerW = 0x77; // w

  /// Builds the span for a `#tag`, tinted and (when [onTagTap] is set)
  /// tappable. The tag text — including the leading `#` — stays a normal
  /// offset-mapped text run so search highlighting still applies inside
  /// it; the recognizer is attached to every leaf.
  InlineSpan _buildTagSpan(
    String text,
    int start,
    int end,
    TextStyle baseStyle,
    int contentStart,
  ) {
    final tagText = text.substring(start, end);
    final tagStyle = baseStyle.copyWith(
      color: style.primaryColor,
      fontWeight: FontWeight.w600,
      backgroundColor: style.primaryColor.withValues(alpha: 0.12),
    );
    final span = _applyHighlighting(tagText, tagStyle, contentStart + start);
    if (onTagTap == null) return span;
    final cacheKey = 'tag:${contentStart + start}:$tagText';
    final recognizer = _linkRecognizers[cacheKey] ??= TapGestureRecognizer()
      ..onTap = () => onTagTap!(tagText);
    return _attachRecognizer(span, recognizer);
  }

  /// Builds the dimmed span for a ghost run. The `{{` / `}}` markers are
  /// hidden; only the inner text renders, tinted with [style.ghostColor]
  /// on top of [baseStyle] so it inherits the surrounding context
  /// (heading size, list style, etc.). Search highlighting still applies
  /// to the inner text via its true source offset. When [onGhostTap] is
  /// set, a cached tap recognizer is attached to every leaf so a tap
  /// anywhere on the placeholder engages it.
  InlineSpan _buildGhostSpan(
    String text,
    GhostMatch ghost,
    TextStyle baseStyle,
    int contentStart,
  ) {
    final inner = text.substring(ghost.innerStart, ghost.innerEnd);
    final ghostStyle = baseStyle.copyWith(color: style.ghostColor);
    final span = _applyHighlighting(
      inner,
      ghostStyle,
      contentStart + ghost.innerStart,
    );
    if (onGhostTap == null) return span;
    final absStart = contentStart + ghost.start;
    final absEnd = contentStart + ghost.end;
    final cacheKey = 'ghost:$absStart:$absEnd';
    final recognizer = _linkRecognizers[cacheKey] ??= TapGestureRecognizer()
      ..onTap = () => onGhostTap!(absStart, absEnd);
    return _attachRecognizer(span, recognizer);
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

/// Inline emphasis variants produced by the recursive inline parser.
enum _EmphasisKind { boldItalic, bold, italic, strikethrough, highlight }

/// A parsed `[text](url)` link with source offsets for the link text.
class _InlineLink {
  final int textStart;
  final int textEnd;
  final String url;
  final int end;

  const _InlineLink({
    required this.textStart,
    required this.textEnd,
    required this.url,
    required this.end,
  });
}

/// A parsed emphasis run: [contentStart, contentEnd) is the inner text,
/// [end] is the index just past the closing delimiter.
class _InlineEmphasis {
  final _EmphasisKind kind;
  final int contentStart;
  final int contentEnd;
  final int end;

  const _InlineEmphasis({
    required this.kind,
    required this.contentStart,
    required this.contentEnd,
    required this.end,
  });
}

/// A parsed bare autolink: [end] is the index just past the URL and
/// [url] is the launch target (scheme-normalized for `www.` links).
class _InlineAutoLink {
  final int end;
  final String url;

  const _InlineAutoLink({required this.end, required this.url});
}

/// Pre-compiled regex patterns for inline markdown (compiled once, reused)
class _MarkdownPatterns {
  static final horizontalRule = RegExp(r'^[-*_]{3,}\s*$');

  /// Image pattern: ![alt text](url)
  static final image = RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)$');

  /// Table row pattern: | cell | cell | or |cell|cell|
  static final tableRow = RegExp(r'^\|.*\|$');

  /// Table separator pattern: |---|---| or | --- | --- |
  static final tableSeparator = RegExp(r'^\|[\s:-]+\|[\s:|+-]*$');
}
