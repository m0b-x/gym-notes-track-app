import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class InteractiveMarkdown extends StatefulWidget {
  final String data;
  final Function(String)? onCheckboxChanged;
  final MarkdownStyleSheet? styleSheet;
  final bool selectable;
  final EdgeInsets? padding;
  final ScrollController? scrollController;
  final int? selectedLine;
  final Function(int)? onLineTap;

  const InteractiveMarkdown({
    super.key,
    required this.data,
    this.onCheckboxChanged,
    this.styleSheet,
    this.selectable = false,
    this.padding,
    this.scrollController,
    this.selectedLine,
    this.onLineTap,
  });

  @override
  State<InteractiveMarkdown> createState() => _InteractiveMarkdownState();
}

class _InteractiveMarkdownState extends State<InteractiveMarkdown> {
  late String _currentData;

  @override
  void initState() {
    super.initState();
    _currentData = widget.data;
  }

  @override
  void didUpdateWidget(InteractiveMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _currentData = widget.data;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: widget.padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildContent(context),
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context) {
    final lines = _currentData.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();
      final isSelected = widget.selectedLine == i;

      final uncheckedPattern = RegExp(r'^([\s]*)-\s+\[\s\]\s+(.+)$');
      final checkedPattern = RegExp(r'^([\s]*)-\s+\[[xX]\]\s+(.+)$');

      final uncheckedMatch = uncheckedPattern.firstMatch(line);
      final checkedMatch = checkedPattern.firstMatch(line);

      final bulletPattern = RegExp(r'^([\s]*)[-*•]\s+(.+)$');
      final bulletMatch = bulletPattern.firstMatch(line);

      final numberedPattern = RegExp(r'^([\s]*)(\d+)\.\s+(.+)$');
      final numberedMatch = numberedPattern.firstMatch(line);

      Widget lineWidget;

      if (uncheckedMatch != null) {
        final indent = uncheckedMatch.group(1)?.length ?? 0;
        final text = uncheckedMatch.group(2) ?? '';
        lineWidget = _buildCheckboxItem(context, i, false, text, indent);
      } else if (checkedMatch != null) {
        final indent = checkedMatch.group(1)?.length ?? 0;
        final text = checkedMatch.group(2) ?? '';
        lineWidget = _buildCheckboxItem(context, i, true, text, indent);
      } else if (bulletMatch != null) {
        final indent = bulletMatch.group(1)?.length ?? 0;
        final text = bulletMatch.group(2) ?? '';
        lineWidget = _buildBulletItem(context, text, indent);
      } else if (numberedMatch != null) {
        final indent = numberedMatch.group(1)?.length ?? 0;
        final number = numberedMatch.group(2) ?? '1';
        final text = numberedMatch.group(3) ?? '';
        lineWidget = _buildNumberedItem(context, text, number, indent);
      } else if (trimmedLine.isEmpty) {
        lineWidget = const SizedBox(height: 16);
      } else {
        lineWidget = _buildMarkdownLine(context, line);
      }

      widgets.add(_wrapWithSelection(context, lineWidget, i, isSelected));
    }

    return widgets;
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

  Widget _buildMarkdownLine(BuildContext context, String line) {
    return Markdown(
      data: line,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      styleSheet: widget.styleSheet,
      selectable: widget.selectable,
      padding: EdgeInsets.zero,
      softLineBreak: true,
    );
  }

  Widget _buildBulletItem(BuildContext context, String text, int indent) {
    final baseFontSize = widget.styleSheet?.p?.fontSize ?? 16;
    return Padding(
      padding: EdgeInsets.only(
        left: 16.0 + (indent ~/ 2) * 16.0,
        top: 4,
        bottom: 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 2),
            child: Text('•', style: TextStyle(fontSize: baseFontSize)),
          ),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: baseFontSize)),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedItem(
    BuildContext context,
    String text,
    String number,
    int indent,
  ) {
    final baseFontSize = widget.styleSheet?.p?.fontSize ?? 16;
    return Padding(
      padding: EdgeInsets.only(
        left: 16.0 + (indent ~/ 2) * 16.0,
        top: 4,
        bottom: 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 2),
            child: SizedBox(
              width: 20,
              child: Text('$number.', style: TextStyle(fontSize: baseFontSize)),
            ),
          ),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: baseFontSize)),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxItem(
    BuildContext context,
    int lineIndex,
    bool isChecked,
    String text,
    int indent,
  ) {
    final baseFontSize = widget.styleSheet?.p?.fontSize ?? 16;
    return Padding(
      padding: EdgeInsets.only(left: indent * 16.0, top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: widget.onCheckboxChanged != null
                ? () => _toggleCheckbox(lineIndex, isChecked)
                : null,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                size: baseFontSize * 1.25,
                color: isChecked
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: widget.onCheckboxChanged != null
                  ? () => _toggleCheckbox(lineIndex, isChecked)
                  : null,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: baseFontSize,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  decorationColor: isChecked
                      ? Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5)
                      : null,
                  color: isChecked
                      ? Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleCheckbox(int lineIndex, bool currentlyChecked) {
    final lines = _currentData.split('\n');

    if (lineIndex < lines.length) {
      final line = lines[lineIndex];

      if (currentlyChecked) {
        lines[lineIndex] = line.replaceFirst(RegExp(r'\[[xX]\]'), '[ ]');
      } else {
        lines[lineIndex] = line.replaceFirst('[ ]', '[x]');
      }

      final updatedContent = lines.join('\n');

      setState(() {
        _currentData = updatedContent;
      });

      if (widget.onCheckboxChanged != null) {
        widget.onCheckboxChanged!(updatedContent);
      }
    }
  }
}
