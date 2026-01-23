import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../constants/app_spacing.dart';
import '../constants/markdown_constants.dart';
import '../models/dev_options.dart';
import '../utils/line_based_markdown_builder.dart';
import 'double_tap_line_detector.dart';
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

  /// Callback when user double-taps to navigate to source line
  final DoubleTapLineCallback? onDoubleTapLine;

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
    this.onDoubleTapLine,
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
  bool? _lastDebugEnabled;

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

    // Special case: only one chunk or all content fits in viewport
    if (chunkCount == 1) {
      // For single chunk, use the leading edge as progress indicator
      if (firstVisible.itemLeadingEdge >= 0 &&
          firstVisible.itemTrailingEdge <= 1.0) {
        return 0.0; // Content fits entirely in viewport
      }
      if (firstVisible.itemLeadingEdge >= 0) return 0.0;
      if (firstVisible.itemTrailingEdge <= 1.0) return 1.0;
      // Content is larger than viewport, calculate based on position
      final totalHeight =
          firstVisible.itemTrailingEdge - firstVisible.itemLeadingEdge;
      final scrolledAmount = -firstVisible.itemLeadingEdge;
      return (scrolledAmount / (totalHeight - 1.0)).clamp(0.0, 1.0);
    }

    // Check if at the very start
    if (firstVisible.index == 0 && firstVisible.itemLeadingEdge >= 0.0) {
      return 0.0;
    }

    // Check if at the very end
    if (lastVisible.index == chunkCount - 1 &&
        lastVisible.itemTrailingEdge <= 1.0) {
      return 1.0;
    }

    // Find the item at the top of the viewport (partially scrolled past)
    final topItem = sortedPositions.firstWhere(
      (p) => p.itemLeadingEdge <= 0 && p.itemTrailingEdge > 0,
      orElse: () => firstVisible,
    );

    // Calculate how much of the top item has been scrolled past
    double scrolledPastRatio = 0.0;
    if (topItem.itemLeadingEdge < 0) {
      final itemHeight = topItem.itemTrailingEdge - topItem.itemLeadingEdge;
      if (itemHeight > 0) {
        scrolledPastRatio = (-topItem.itemLeadingEdge / itemHeight).clamp(
          0.0,
          1.0,
        );
      }
    }

    // Calculate progress with an adjusted denominator
    // The maximum scrollable position is when the last chunk's trailing edge = 1.0
    // So the range is [0, chunkCount - viewportChunks] but we approximate
    // by using a reduced denominator to account for viewport height

    // Estimate how many chunks fit in viewport
    final visibleChunkCount = sortedPositions.length;

    // Effective scroll range: we can't scroll past when last chunk hits bottom
    // So the denominator should be (chunkCount - visibleChunkCount + 1)
    final effectiveRange = (chunkCount - visibleChunkCount + 1).clamp(
      1,
      chunkCount,
    );

    // Progress = how far through the effective range
    final progress = (topItem.index + scrolledPastRatio) / effectiveRange;

    return progress.clamp(0.0, 1.0);
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

  /// Get the total number of chunks
  int get chunkCount => _builder?.chunkCount ?? 0;

  /// Scroll to a specific progress value (0.0 to 1.0)
  /// Used by interactive scrollbars
  void scrollToProgress(double progress, {bool animate = false}) {
    if (_builder == null || _builder!.chunkCount == 0) return;

    final clampedProgress = progress.clamp(0.0, 1.0);
    final chunkCount = _builder!.chunkCount;

    // Handle edge cases
    if (clampedProgress <= 0.0) {
      _itemScrollController.jumpTo(index: 0, alignment: 0.0);
      return;
    }
    if (clampedProgress >= 1.0) {
      // Scroll to the last chunk with alignment that puts it at the bottom
      _itemScrollController.jumpTo(index: chunkCount - 1, alignment: 0.0);
      return;
    }

    // Estimate visible chunks - we'll use positions if available, else estimate
    final positions = _itemPositionsListener.itemPositions.value;
    int visibleChunkCount = 3; // Default estimate
    if (positions.isNotEmpty) {
      visibleChunkCount = positions.length;
    }

    // Use the same effective range calculation as scrollProgress
    final effectiveRange = (chunkCount - visibleChunkCount + 1).clamp(
      1,
      chunkCount,
    );

    // Calculate target chunk and alignment
    final targetPosition = clampedProgress * effectiveRange;
    final targetChunk = targetPosition.floor().clamp(0, chunkCount - 1);
    final alignment = (targetPosition - targetChunk).clamp(0.0, 0.8);

    if (animate) {
      _itemScrollController.scrollTo(
        index: targetChunk,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: alignment,
      );
    } else {
      _itemScrollController.jumpTo(index: targetChunk, alignment: alignment);
    }
  }

  bool _shouldRebuild(ThemeData theme) {
    final devOptions = DevOptions.instance;
    final debugEnabled =
        devOptions.colorMarkdownBlocks || devOptions.showBlockBoundaries;

    return _builder == null ||
        _lastData != widget.data ||
        _lastFontSize != widget.fontSize ||
        !_highlightsEqual(_lastHighlights, widget.searchHighlights) ||
        _lastHighlightIndex != widget.currentHighlightIndex ||
        _lastTheme?.brightness != theme.brightness ||
        _lastLinesPerChunk != widget.linesPerChunk ||
        _lastDebugEnabled != debugEnabled;
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

    final devOptions = DevOptions.instance;
    final debugEnabled =
        devOptions.colorMarkdownBlocks || devOptions.showBlockBoundaries;

    _lastData = widget.data;
    _lastFontSize = widget.fontSize;
    _lastHighlights = widget.searchHighlights;
    _lastHighlightIndex = widget.currentHighlightIndex;
    _lastTheme = theme;
    _lastLinesPerChunk = widget.linesPerChunk;
    _lastDebugEnabled = debugEnabled;

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

    // Add a spacer item for short content to prevent centering
    // The spacer fills remaining viewport space, forcing content to top
    final isShortContent = chunkCount <= 3;
    final itemCount = isShortContent ? chunkCount + 1 : chunkCount;

    // Cache debug state ONCE per build, not per chunk
    final devOptions = DevOptions.instance;
    final showColors = devOptions.colorMarkdownBlocks;
    final showBorders = devOptions.showBlockBoundaries;
    final debugEnabled = showColors || showBorders;

    // SelectionArea enables text selection across all chunks
    return SelectionArea(
      child: ScrollablePositionedList.builder(
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositionsListener,
        padding: widget.padding ?? const EdgeInsets.all(AppSpacing.lg),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Spacer item - fills remaining space to prevent centering
          if (isShortContent && index == chunkCount) {
            return LayoutBuilder(
              builder: (context, constraints) {
                // Get viewport height and create spacer to fill it
                final viewportHeight = MediaQuery.of(context).size.height;
                return SizedBox(height: viewportHeight * 0.7);
              },
            );
          }

          if (_builder == null || index >= chunkCount) {
            return const SizedBox.shrink();
          }

          // Build chunk spans (cached internally)
          final chunkSpans = _builder!.buildChunk(index);

          // Build the text widget
          Widget chunkWidget = Text.rich(
            TextSpan(style: baseStyle, children: chunkSpans),
          );

          // Wrap with double-tap detector if callback is provided
          if (widget.onDoubleTapLine != null) {
            chunkWidget = DoubleTapLineDetector(
              chunkIndex: index,
              linesPerChunk: _builder!.linesPerChunk,
              totalLines: _builder!.lineCount,
              fontSize: widget.fontSize,
              onDoubleTapLine: widget.onDoubleTapLine!,
              lineHeightScales: _builder!.getLineHeightScales(index),
              child: chunkWidget,
            );
          }

          // Early exit if debug disabled - no extra work
          if (!debugEnabled) {
            return RepaintBoundary(child: chunkWidget);
          }

          // Debug mode: wrap in colored/bordered container
          final colorIndex = index % _debugColors.length;

          if (showBorders) {
            // Full debug with borders and label
            chunkWidget = Container(
              decoration: BoxDecoration(
                color: showColors ? _debugColors[colorIndex] : null,
                border: Border.all(
                  color: _debugBorderColors[colorIndex],
                  width: 2,
                ),
                borderRadius: _debugBorderRadius,
              ),
              padding: _debugPadding,
              margin: _debugMargin,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: _debugLabelPadding,
                    margin: _debugLabelMargin,
                    decoration: BoxDecoration(
                      color: _debugBorderColors[colorIndex],
                      borderRadius: _debugLabelBorderRadius,
                    ),
                    child: Text('Chunk $index', style: _debugLabelStyle),
                  ),
                  chunkWidget,
                ],
              ),
            );
          } else if (showColors) {
            // Just background color, minimal overhead
            chunkWidget = Container(
              color: _debugColors[colorIndex],
              child: chunkWidget,
            );
          }

          // RepaintBoundary isolates repaints to this chunk only
          return RepaintBoundary(child: chunkWidget);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DEBUG STYLING CONSTANTS (static to avoid recreation)
  // ═══════════════════════════════════════════════════════════════════════════

  static const List<Color> _debugColors = [
    Color(0x40E91E63), // pink 💖
    Color(0x40FF5722), // deep orange
    Color(0x40FF9800), // orange
    Color(0x40FFEB3B), // yellow
    Color(0x4000E676), // green accent
    Color(0x4000BCD4), // cyan
    Color(0x402196F3), // blue
    Color(0x407C4DFF), // deep purple accent
    Color(0x409C27B0), // purple
    Color(0x40F50057), // pink accent
    Color(0x4000E5FF), // cyan accent
    Color(0x4076FF03), // lime accent
  ];

  static const List<Color> _debugBorderColors = [
    Color(0xFFE91E63), // pink 💖
    Color(0xFFFF5722), // deep orange
    Color(0xFFFF9800), // orange
    Color(0xFFFFEB3B), // yellow
    Color(0xFF00E676), // green accent
    Color(0xFF00BCD4), // cyan
    Color(0xFF2196F3), // blue
    Color(0xFF7C4DFF), // deep purple accent
    Color(0xFF9C27B0), // purple
    Color(0xFFF50057), // pink accent
    Color(0xFF00E5FF), // cyan accent
    Color(0xFF76FF03), // lime accent
  ];

  static const BorderRadius _debugBorderRadius = BorderRadius.all(
    Radius.circular(8),
  );
  static const BorderRadius _debugLabelBorderRadius = BorderRadius.all(
    Radius.circular(4),
  );
  static const EdgeInsets _debugPadding = EdgeInsets.all(8);
  static const EdgeInsets _debugMargin = EdgeInsets.symmetric(vertical: 4);
  static const EdgeInsets _debugLabelPadding = EdgeInsets.symmetric(
    horizontal: 6,
    vertical: 2,
  );
  static const EdgeInsets _debugLabelMargin = EdgeInsets.only(bottom: 4);
  static const TextStyle _debugLabelStyle = TextStyle(
    color: Colors.white,
    fontSize: 10,
    fontWeight: FontWeight.bold,
  );
}
