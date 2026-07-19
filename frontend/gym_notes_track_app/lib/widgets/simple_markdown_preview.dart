import 'package:flutter/material.dart';

import '../constants/markdown_constants.dart';
import '../utils/line_based_markdown_builder.dart';
import '../utils/markdown_color_syntax.dart';

class SimpleMarkdownPreview extends StatefulWidget {
  final String data;
  final double fontSize;
  final EdgeInsets? padding;
  final LinkTapCallback? onTapLink;

  /// Money ledger display config, mirroring [LineBasedMarkdownBuilder].
  /// Defaults leave the ledger off — a caller that does not resolve
  /// `SettingsService.getMoneyConfig()` renders `$` lines as plain text,
  /// which is why this has to be threaded through rather than assumed.
  final bool moneyEnabled;
  final int moneyStartCents;
  final String currencySymbol;
  final bool currencySuffix;

  /// Resolved colour palette, so `{name:text}` runs and money accent
  /// tokens show the user's custom colours and not just the presets.
  final MarkdownColorPalette colorPalette;

  const SimpleMarkdownPreview({
    super.key,
    required this.data,
    this.fontSize = 14.0,
    this.padding,
    this.onTapLink,
    this.moneyEnabled = false,
    this.moneyStartCents = 0,
    this.currencySymbol = '',
    this.currencySuffix = false,
    this.colorPalette = MarkdownColorPalette.presets,
  });

  @override
  State<SimpleMarkdownPreview> createState() => _SimpleMarkdownPreviewState();
}

class _SimpleMarkdownPreviewState extends State<SimpleMarkdownPreview> {
  LineBasedMarkdownBuilder? _builder;
  String? _lastData;
  double? _lastFontSize;
  ThemeData? _lastTheme;
  bool? _lastMoneyEnabled;
  int? _lastMoneyStartCents;
  String? _lastCurrencySymbol;
  bool? _lastCurrencySuffix;
  MarkdownColorPalette? _lastColorPalette;

  @override
  void dispose() {
    _builder?.dispose();
    super.dispose();
  }

  /// The money config and palette arrive asynchronously, so they must be
  /// part of the rebuild check — otherwise the first (config-less) build
  /// sticks and `$` lines stay plain text forever.
  bool _shouldRebuild(ThemeData theme) {
    return _builder == null ||
        _lastData != widget.data ||
        _lastFontSize != widget.fontSize ||
        _lastTheme?.brightness != theme.brightness ||
        _lastMoneyEnabled != widget.moneyEnabled ||
        _lastMoneyStartCents != widget.moneyStartCents ||
        _lastCurrencySymbol != widget.currencySymbol ||
        _lastCurrencySuffix != widget.currencySuffix ||
        _lastColorPalette != widget.colorPalette;
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
    _lastMoneyEnabled = widget.moneyEnabled;
    _lastMoneyStartCents = widget.moneyStartCents;
    _lastCurrencySymbol = widget.currencySymbol;
    _lastCurrencySuffix = widget.currencySuffix;
    _lastColorPalette = widget.colorPalette;

    final mdStyle = LineMarkdownStyle.fromTheme(theme, widget.fontSize);

    _builder = LineBasedMarkdownBuilder(
      style: mdStyle,
      onLinkTap: widget.onTapLink,
      moneyEnabled: widget.moneyEnabled,
      moneyStartCents: widget.moneyStartCents,
      currencySymbol: widget.currencySymbol,
      currencySuffix: widget.currencySuffix,
      colorPalette: widget.colorPalette,
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
