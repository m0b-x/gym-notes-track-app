import 'package:flutter/material.dart';

import '../constants/markdown_constants.dart';
import '../utils/line_based_markdown_builder.dart';

class SimpleMarkdownPreview extends StatefulWidget {
  final String data;
  final double fontSize;
  final EdgeInsets? padding;
  final LinkTapCallback? onTapLink;

  const SimpleMarkdownPreview({
    super.key,
    required this.data,
    this.fontSize = 14.0,
    this.padding,
    this.onTapLink,
  });

  @override
  State<SimpleMarkdownPreview> createState() => _SimpleMarkdownPreviewState();
}

class _SimpleMarkdownPreviewState extends State<SimpleMarkdownPreview> {
  LineBasedMarkdownBuilder? _builder;
  String? _lastData;
  double? _lastFontSize;
  ThemeData? _lastTheme;

  @override
  void dispose() {
    _builder?.dispose();
    super.dispose();
  }

  bool _shouldRebuild(ThemeData theme) {
    return _builder == null ||
        _lastData != widget.data ||
        _lastFontSize != widget.fontSize ||
        _lastTheme?.brightness != theme.brightness;
  }

  void _buildCache(BuildContext context) {
    final theme = Theme.of(context);

    if (!_shouldRebuild(theme)) {
      return;
    }

    _builder?.dispose();

    _lastData = widget.data;
    _lastFontSize = widget.fontSize;
    _lastTheme = theme;

    final mdStyle = LineMarkdownStyle.fromTheme(theme, widget.fontSize);

    _builder = LineBasedMarkdownBuilder(
      style: mdStyle,
      onLinkTap: widget.onTapLink,
      linesPerChunk: 100,
    );

    _builder!.prepare(widget.data);
  }

  @override
  Widget build(BuildContext context) {
    _buildCache(context);

    if (_builder == null || widget.data.isEmpty) {
      return const SizedBox.shrink();
    }

    final baseStyle = TextStyle(
      fontSize: widget.fontSize,
      height: MarkdownConstants.lineHeight,
    );

    final allSpans = <InlineSpan>[];
    for (int i = 0; i < _builder!.chunkCount; i++) {
      final chunkSpans = _builder!.buildChunk(i);
      allSpans.addAll(chunkSpans);
      if (i < _builder!.chunkCount - 1) {
        allSpans.add(const TextSpan(text: '\n'));
      }
    }

    return SingleChildScrollView(
      padding: widget.padding ?? const EdgeInsets.all(8),
      child: Text.rich(TextSpan(style: baseStyle, children: allSpans)),
    );
  }
}
