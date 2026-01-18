import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../constants/markdown_constants.dart';

/// Configuration for editor width calculation
class EditorWidthConfig {
  final GlobalKey editorContainerKey;
  final GlobalKey? lineNumbersKey;
  final GlobalKey? scrollIndicatorKey;
  final double fontSize;
  final double lineHeight;

  /// Additional safety margin for font rendering differences
  final double safetyMargin;

  const EditorWidthConfig({
    required this.editorContainerKey,
    this.lineNumbersKey,
    this.scrollIndicatorKey,
    required this.fontSize,
    this.lineHeight = MarkdownConstants.lineHeight,
    this.safetyMargin = 10.0,
  });
}

/// Result of smart line breaking operation
class LineBreakResult {
  final List<String> lines;
  final int linesModified;

  const LineBreakResult({required this.lines, required this.linesModified});
}

/// Utility class for calculating available text width in the editor
/// and measuring text pixel widths for paste line breaking.
///
/// Supports smart line breaking that:
/// - Skips code blocks (``` fenced blocks)
/// - Respects markdown syntax (links, images, inline code, bold/italic)
/// - Breaks at word boundaries when possible
class EditorWidthCalculator {
  final EditorWidthConfig config;

  /// Cached editor padding from the CodeEditor widget
  final EdgeInsets editorPadding;

  // Regex patterns for markdown syntax that shouldn't be broken
  static final _linkPattern = RegExp(r'\[([^\]]*)\]\([^)]+\)');
  static final _imagePattern = RegExp(r'!\[([^\]]*)\]\([^)]+\)');
  static final _inlineCodePattern = RegExp(r'`[^`]+`');
  static final _boldPattern = RegExp(r'\*\*[^*]+\*\*|__[^_]+__');
  static final _italicPattern = RegExp(r'\*[^*]+\*|_[^_]+_');
  static final _codeBlockFencePattern = RegExp(r'^```');

  const EditorWidthCalculator({
    required this.config,
    required this.editorPadding,
  });

  /// Get the available width for text in the editor by measuring actual widget sizes
  double? getAvailableTextWidth() {
    // Measure the editor container width
    final containerWidth = _measureWidgetWidth(config.editorContainerKey);
    if (containerWidth == null) return null;

    // Measure line numbers width (if key provided and widget exists)
    final lineNumbersWidth = config.lineNumbersKey != null
        ? _measureWidgetWidth(config.lineNumbersKey!) ?? 0.0
        : 0.0;

    // Measure scroll indicator width (if key provided and widget exists)
    final scrollIndicatorWidth = config.scrollIndicatorKey != null
        ? _measureWidgetWidth(config.scrollIndicatorKey!) ?? 0.0
        : 0.0;

    // Calculate total deduction
    final horizontalPadding = editorPadding.left + editorPadding.right;
    final totalDeduction =
        lineNumbersWidth +
        horizontalPadding +
        scrollIndicatorWidth +
        config.safetyMargin;

    final availableWidth = containerWidth - totalDeduction;

    return availableWidth > 0 ? availableWidth : null;
  }

  /// Measure the pixel width of a string using the editor's font
  double measureTextWidth(String text) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: _getTextStyle()),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    );
    textPainter.layout();
    return textPainter.width;
  }

  /// Check if a line exceeds the available width
  bool lineExceedsWidth(String lineText, double availableWidth) {
    return lineText.isNotEmpty && measureTextWidth(lineText) > availableWidth;
  }

  /// Smart line breaking for all lines, respecting code blocks and markdown syntax.
  /// Returns the result with new lines and count of modified lines.
  LineBreakResult breakLinesSmartly(List<String> lines, double maxWidth) {
    final result = <String>[];
    int linesModified = 0;
    bool inCodeBlock = false;

    for (final line in lines) {
      final trimmed = line.trim();

      // Toggle code block state
      if (_codeBlockFencePattern.hasMatch(trimmed)) {
        inCodeBlock = !inCodeBlock;
        result.add(line);
        continue;
      }

      // Skip lines inside code blocks
      if (inCodeBlock) {
        result.add(line);
        continue;
      }

      // Check if line needs breaking
      if (line.isEmpty || !lineExceedsWidth(line, maxWidth)) {
        result.add(line);
        continue;
      }

      // Break the line respecting markdown syntax
      final brokenLines = _breakLineRespectingMarkdown(line, maxWidth);
      if (brokenLines.length > 1) {
        linesModified++;
      }
      result.addAll(brokenLines);
    }

    return LineBreakResult(lines: result, linesModified: linesModified);
  }

  /// Break a single line respecting markdown syntax
  List<String> _breakLineRespectingMarkdown(String line, double maxWidth) {
    if (line.isEmpty || measureTextWidth(line) <= maxWidth) return [line];

    // Find all protected ranges (markdown syntax that shouldn't be broken)
    final protectedRanges = _findProtectedRanges(line);

    final result = <String>[];
    var remaining = line;
    var offset = 0;

    while (remaining.isNotEmpty && measureTextWidth(remaining) > maxWidth) {
      // Find the optimal break point
      int breakPoint = _findBreakPoint(remaining, maxWidth);

      if (breakPoint <= 0) {
        // Can't fit even one character, force at least one
        breakPoint = 1;
      }

      // Adjust break point to respect protected ranges
      breakPoint = _adjustBreakPointForProtectedRanges(
        offset,
        breakPoint,
        protectedRanges,
        remaining.length,
      );

      // Try to break at a word boundary (space) if possible
      // but only if it doesn't put us inside a protected range
      final spaceIndex = remaining.lastIndexOf(' ', breakPoint);
      if (spaceIndex > 0) {
        final adjustedSpaceIndex = _adjustBreakPointForProtectedRanges(
          offset,
          spaceIndex,
          protectedRanges,
          remaining.length,
        );
        if (adjustedSpaceIndex == spaceIndex) {
          breakPoint = spaceIndex;
        }
      }

      // Ensure we make progress
      if (breakPoint <= 0) breakPoint = 1;

      result.add(remaining.substring(0, breakPoint).trimRight());
      remaining = remaining.substring(breakPoint).trimLeft();
      offset += breakPoint;
    }

    if (remaining.isNotEmpty) {
      result.add(remaining);
    }

    return result;
  }

  /// Find all ranges in the line that shouldn't be broken (markdown syntax)
  List<_Range> _findProtectedRanges(String line) {
    final ranges = <_Range>[];

    // Find all patterns and add their ranges
    for (final pattern in [
      _imagePattern, // Check images first (they contain link pattern)
      _linkPattern,
      _inlineCodePattern,
      _boldPattern,
      _italicPattern,
    ]) {
      for (final match in pattern.allMatches(line)) {
        ranges.add(_Range(match.start, match.end));
      }
    }

    // Sort by start position and merge overlapping ranges
    ranges.sort((a, b) => a.start.compareTo(b.start));
    return _mergeOverlappingRanges(ranges);
  }

  /// Merge overlapping ranges
  List<_Range> _mergeOverlappingRanges(List<_Range> ranges) {
    if (ranges.isEmpty) return ranges;

    final merged = <_Range>[ranges.first];

    for (int i = 1; i < ranges.length; i++) {
      final current = ranges[i];
      final last = merged.last;

      if (current.start <= last.end) {
        // Overlapping or adjacent, merge
        merged[merged.length - 1] = _Range(
          last.start,
          current.end > last.end ? current.end : last.end,
        );
      } else {
        merged.add(current);
      }
    }

    return merged;
  }

  /// Adjust break point to not break inside protected markdown ranges
  int _adjustBreakPointForProtectedRanges(
    int lineOffset,
    int breakPoint,
    List<_Range> protectedRanges,
    int remainingLength,
  ) {
    final absoluteBreakPoint = lineOffset + breakPoint;

    for (final range in protectedRanges) {
      // If break point is inside a protected range, move it before the range
      if (absoluteBreakPoint > range.start && absoluteBreakPoint < range.end) {
        final adjustedBreakPoint = range.start - lineOffset;
        // Only adjust if it gives us a valid break point
        if (adjustedBreakPoint > 0) {
          return adjustedBreakPoint;
        }
        // If we can't break before, try after the range
        final afterRange = range.end - lineOffset;
        if (afterRange < remainingLength) {
          return afterRange;
        }
      }
    }

    return breakPoint;
  }

  /// Binary search to find how many characters fit within maxWidth
  int _findBreakPoint(String text, double maxWidth) {
    int low = 0;
    int high = text.length;

    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      final substring = text.substring(0, mid);
      if (measureTextWidth(substring) <= maxWidth) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }

    return low;
  }

  TextStyle _getTextStyle() {
    return TextStyle(fontSize: config.fontSize, height: config.lineHeight);
  }

  double? _measureWidgetWidth(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size.width;
  }
}

/// Simple range class for tracking protected text ranges
class _Range {
  final int start;
  final int end;

  const _Range(this.start, this.end);
}
