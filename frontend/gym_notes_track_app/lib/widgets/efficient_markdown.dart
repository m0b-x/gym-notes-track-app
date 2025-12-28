import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

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

  const EfficientMarkdownView({
    super.key,
    required this.data,
    this.onCheckboxChanged,
    this.styleSheet,
    this.selectable = false,
    this.itemExtent = 32.0,
    this.cacheExtent = 500,
  });

  @override
  State<EfficientMarkdownView> createState() => _EfficientMarkdownViewState();
}

class _EfficientMarkdownViewState extends State<EfficientMarkdownView> {
  late List<MarkdownLine> _parsedLines;
  late String _currentData;

  @override
  void initState() {
    super.initState();
    _currentData = widget.data;
    _parsedLines = _parseMarkdown(_currentData);
  }

  @override
  void didUpdateWidget(EfficientMarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _currentData = widget.data;
      _parsedLines = _parseMarkdown(_currentData);
    }
  }

  List<MarkdownLine> _parseMarkdown(String data) {
    final lines = data.split('\n');
    final parsedLines = <MarkdownLine>[];
    bool inCodeBlock = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.trim().startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        parsedLines.add(MarkdownLine(
          index: i,
          content: line,
          type: MarkdownLineType.codeBlock,
        ));
        continue;
      }

      if (inCodeBlock) {
        parsedLines.add(MarkdownLine(
          index: i,
          content: line,
          type: MarkdownLineType.codeBlock,
        ));
        continue;
      }

      parsedLines.add(_parseLine(i, line));
    }

    return parsedLines;
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

    final checkboxUnchecked = RegExp(r'^([\s]*)-\s+\[\s\]\s+(.+)$');
    final checkboxChecked = RegExp(r'^([\s]*)-\s+\[[xX]\]\s+(.+)$');

    final uncheckedMatch = checkboxUnchecked.firstMatch(line);
    if (uncheckedMatch != null) {
      return MarkdownLine(
        index: index,
        content: uncheckedMatch.group(2) ?? '',
        type: MarkdownLineType.checkbox,
        indentLevel: (uncheckedMatch.group(1)?.length ?? 0) ~/ 2,
        isChecked: false,
      );
    }

    final checkedMatch = checkboxChecked.firstMatch(line);
    if (checkedMatch != null) {
      return MarkdownLine(
        index: index,
        content: checkedMatch.group(2) ?? '',
        type: MarkdownLineType.checkbox,
        indentLevel: (checkedMatch.group(1)?.length ?? 0) ~/ 2,
        isChecked: true,
      );
    }

    if (trimmed.startsWith('- ') || trimmed.startsWith('* ') || trimmed.startsWith('• ')) {
      final indent = line.length - line.trimLeft().length;
      return MarkdownLine(
        index: index,
        content: trimmed.substring(2),
        type: MarkdownLineType.bulletList,
        indentLevel: indent ~/ 2,
      );
    }

    final numberedMatch = RegExp(r'^(\d+)\.\s+(.+)$').firstMatch(trimmed);
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

    final lines = _currentData.split('\n');
    if (lineIndex >= lines.length) return;

    final line = lines[lineIndex];
    final parsedLine = _parsedLines[lineIndex];

    String newLine;
    if (parsedLine.isChecked) {
      newLine = line.replaceFirst(RegExp(r'\[[xX]\]'), '[ ]');
    } else {
      newLine = line.replaceFirst('[ ]', '[x]');
    }

    lines[lineIndex] = newLine;
    final updatedContent = lines.join('\n');

    setState(() {
      _currentData = updatedContent;
      _parsedLines = _parseMarkdown(_currentData);
    });

    widget.onCheckboxChanged!(updatedContent);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _parsedLines.length,
      cacheExtent: widget.cacheExtent.toDouble(),
      itemBuilder: (context, index) {
        final line = _parsedLines[index];
        return _buildLine(context, line);
      },
    );
  }

  Widget _buildLine(BuildContext context, MarkdownLine line) {
    switch (line.type) {
      case MarkdownLineType.empty:
        return const SizedBox(height: 16);

      case MarkdownLineType.heading1:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _buildSelectableText(
            line.content,
            widget.styleSheet?.h1 ??
                const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        );

      case MarkdownLineType.heading2:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _buildSelectableText(
            line.content,
            widget.styleSheet?.h2 ??
                const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        );

      case MarkdownLineType.heading3:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _buildSelectableText(
            line.content,
            widget.styleSheet?.h3 ??
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        );

      case MarkdownLineType.heading4:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _buildSelectableText(
            line.content,
            widget.styleSheet?.h4 ??
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        );

      case MarkdownLineType.heading5:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _buildSelectableText(
            line.content,
            widget.styleSheet?.h5 ??
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        );

      case MarkdownLineType.heading6:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _buildSelectableText(
            line.content,
            widget.styleSheet?.h6 ??
                const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        );

      case MarkdownLineType.checkbox:
        return _buildCheckbox(context, line);

      case MarkdownLineType.bulletList:
        return Padding(
          padding: EdgeInsets.only(left: 16.0 + line.indentLevel * 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 16)),
              Expanded(child: _buildRichText(line.content)),
            ],
          ),
        );

      case MarkdownLineType.numberedList:
        return Padding(
          padding: EdgeInsets.only(left: 16.0 + line.indentLevel * 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${line.listNumber}. ',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              Expanded(child: _buildRichText(line.content)),
            ],
          ),
        );

      case MarkdownLineType.quote:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.only(left: 16),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 4,
              ),
            ),
          ),
          child: _buildSelectableText(
            line.content,
            TextStyle(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        );

      case MarkdownLineType.codeBlock:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            line.content,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );

      case MarkdownLineType.horizontalRule:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(),
        );

      case MarkdownLineType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _buildRichText(line.content),
        );
    }
  }

  Widget _buildCheckbox(BuildContext context, MarkdownLine line) {
    return Padding(
      padding: EdgeInsets.only(left: line.indentLevel * 16.0, top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.onCheckboxChanged != null
                ? () => _toggleCheckbox(line.index)
                : null,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Icon(
                line.isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20,
                color: line.isChecked
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                  fontSize: 16,
                  decoration: line.isChecked ? TextDecoration.lineThrough : null,
                  color: line.isChecked
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
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

    if (widget.selectable) {
      return SelectableText.rich(TextSpan(children: spans));
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
        ),
      ),
    );
  }

  List<TextSpan> _parseInlineMarkdown(String text) {
    final spans = <TextSpan>[];
    final defaultStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: 16,
    );

    final patterns = [
      (RegExp(r'\*\*(.+?)\*\*'), const TextStyle(fontWeight: FontWeight.bold)),
      (RegExp(r'__(.+?)__'), const TextStyle(fontWeight: FontWeight.bold)),
      (RegExp(r'\*(.+?)\*'), const TextStyle(fontStyle: FontStyle.italic)),
      (RegExp(r'_(.+?)_'), const TextStyle(fontStyle: FontStyle.italic)),
      (RegExp(r'~~(.+?)~~'), const TextStyle(decoration: TextDecoration.lineThrough)),
      (RegExp(r'`(.+?)`'), TextStyle(
        fontFamily: 'monospace',
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      )),
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

      if (earliestMatch != null && earliestMatchStart != null && matchStyle != null) {
        if (earliestMatchStart > currentIndex) {
          spans.add(TextSpan(
            text: text.substring(currentIndex, earliestMatchStart),
            style: defaultStyle,
          ));
        }

        spans.add(TextSpan(
          text: earliestMatch.group(1),
          style: defaultStyle.merge(matchStyle),
        ));

        currentIndex = earliestMatchStart + earliestMatch.group(0)!.length;
      } else {
        spans.add(TextSpan(
          text: text.substring(currentIndex),
          style: defaultStyle,
        ));
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
    this.previewFontSize = 16.0,
    this.showLineNumbers = false,
  });

  @override
  State<EfficientMarkdownEditor> createState() => _EfficientMarkdownEditorState();
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
        h1: TextStyle(fontSize: widget.previewFontSize * 2, fontWeight: FontWeight.bold),
        h2: TextStyle(fontSize: widget.previewFontSize * 1.5, fontWeight: FontWeight.bold),
        h3: TextStyle(fontSize: widget.previewFontSize * 1.25, fontWeight: FontWeight.bold),
      ),
    );
  }
}
