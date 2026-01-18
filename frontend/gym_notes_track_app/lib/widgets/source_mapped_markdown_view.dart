import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../constants/app_spacing.dart';
import '../constants/markdown_constants.dart';
import '../utils/line_based_markdown_builder.dart';
import 'full_markdown_view.dart';

typedef LinkTapCallback = void Function(String url);

/// Line-based markdown view for precise scroll positioning.
/// Lines are grouped into small chunks for better performance
/// while maintaining accurate search scroll positioning.
class SourceMappedMarkdownView extends StatefulWidget {
  final String data;
  final double fontSize;
  final Function(CheckboxToggleInfo)? onCheckboxToggle;
  final ScrollController?
  scrollController; // Kept for API compatibility but not used internally
  final EdgeInsets? padding;
  final List<TextRange>? searchHighlights;
  final int? currentHighlightIndex;
  final LinkTapCallback? onTapLink;

  /// Callback to receive scroll progress updates (0.0 to 1.0)
  final ValueChanged<double>? onScrollProgress;

  /// Lines per chunk for preview performance (higher = better performance, lower = more precise scroll)
  final int linesPerChunk;

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
    this.onScrollProgress,
    this.linesPerChunk = 10,
  });

  @override
  State<SourceMappedMarkdownView> createState() =>
      SourceMappedMarkdownViewState();

  /// Helper to access state for imperative actions (e.g., scroll to highlight)
  static SourceMappedMarkdownViewState? of(BuildContext context) {
    return context.findAncestorStateOfType<SourceMappedMarkdownViewState>();
  }
}

class SourceMappedMarkdownViewState extends State<SourceMappedMarkdownView> {
  /// Controller for jumping to specific chunk indices
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  /// Line-based markdown builder (with chunking)
  LineBasedMarkdownBuilder? _builder;

  /// Cache invalidation tracking
  String? _lastData;
  double? _lastFontSize;
  List<TextRange>? _lastHighlights;
  int? _lastHighlightIndex;
  ThemeData? _lastTheme;
  int? _lastLinesPerChunk;

  /// Debounce timer for rapid data changes
  Timer? _rebuildDebounce;

  /// Pre-warm cache tracking
  int _lastFirstVisibleChunk = -1;
  int _lastScrollDirection = 0; // -1 = up, 0 = none, 1 = down

  /// Get the item positions listener for external scroll tracking
  ItemPositionsListener get itemPositionsListener => _itemPositionsListener;

  /// Get current scroll progress (0.0 to 1.0)
  /// Uses itemLeadingEdge for smooth sub-chunk precision
  double get scrollProgress {
    if (_builder == null || _builder!.chunkCount == 0) return 0.0;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return 0.0;

    final chunkCount = _builder!.chunkCount;

    // Find the first and last visible items
    final sortedPositions = positions.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final firstVisible = sortedPositions.first;
    final lastVisible = sortedPositions.last;

    // Check if we're at the end (last chunk is visible and its trailing edge is at or past viewport bottom)
    if (lastVisible.index == chunkCount - 1 &&
        lastVisible.itemTrailingEdge <= 1.0) {
      // At the end - calculate how close to fully scrolled
      // When trailing edge is 1.0, we're exactly at the bottom
      // When trailing edge is less, we've scrolled past
      return 1.0;
    }

    // Check if we're at the start
    if (firstVisible.index == 0 && firstVisible.itemLeadingEdge >= 0.0) {
      return 0.0;
    }

    // Calculate smooth progress using both index and leading edge
    // itemLeadingEdge: 0.0 = item at top of viewport, negative = item extends above viewport

    // Base progress from chunk index
    final baseProgress = firstVisible.index / chunkCount;

    // Add sub-chunk offset based on how much of the item is scrolled past
    // When leadingEdge is negative, we've scrolled into this chunk
    final scrolledPastAmount = -firstVisible.itemLeadingEdge;
    final subChunkProgress = scrolledPastAmount.clamp(0.0, 1.0) / chunkCount;

    return (baseProgress + subChunkProgress).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    // Listen to scroll position changes and notify parent
    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
  }

  @override
  void dispose() {
    _rebuildDebounce?.cancel();
    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    // Dispose the builder to clean up gesture recognizers
    _builder?.dispose();
    super.dispose();
  }

  void _onPositionsChanged() {
    widget.onScrollProgress?.call(scrollProgress);

    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty || _builder == null) return;

    final firstVisible = positions.reduce((a, b) => a.index < b.index ? a : b);

    // Detect scroll direction and pre-warm adjacent chunks
    if (_lastFirstVisibleChunk >= 0) {
      final newDirection = firstVisible.index > _lastFirstVisibleChunk
          ? 1
          : (firstVisible.index < _lastFirstVisibleChunk ? -1 : 0);
      if (newDirection != 0) {
        _lastScrollDirection = newDirection;
        _preWarmAdjacentChunks(firstVisible.index);
      }
    }
    _lastFirstVisibleChunk = firstVisible.index;

    // Also update the external scroll controller if provided (for compatibility)
    if (widget.scrollController != null && _builder!.chunkCount > 0) {
      // Approximate the scroll offset based on chunk position
      final approximateOffset =
          firstVisible.index *
          widget.linesPerChunk *
          widget.fontSize *
          MarkdownConstants.lineHeight;
      // Only notify if controller is attached
      if (widget.scrollController!.hasClients) {
        widget.scrollController!.jumpTo(
          approximateOffset.clamp(
            0.0,
            widget.scrollController!.position.maxScrollExtent,
          ),
        );
      }
    }
  }

  /// Pre-warm cache for chunks in the scroll direction
  void _preWarmAdjacentChunks(int currentChunk) {
    if (_builder == null) return;
    final chunkCount = _builder!.chunkCount;

    // Pre-warm 2 chunks ahead in scroll direction
    if (_lastScrollDirection > 0) {
      // Scrolling down - pre-warm next chunks
      for (int i = 1; i <= 2; i++) {
        final nextChunk = currentChunk + i;
        if (nextChunk < chunkCount) {
          _builder!.buildChunk(nextChunk);
        }
      }
    } else if (_lastScrollDirection < 0) {
      // Scrolling up - pre-warm previous chunks
      for (int i = 1; i <= 2; i++) {
        final prevChunk = currentChunk - i;
        if (prevChunk >= 0) {
          _builder!.buildChunk(prevChunk);
        }
      }
    }
  }

  /// Scrolls to the chunk containing the given source offset.
  /// Returns true if scroll was successful.
  Future<bool> scrollToSourceOffset(
    int sourceOffset, {
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    if (_builder == null || _builder!.chunkCount == 0) {
      return false;
    }

    final chunkIndex = _builder!.getChunkIndexForOffset(sourceOffset);
    if (chunkIndex < 0 || chunkIndex >= _builder!.chunkCount) {
      return false;
    }

    // Calculate alignment within the chunk for better positioning
    final chunkRange = _builder!.getChunkOffsetRange(chunkIndex);
    final chunkStart = chunkRange[0];
    final chunkEnd = chunkRange[1];
    final chunkLength = chunkEnd - chunkStart;

    // Position the chunk in the upper portion of the viewport
    double alignment = 0.2;
    if (chunkLength > 0) {
      final relativePos = (sourceOffset - chunkStart) / chunkLength;
      alignment = (relativePos * 0.3).clamp(0.1, 0.4);
    }

    _itemScrollController.scrollTo(
      index: chunkIndex,
      duration: duration,
      curve: Curves.easeInOut,
      alignment: alignment,
    );

    return true;
  }

  /// Scrolls to show a specific line index.
  /// Used for syncing scroll position between editor and preview.
  Future<bool> scrollToLineIndex(
    int lineIndex,
    int totalLines, {
    Duration duration = const Duration(milliseconds: 300),
    bool animate = true,
  }) async {
    if (_builder == null || _builder!.chunkCount == 0 || totalLines <= 0) {
      return false;
    }

    // Calculate chunk index from line index
    final chunkIndex = lineIndex ~/ _builder!.linesPerChunk;
    if (chunkIndex < 0 || chunkIndex >= _builder!.chunkCount) {
      return false;
    }

    // Calculate alignment - position within chunk
    final lineInChunk = lineIndex % _builder!.linesPerChunk;
    final alignment = (lineInChunk / _builder!.linesPerChunk * 0.3).clamp(
      0.1,
      0.4,
    );

    if (animate) {
      _itemScrollController.scrollTo(
        index: chunkIndex,
        duration: duration,
        curve: Curves.easeInOut,
        alignment: alignment,
      );
    } else {
      _itemScrollController.jumpTo(index: chunkIndex, alignment: alignment);
    }

    return true;
  }

  /// Get the current visible line index (approximate)
  int get currentLineIndex {
    if (_builder == null) return 0;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return 0;

    final firstVisible = positions.reduce((a, b) => a.index < b.index ? a : b);
    return firstVisible.index * _builder!.linesPerChunk;
  }

  bool _shouldRebuild(ThemeData theme) {
    return _builder == null ||
        _lastData != widget.data ||
        _lastFontSize != widget.fontSize ||
        !_highlightsEqual(_lastHighlights, widget.searchHighlights) ||
        _lastHighlightIndex != widget.currentHighlightIndex ||
        _lastTheme?.brightness != theme.brightness ||
        _lastLinesPerChunk != widget.linesPerChunk;
  }

  /// Deep equality check for highlights list
  bool _highlightsEqual(List<TextRange>? a, List<TextRange>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].start != b[i].start || a[i].end != b[i].end) return false;
    }
    return true;
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
    _lastLinesPerChunk = widget.linesPerChunk;

    final mdStyle = LineMarkdownStyle.fromTheme(theme, widget.fontSize);

    // Use adaptive chunk size for very large documents
    // This reduces total chunk count which improves list performance
    final lineCount = '\\n'.allMatches(widget.data).length + 1;
    final adaptiveChunkSize = _computeAdaptiveChunkSize(
      lineCount,
      widget.linesPerChunk,
    );

    _builder = LineBasedMarkdownBuilder(
      style: mdStyle,
      onLinkTap: _handleLinkTap,
      onCheckboxTap: _handleCheckboxTap,
      searchHighlights: widget.searchHighlights,
      currentHighlightIndex: widget.currentHighlightIndex,
      linesPerChunk: adaptiveChunkSize,
    );

    // Parse source into lines and compute offsets
    _builder!.prepare(widget.data);
  }

  /// Compute adaptive chunk size based on document size
  /// Larger documents use larger chunks to reduce total item count
  int _computeAdaptiveChunkSize(int lineCount, int baseChunkSize) {
    if (lineCount < 1000) {
      return baseChunkSize; // Small docs: use configured size
    } else if (lineCount < 10000) {
      return baseChunkSize * 2; // Medium docs: 2x chunk size
    } else if (lineCount < 50000) {
      return baseChunkSize * 5; // Large docs: 5x chunk size (50 lines/chunk)
    } else {
      return baseChunkSize * 10; // Huge docs: 10x chunk size (100 lines/chunk)
    }
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
  Widget build(BuildContext context) {
    _buildCache(context);

    final baseStyle = TextStyle(
      fontSize: widget.fontSize,
      height: MarkdownConstants.lineHeight,
    );

    final chunkCount = _builder?.chunkCount ?? 0;

    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      padding: widget.padding ?? const EdgeInsets.all(AppSpacing.lg),
      itemCount: chunkCount,
      itemBuilder: (context, chunkIndex) {
        if (_builder == null || chunkIndex >= chunkCount) {
          return const SizedBox.shrink();
        }

        // Build chunk spans (cached internally)
        final chunkSpans = _builder!.buildChunk(chunkIndex);

        // RepaintBoundary isolates repaints to this chunk only
        return RepaintBoundary(
          child: Text.rich(TextSpan(style: baseStyle, children: chunkSpans)),
        );
      },
    );
  }
}
