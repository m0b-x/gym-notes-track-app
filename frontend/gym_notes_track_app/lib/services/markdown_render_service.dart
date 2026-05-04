import 'package:flutter/material.dart';

import '../utils/line_based_markdown_builder.dart';

/// Owns the lifecycle of a [LineBasedMarkdownBuilder] for a single
/// markdown preview surface.
///
/// This service centralizes the cache-invalidation rules and adaptive
/// chunk sizing that previously lived inside
/// `SourceMappedMarkdownView`. It is intentionally widget-free so it
/// can be driven by either a widget's [State] or a BLoC.
///
/// The service preserves the existing performance characteristics:
///   * Builder is reused as long as none of the inputs that affect
///     parsing/styling have changed.
///   * Builder is disposed and recreated when inputs change so that
///     gesture recognizers do not leak.
///   * Chunk LRU cache and lazy line extraction live inside the
///     underlying [LineBasedMarkdownBuilder] and are unaffected.
class MarkdownRenderService {
  LineBasedMarkdownBuilder? _builder;

  String? _lastData;
  double? _lastFontSize;
  List<TextRange>? _lastHighlights;
  int? _lastHighlightIndex;
  Brightness? _lastBrightness;
  int? _lastLinesPerChunk;
  bool? _lastDebugEnabled;

  /// The active builder, or `null` if [prepare] has not been called yet.
  LineBasedMarkdownBuilder? get builder => _builder;

  int get chunkCount => _builder?.chunkCount ?? 0;
  int get lineCount => _builder?.lineCount ?? 0;
  int get linesPerChunk => _builder?.linesPerChunk ?? 0;

  /// Ensures the underlying builder is up to date for the given inputs.
  ///
  /// Returns `true` when the builder was rebuilt (i.e. cached spans
  /// were thrown away), `false` when the existing builder was reused.
  ///
  /// The invalidation rules mirror the previous in-widget logic
  /// exactly so behavior is unchanged. Callers without a
  /// [BuildContext] (e.g. a BLoC) build the [LineMarkdownStyle]
  /// themselves and pass it together with the [Brightness] cache key.
  bool prepareWithStyle({
    required String data,
    required double fontSize,
    required Brightness brightness,
    required LineMarkdownStyle style,
    required int linesPerChunk,
    required bool debugEnabled,
    List<TextRange>? searchHighlights,
    int? currentHighlightIndex,
    LinkTapCallback? onLinkTap,
    CheckboxTapCallback? onCheckboxTap,
  }) {
    final needsRebuild =
        _builder == null ||
        _lastData != data ||
        _lastFontSize != fontSize ||
        !_highlightsEqual(_lastHighlights, searchHighlights) ||
        _lastHighlightIndex != currentHighlightIndex ||
        _lastBrightness != brightness ||
        _lastLinesPerChunk != linesPerChunk ||
        _lastDebugEnabled != debugEnabled;

    if (!needsRebuild) {
      return false;
    }

    _lastData = data;
    _lastFontSize = fontSize;
    _lastHighlights = searchHighlights;
    _lastHighlightIndex = currentHighlightIndex;
    _lastBrightness = brightness;
    _lastLinesPerChunk = linesPerChunk;
    _lastDebugEnabled = debugEnabled;

    final adaptiveChunkSize = _computeAdaptiveChunkSize(
      _estimateLineCount(data),
      linesPerChunk,
    );

    _disposeBuilder();
    _builder = LineBasedMarkdownBuilder(
      style: style,
      onLinkTap: onLinkTap,
      onCheckboxTap: onCheckboxTap,
      searchHighlights: searchHighlights,
      currentHighlightIndex: currentHighlightIndex,
      linesPerChunk: adaptiveChunkSize,
    );
    _builder!.prepare(data);

    return true;
  }

  /// Pre-warm the LRU cache for [chunkIndex] without forcing a render.
  /// Safe to call with out-of-range indices (no-op).
  void preWarmChunk(int chunkIndex) {
    final b = _builder;
    if (b == null) return;
    if (chunkIndex < 0 || chunkIndex >= b.chunkCount) return;
    b.buildChunk(chunkIndex);
  }

  /// Disposes the underlying builder and clears all cached state.
  void dispose() {
    _disposeBuilder();
    _lastData = null;
    _lastFontSize = null;
    _lastHighlights = null;
    _lastHighlightIndex = null;
    _lastBrightness = null;
    _lastLinesPerChunk = null;
    _lastDebugEnabled = null;
  }

  void _disposeBuilder() {
    _builder?.dispose();
    _builder = null;
  }

  /// Counts source lines by scanning for newline characters. Used
  /// only to drive [_computeAdaptiveChunkSize], so an off-by-one is
  /// inconsequential.
  int _estimateLineCount(String data) {
    return '\n'.allMatches(data).length + 1;
  }

  /// Hard cap on the chunk size produced by [_computeAdaptiveChunkSize].
  ///
  /// `scrollToLineIndex` lands on the chunk containing the target
  /// line and then interpolates an `alignment` within that chunk —
  /// so larger chunks make line-precision scroll coarser. 100 lines
  /// per chunk keeps the worst-case landing error to roughly one
  /// screen height even on huge documents while still capping the
  /// total `ScrollablePositionedList` item count.
  static const int _maxAdaptiveChunkSize = 100;

  int _computeAdaptiveChunkSize(int lineCount, int baseChunkSize) {
    final int scaled;
    if (lineCount < 1000) {
      scaled = baseChunkSize;
    } else if (lineCount < 10000) {
      scaled = baseChunkSize * 2;
    } else if (lineCount < 50000) {
      scaled = baseChunkSize * 5;
    } else {
      scaled = baseChunkSize * 10;
    }
    // Never go below the configured size and never exceed the cap.
    if (scaled < baseChunkSize) return baseChunkSize;
    if (scaled > _maxAdaptiveChunkSize) return _maxAdaptiveChunkSize;
    return scaled;
  }

  bool _highlightsEqual(List<TextRange>? a, List<TextRange>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].start != b[i].start || a[i].end != b[i].end) return false;
    }
    return true;
  }
}
