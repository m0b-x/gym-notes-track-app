import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// A custom markdown widget that allows interactive checkboxes
/// User can tap on checkboxes to toggle between checked and unchecked states
class InteractiveMarkdown extends StatefulWidget {
  final String data;
  final Function(String)? onCheckboxChanged;
  final MarkdownStyleSheet? styleSheet;
  final bool selectable;
  final EdgeInsets? padding;

  const InteractiveMarkdown({
    super.key,
    required this.data,
    this.onCheckboxChanged,
    this.styleSheet,
    this.selectable = false,
    this.padding,
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
    // Parse and build custom widgets for checkboxes
    return SingleChildScrollView(
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
    final List<String> pendingLines = [];

    void flushPendingLines() {
      if (pendingLines.isNotEmpty) {
        widgets.add(
          Markdown(
            data: pendingLines.join('\n'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            styleSheet: widget.styleSheet,
            selectable: widget.selectable,
            padding: EdgeInsets.zero,
            softLineBreak: true,
          ),
        );
        pendingLines.clear();
      }
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      // Check for checkbox patterns
      final uncheckedPattern = RegExp(r'^([\s]*)-\s+\[\s\]\s+(.+)$');
      final checkedPattern = RegExp(r'^([\s]*)-\s+\[[xX]\]\s+(.+)$');

      final uncheckedMatch = uncheckedPattern.firstMatch(line);
      final checkedMatch = checkedPattern.firstMatch(line);

      // Check for bullet list patterns (- , * , • )
      final bulletPattern = RegExp(r'^([\s]*)[-*•]\s+(.+)$');
      final bulletMatch = bulletPattern.firstMatch(line);
      
      // Check for numbered list patterns (1. , 2. , etc.)
      final numberedPattern = RegExp(r'^([\s]*)(\d+)\.\s+(.+)$');
      final numberedMatch = numberedPattern.firstMatch(line);

      if (uncheckedMatch != null) {
        flushPendingLines();
        final indent = uncheckedMatch.group(1)?.length ?? 0;
        final text = uncheckedMatch.group(2) ?? '';
        widgets.add(_buildCheckboxItem(context, i, false, text, indent));
      } else if (checkedMatch != null) {
        flushPendingLines();
        final indent = checkedMatch.group(1)?.length ?? 0;
        final text = checkedMatch.group(2) ?? '';
        widgets.add(_buildCheckboxItem(context, i, true, text, indent));
      } else if (bulletMatch != null) {
        // Manually render bullet list item
        flushPendingLines();
        final indent = bulletMatch.group(1)?.length ?? 0;
        final text = bulletMatch.group(2) ?? '';
        widgets.add(_buildBulletItem(context, text, indent));
      } else if (numberedMatch != null) {
        // Manually render numbered list item
        flushPendingLines();
        final indent = numberedMatch.group(1)?.length ?? 0;
        final number = numberedMatch.group(2) ?? '1';
        final text = numberedMatch.group(3) ?? '';
        widgets.add(_buildNumberedItem(context, text, number, indent));
      } else {
        // Regular line - accumulate for batch markdown rendering
        if (trimmedLine.isNotEmpty) {
          pendingLines.add(line);
        } else {
          // Empty line - flush pending and add spacing
          flushPendingLines();
          widgets.add(const SizedBox(height: 16));
        }
      }
    }

    // Flush any remaining lines
    flushPendingLines();

    return widgets;
  }

  Widget _buildBulletItem(BuildContext context, String text, int indent) {
    return Padding(
      padding: EdgeInsets.only(left: 16.0 + (indent ~/ 2) * 16.0, top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8, top: 2),
            child: Text('•', style: TextStyle(fontSize: 16)),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedItem(BuildContext context, String text, String number, int indent) {
    return Padding(
      padding: EdgeInsets.only(left: 16.0 + (indent ~/ 2) * 16.0, top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 2),
            child: SizedBox(
              width: 20,
              child: Text('$number.', style: const TextStyle(fontSize: 16)),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
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
    return Padding(
      padding: EdgeInsets.only(left: indent * 16.0, top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.onCheckboxChanged != null
                ? () => _toggleCheckbox(lineIndex, isChecked)
                : null,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Icon(
                isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20,
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
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
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
