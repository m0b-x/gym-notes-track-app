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
  State<SourceMappedMarkdownView> createState() =>
      _SourceMappedMarkdownViewState();
}

class _SourceMappedMarkdownViewState extends State<SourceMappedMarkdownView> {
  LazyMarkdownBlocks? _lazyBlocks;
  String? _lastData;
  double? _lastFontSize;
  List<TextRange>? _lastHighlights;
  int? _lastHighlightIndex;
  ThemeData? _lastTheme;

  bool _shouldRebuild(ThemeData theme) {
    return _lazyBlocks == null ||
        _lastData != widget.data ||
        _lastFontSize != widget.fontSize ||
        _lastHighlights != widget.searchHighlights ||
        _lastHighlightIndex != widget.currentHighlightIndex ||
        _lastTheme?.brightness != theme.brightness;
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

    return ListView.builder(
      controller: widget.scrollController,
      padding: widget.padding ?? const EdgeInsets.all(AppSpacing.lg),
      itemCount: _lazyBlocks?.length ?? 0,
      itemBuilder: (context, index) {
        // Spans are built lazily here, only when this block becomes visible
        final blockSpans = _lazyBlocks![index];
        return Text.rich(TextSpan(style: baseStyle, children: blockSpans));
      },
    );
  }
}
