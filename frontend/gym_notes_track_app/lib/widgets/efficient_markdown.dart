import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../constants/app_spacing.dart';
import '../constants/font_constants.dart';
import '../constants/markdown_constants.dart';

class MarkdownLine {
  final int index;
  final String content;
  final MarkdownLineType type;
  final int indentLevel;
  final bool isChecked;
  final int? listNumber;

  const MarkdownLine({
    required this.index,
    required this.content,
    required this.type,
    this.indentLevel = 0,
    this.isChecked = false,
    this.listNumber,
  });
}

enum MarkdownLineType {
  text,
  heading1,
  heading2,
  heading3,
  heading4,
  heading5,
  heading6,
  bulletList,
  numberedList,
  checkbox,
  quote,
  codeBlock,
  horizontalRule,
  empty,
}

class EfficientMarkdownView extends StatefulWidget {
  final String data;
  final Function(String)? onCheckboxChanged;
  final MarkdownStyleSheet? styleSheet;
  final bool selectable;
  final double itemExtent;
  final int cacheExtent;
  final ScrollController? scrollController;
  final int? selectedLine;
  final Function(int)? onLineTap;
  final EdgeInsets? padding;

  const EfficientMarkdownView({
    super.key,
    required this.data,
    this.onCheckboxChanged,
    this.styleSheet,
    this.selectable = false,
    this.itemExtent = MarkdownConstants.itemExtent,
    this.cacheExtent = MarkdownConstants.cacheExtent,
    this.scrollController,
    this.selectedLine,
    this.onLineTap,
    this.padding,
  });

  @override
  State<EfficientMarkdownView> createState() => _EfficientMarkdownViewState();
}

class _EfficientMarkdownViewState extends State<EfficientMarkdownView> {
  late List<String> _rawLines;
  late String _currentData;

  // Lazy parsing cache - only parsed lines are stored
  final Map<int, MarkdownLine> _parsedLineCache = {};

  // Code block tracking for lazy parsing
  List<bool>? _codeBlockState; // true if line i is inside a code block

  static final _boldPattern = RegExp(r'\*\*(.+?)\*\*');
  static final _boldAltPattern = RegExp(r'__(.+?)__');
  static final _italicPattern = RegExp(r'\*(.+?)\*');
  static final _italicAltPattern = RegExp(r'_(.+?)_');
  static final _strikethroughPattern = RegExp(r'~~(.+?)~~');
  static final _codePattern = RegExp(r'`(.+?)`');
  static final _checkboxUncheckedPattern = RegExp(
    r'^([\s]*)-\s+\[\s\]\s+(.+)$',
  );
  static final _checkboxCheckedPattern = RegExp(
    r'^([\s]*)-\s+\[[xX]\]\s+(.+)$',
  );
  static final _numberedListPattern = RegExp(r'^(\d+)\.\s+(.+)$');

  @override
  void initState() {
    super.initState();
    _currentData = widget.data;
    _rawLines = _currentData.split('\n');
    _buildCodeBlockState();
  }

  @override
  void didUpdateWidget(EfficientMarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _currentData = widget.data;
      _rawLines = _currentData.split('\n');
      _parsedLineCache.clear();
      _buildCodeBlockState();
    }
  }

  /// Pre-compute which lines are inside code blocks (fast single pass)
  void _buildCodeBlockState() {
    _codeBlockState = List<bool>.filled(_rawLines.length, false);
    bool inCodeBlock = false;

    for (int i = 0; i < _rawLines.length; i++) {
      final line = _rawLines[i];
      if (line.trim().startsWith('```')) {
        _codeBlockState![i] = true; // The ``` line itself is part of code block
        inCodeBlock = !inCodeBlock;
      } else {
        _codeBlockState![i] = inCodeBlock;
      }
    }
  }

  /// Lazily parse a line only when needed
  MarkdownLine _getLine(int index) {
    // Return from cache if already parsed
    if (_parsedLineCache.containsKey(index)) {
      return _parsedLineCache[index]!;
    }

    // Parse on demand
    final line = _rawLines[index];
    final isInCodeBlock = _codeBlockState?[index] ?? false;

    MarkdownLine parsed;
    if (isInCodeBlock || line.trim().startsWith('```')) {
      parsed = MarkdownLine(
        index: index,
        content: line,
        type: MarkdownLineType.codeBlock,
      );
    } else {
      parsed = _parseLine(index, line);
    }

    // Cache it
    _parsedLineCache[index] = parsed;
    return parsed;
  }

  MarkdownLine _parseLine(int index, String line) {
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      return MarkdownLine(
        index: index,
        content: line,
        type: MarkdownLineType.empty,
      );
    }

    if (trimmed.startsWith('# ')) {
      return MarkdownLine(
        index: index,
        content: trimmed.substring(2),
        type: MarkdownLineType.heading1,
      );
    }

    if (trimmed.startsWith('## ')) {
      return MarkdownLine(
        index: index,
        content: trimmed.substring(3),
        type: MarkdownLineType.heading2,
      );
    }

    if (trimmed.startsWith('### ')) {
      return MarkdownLine(
        index: index,
        content: trimmed.substring(4),
        type: MarkdownLineType.heading3,
      );
    }

    if (trimmed.startsWith('#### ')) {
      return MarkdownLine(
        index: index,
        content: trimmed.substring(5),
        type: MarkdownLineType.heading4,
      );
    }

    if (trimmed.startsWith('##### ')) {
      return MarkdownLine(
        index: index,
        content: trimmed.substring(6),
        type: MarkdownLineType.heading5,
      );
    }

    if (trimmed.startsWith('###### ')) {
      return MarkdownLine(
        index: index,
        content: trimmed.substring(7),
        type: MarkdownLineType.heading6,
      );
    }

    final uncheckedMatch = _checkboxUncheckedPattern.firstMatch(line);
    if (uncheckedMatch != null) {
      return MarkdownLine(
        index: index,
        content: uncheckedMatch.group(2) ?? '',
        type: MarkdownLineType.checkbox,
        indentLevel: (uncheckedMatch.group(1)?.length ?? 0) ~/ 2,
        isChecked: false,
      );
    }

    final checkedMatch = _checkboxCheckedPattern.firstMatch(line);
    if (checkedMatch != null) {
      return MarkdownLine(
        index: index,
        content: checkedMatch.group(2) ?? '',
        type: MarkdownLineType.checkbox,
        indentLevel: (checkedMatch.group(1)?.length ?? 0) ~/ 2,
        isChecked: true,
      );
    }

    if (trimmed.startsWith('- ') ||
        trimmed.startsWith('* ') ||
        trimmed.startsWith('• ')) {
      final indent = line.length - line.trimLeft().length;
      return MarkdownLine(
        index: index,
        content: trimmed.substring(2),
        type: MarkdownLineType.bulletList,
        indentLevel: indent ~/ 2,
      );
    }

    final numberedMatch = _numberedListPattern.firstMatch(trimmed);
    if (numberedMatch != null) {
      final indent = line.length - line.trimLeft().length;
      return MarkdownLine(
        index: index,
        content: numberedMatch.group(2) ?? '',
        type: MarkdownLineType.numberedList,
        listNumber: int.tryParse(numberedMatch.group(1) ?? '1') ?? 1,
        indentLevel: indent ~/ 2,
      );
    }

    if (trimmed.startsWith('> ')) {
      return MarkdownLine(
        index: index,
        content: trimmed.substring(2),
        type: MarkdownLineType.quote,
      );
    }

    if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
      return MarkdownLine(
        index: index,
        content: '',
        type: MarkdownLineType.horizontalRule,
      );
    }

    return MarkdownLine(
      index: index,
      content: line,
      type: MarkdownLineType.text,
    );
  }

  void _toggleCheckbox(int lineIndex) {
    if (widget.onCheckboxChanged == null) return;

    if (lineIndex >= _rawLines.length) return;

    final line = _rawLines[lineIndex];
    final parsedLine = _getLine(lineIndex);

    String newLine;
    if (parsedLine.isChecked) {
      newLine = line.replaceFirst(RegExp(r'\[[xX]\]'), '[ ]');
    } else {
      newLine = line.replaceFirst('[ ]', '[x]');
    }

    _rawLines[lineIndex] = newLine;
    final updatedContent = _rawLines.join('\n');

    setState(() {
      _currentData = updatedContent;
      // Only invalidate the changed line in cache
      _parsedLineCache.remove(lineIndex);
    });

    widget.onCheckboxChanged!(updatedContent);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.scrollController,
      itemCount: _rawLines.length,
      cacheExtent: widget.cacheExtent.toDouble(),
      padding: widget.padding,
      itemBuilder: (context, index) {
        // Lazy parsing happens here - only when line becomes visible
        final line = _getLine(index);
        final isSelected = widget.selectedLine == index;
        return _wrapWithSelection(
          context,
          _buildLine(context, line),
          index,
          isSelected,
        );
      },
    );
  }

  Widget _wrapWithSelection(
    BuildContext context,
    Widget child,
    int lineIndex,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () => widget.onLineTap?.call(lineIndex),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        decoration: isSelected
            ? BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              )
            : null,
        child: child,
      ),
    );
  }

  Widget _buildLine(BuildContext context, MarkdownLine line) {
    switch (line.type) {
      case MarkdownLineType.empty:
        return const SizedBox(height: AppSpacing.lg);

      case MarkdownLineType.heading1:
        final baseFontSize =
            widget.styleSheet?.p?.fontSize ?? FontConstants.defaultFontSize;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: _buildSelectableText(
            line.content,
            widget.styleSheet?.h1 ??
                TextStyle(
                  fontSize: baseFontSize * MarkdownConstants.h1Scale,
                  fontWeight: FontWeight.bold,
                ),
          ),
        );

      case MarkdownLineType.heading2:
        final baseFontSize =
            widget.styleSheet?.p?.fontSize ?? FontConstants.defaultFontSize;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: _buildSelectableText(
            line.content,
            widget.styleSheet?.h2 ??
                TextStyle(
                  fontSize: baseFontSize * MarkdownConstants.h2Scale,
                  fontWeight: FontWeight.bold,
                ),
          ),
        );

      case MarkdownLineType.heading3:
        final baseFontSize =
            widget.styleSheet?.p?.fontSize ?? FontConstants.defaultFontSize;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: _buildSelectableText(
            line.content,
            widget.styleSheet?.h3 ??
                TextStyle(
                  fontSize: baseFontSize * MarkdownConstants.h3Scale,
                  fontWeight: FontWeight.bold,
                ),
          ),
        );

      case MarkdownLineType.heading4:
        final baseFontSize =
            widget.styleSheet?.p?.fontSize ?? FontConstants.defaultFontSize;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: _buildSelectableText(
            line.content,
            widget.styleSheet?.h4 ??
                TextStyle(
                  fontSize: baseFontSize * MarkdownConstants.h4Scale,
                  fontWeight: FontWeight.bold,
                ),
          ),
        );

      case MarkdownLineType.heading5:
        final baseFontSize =
            widget.styleSheet?.p?.fontSize ?? FontConstants.defaultFontSize;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: _buildSelectableText(
            line.content,
            widget.styleSheet?.h5 ??
                TextStyle(fontSize: baseFontSize, fontWeight: FontWeight.bold),
          ),
        );

      case MarkdownLineType.heading6:
        final baseFontSize =
            widget.styleSheet?.p?.fontSize ?? FontConstants.defaultFontSize;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: _buildSelectableText(
            line.content,
            widget.styleSheet?.h6 ??
                TextStyle(
                  fontSize: baseFontSize * MarkdownConstants.h6Scale,
                  fontWeight: FontWeight.bold,
                ),
          ),
        );

      case MarkdownLineType.checkbox:
        return _buildCheckbox(context, line);

      case MarkdownLineType.bulletList:
        final baseFontSize =
            widget.styleSheet?.p?.fontSize ?? FontConstants.defaultFontSize;
        final lineHeight = widget.styleSheet?.p?.height;
        return Padding(
          padding: EdgeInsets.only(
            left: MarkdownConstants.indentPerLevel +
                line.indentLevel * MarkdownConstants.indentPerLevel,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• ',
                style: TextStyle(fontSize: baseFontSize, height: lineHeight),
              ),
              Expanded(child: _buildRichText(line.content)),
            ],
          ),
        );

      case MarkdownLineType.numberedList:
        final baseFontSize =
            widget.styleSheet?.p?.fontSize ?? FontConstants.defaultFontSize;
        final lineHeight = widget.styleSheet?.p?.height;
        return Padding(
          padding: EdgeInsets.only(
            left: MarkdownConstants.indentPerLevel +
                line.indentLevel * MarkdownConstants.indentPerLevel,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: MarkdownConstants.numberedListNumberWidth,
                child: Text(
                  '${line.listNumber}. ',
                  style: TextStyle(fontSize: baseFontSize, height: lineHeight),
                ),
              ),
              Expanded(child: _buildRichText(line.content)),
            ],
          ),
        );

      case MarkdownLineType.quote:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          padding: const EdgeInsets.only(left: AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: MarkdownConstants.quoteBorderWidth,
              ),
            ),
          ),
          child: _buildSelectableText(
            line.content,
            TextStyle(
              fontStyle: FontStyle.italic,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(
                    alpha: MarkdownConstants.quoteTextOpacity,
                  ),
            ),
          ),
        );

      case MarkdownLineType.codeBlock:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            line.content,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: MarkdownConstants.codeBlockFontSize,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );

      case MarkdownLineType.horizontalRule:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Divider(),
        );

      case MarkdownLineType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: _buildRichText(line.content),
        );
    }
  }

  Widget _buildCheckbox(BuildContext context, MarkdownLine line) {
    final baseFontSize =
        widget.styleSheet?.p?.fontSize ?? FontConstants.defaultFontSize;
    final lineHeight = widget.styleSheet?.p?.height;
    return Padding(
      padding: EdgeInsets.only(
        left: line.indentLevel * MarkdownConstants.indentPerLevel,
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: widget.onCheckboxChanged != null
                ? () => _toggleCheckbox(line.index)
                : null,
            child: Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: Icon(
                line.isChecked
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: baseFontSize * MarkdownConstants.checkboxIconScale,
                color: line.isChecked
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(
                          alpha: MarkdownConstants.uncheckedCheckboxOpacity,
                        ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: widget.onCheckboxChanged != null
                  ? () => _toggleCheckbox(line.index)
                  : null,
              child: Text(
                line.content,
                style: TextStyle(
                  fontSize: baseFontSize,
                  height: lineHeight,
                  decoration: line.isChecked
                      ? TextDecoration.lineThrough
                      : null,
                  color: line.isChecked
                      ? Theme.of(context).colorScheme.onSurface.withValues(
                            alpha: MarkdownConstants.checkedTextOpacity,
                          )
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableText(String text, TextStyle style) {
    if (widget.selectable) {
      return SelectableText(text, style: style);
    }
    return Text(text, style: style);
  }

  Widget _buildRichText(String text) {
    final spans = _parseInlineMarkdown(text);
    final baseFontSize =
        widget.styleSheet?.p?.fontSize ?? FontConstants.defaultFontSize;
    final lineHeight = widget.styleSheet?.p?.height;

    if (widget.selectable) {
      return SelectableText.rich(TextSpan(children: spans));
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: baseFontSize,
          height: lineHeight,
        ),
      ),
    );
  }

  List<TextSpan> _parseInlineMarkdown(String text) {
    final spans = <TextSpan>[];
    final baseFontSize =
        widget.styleSheet?.p?.fontSize ?? FontConstants.defaultFontSize;
    final lineHeight = widget.styleSheet?.p?.height;
    final defaultStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: baseFontSize,
      height: lineHeight,
    );

    final codeStyle = TextStyle(
      fontFamily: 'monospace',
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );

    final patterns = [
      (_boldPattern, const TextStyle(fontWeight: FontWeight.bold)),
      (_boldAltPattern, const TextStyle(fontWeight: FontWeight.bold)),
      (_italicPattern, const TextStyle(fontStyle: FontStyle.italic)),
      (_italicAltPattern, const TextStyle(fontStyle: FontStyle.italic)),
      (
        _strikethroughPattern,
        const TextStyle(decoration: TextDecoration.lineThrough),
      ),
      (_codePattern, codeStyle),
    ];

    int currentIndex = 0;

    while (currentIndex < text.length) {
      int? earliestMatchStart;
      RegExpMatch? earliestMatch;
      TextStyle? matchStyle;

      for (final (pattern, style) in patterns) {
        final match = pattern.firstMatch(text.substring(currentIndex));
        if (match != null) {
          final matchStart = currentIndex + match.start;
          if (earliestMatchStart == null || matchStart < earliestMatchStart) {
            earliestMatchStart = matchStart;
            earliestMatch = match;
            matchStyle = style;
          }
        }
      }

      if (earliestMatch != null &&
          earliestMatchStart != null &&
          matchStyle != null) {
        if (earliestMatchStart > currentIndex) {
          spans.add(
            TextSpan(
              text: text.substring(currentIndex, earliestMatchStart),
              style: defaultStyle,
            ),
          );
        }

        spans.add(
          TextSpan(
            text: earliestMatch.group(1),
            style: defaultStyle.merge(matchStyle),
          ),
        );

        currentIndex = earliestMatchStart + earliestMatch.group(0)!.length;
      } else {
        spans.add(
          TextSpan(text: text.substring(currentIndex), style: defaultStyle),
        );
        break;
      }
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: defaultStyle));
    }

    return spans;
  }
}

class EfficientMarkdownEditor extends StatefulWidget {
  final String initialContent;
  final ValueChanged<String>? onChanged;
  final Function(String)? onCheckboxChanged;
  final double previewFontSize;
  final bool showLineNumbers;

  const EfficientMarkdownEditor({
    super.key,
    required this.initialContent,
    this.onChanged,
    this.onCheckboxChanged,
    this.previewFontSize = FontConstants.defaultFontSize,
    this.showLineNumbers = false,
  });

  @override
  State<EfficientMarkdownEditor> createState() =>
      _EfficientMarkdownEditorState();
}

class _EfficientMarkdownEditorState extends State<EfficientMarkdownEditor> {
  late String _content;

  @override
  void initState() {
    super.initState();
    _content = widget.initialContent;
  }

  @override
  Widget build(BuildContext context) {
    return EfficientMarkdownView(
      data: _content,
      selectable: true,
      onCheckboxChanged: (updatedContent) {
        setState(() {
          _content = updatedContent;
        });
        widget.onCheckboxChanged?.call(updatedContent);
        widget.onChanged?.call(updatedContent);
      },
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: widget.previewFontSize),
        h1: TextStyle(
          fontSize: widget.previewFontSize * MarkdownConstants.h1Scale,
          fontWeight: FontWeight.bold,
        ),
        h2: TextStyle(
          fontSize: widget.previewFontSize * MarkdownConstants.h2Scale,
          fontWeight: FontWeight.bold,
        ),
        h3: TextStyle(
          fontSize: widget.previewFontSize * MarkdownConstants.h3Scale,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
