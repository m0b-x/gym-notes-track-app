import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../constants/app_spacing.dart';
import '../constants/font_constants.dart';
import '../constants/markdown_constants.dart';

/// Info for efficient checkbox toggle via replaceRange
class CheckboxToggleInfo {
  final int start;
  final int end;
  final String replacement;

  const CheckboxToggleInfo({
    required this.start,
    required this.end,
    required this.replacement,
  });
}

/// Search match for preview mode
class PreviewSearchMatch {
  final int start;
  final int end;

  const PreviewSearchMatch({required this.start, required this.end});

  int get length => end - start;
}

/// Full-featured markdown view using flutter_markdown_plus
/// with custom checkbox handling for toggle callbacks and search highlighting
class FullMarkdownView extends StatefulWidget {
  final String data;
  final Function(CheckboxToggleInfo)? onCheckboxToggle;
  final MarkdownStyleSheet? styleSheet;
  final bool selectable;
  final ScrollController? scrollController;
  final EdgeInsets? padding;
  final MarkdownTapLinkCallback? onTapLink;

  // Search highlighting
  final String? searchQuery;
  final int currentMatchIndex;
  final bool caseSensitive;
  final Color? highlightColor;
  final Color? currentMatchColor;

  const FullMarkdownView({
    super.key,
    required this.data,
    this.onCheckboxToggle,
    this.styleSheet,
    this.selectable = false,
    this.scrollController,
    this.padding,
    this.onTapLink,
    this.searchQuery,
    this.currentMatchIndex = -1,
    this.caseSensitive = false,
    this.highlightColor,
    this.currentMatchColor,
  });

  /// Calculate all search matches in the given text
  static List<PreviewSearchMatch> findMatches(
    String text,
    String query, {
    bool caseSensitive = false,
  }) {
    if (query.isEmpty) return [];

    final matches = <PreviewSearchMatch>[];
    final searchText = caseSensitive ? text : text.toLowerCase();
    final searchQuery = caseSensitive ? query : query.toLowerCase();

    int index = 0;
    while (true) {
      index = searchText.indexOf(searchQuery, index);
      if (index == -1) break;
      matches.add(PreviewSearchMatch(start: index, end: index + query.length));
      index += query.length;
    }

    return matches;
  }

  @override
  State<FullMarkdownView> createState() => _FullMarkdownViewState();
}

class _FullMarkdownViewState extends State<FullMarkdownView> {
  late String _currentData;

  // Cache for parsed content
  String? _cachedNonCheckboxContent;
  List<_CheckboxInfo>? _cachedCheckboxes;
  String? _lastDataForCache;

  // Pre-compiled pattern for checkboxes
  static final _checkboxPattern = RegExp(
    r'^([\s]*)-\s+\[([xX\s])\]\s+(.+)$',
    multiLine: true,
  );

  @override
  void initState() {
    super.initState();
    _currentData = widget.data;
  }

  @override
  void didUpdateWidget(FullMarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _currentData = widget.data;
      // Invalidate cache when data changes
      if (_lastDataForCache != _currentData) {
        _cachedNonCheckboxContent = null;
        _cachedCheckboxes = null;
      }
    }
  }

  void _parseContent() {
    if (_lastDataForCache == _currentData &&
        _cachedNonCheckboxContent != null &&
        _cachedCheckboxes != null) {
      return; // Use cached values
    }

    final lines = _currentData.split('\n');
    final checkboxes = <_CheckboxInfo>[];
    final nonCheckboxLines = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final match = _checkboxPattern.firstMatch(line);

      if (match != null) {
        final indent = match.group(1)?.length ?? 0;
        final isChecked = match.group(2)?.toLowerCase() == 'x';
        final text = match.group(3) ?? '';

        checkboxes.add(
          _CheckboxInfo(
            lineIndex: i,
            placeholderIndex: nonCheckboxLines.length,
            indent: indent,
            isChecked: isChecked,
            text: text,
          ),
        );
        // Add empty line as placeholder to maintain structure
        nonCheckboxLines.add('');
      } else {
        nonCheckboxLines.add(line);
      }
    }

    _cachedNonCheckboxContent = nonCheckboxLines.join('\n');
    _cachedCheckboxes = checkboxes;
    _lastDataForCache = _currentData;
  }

  @override
  Widget build(BuildContext context) {
    _parseContent();

    // If no checkboxes, use the built-in Markdown widget directly
    if (_cachedCheckboxes!.isEmpty) {
      return _buildMarkdownWidget(_currentData);
    }

    // Build with custom checkboxes interspersed
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: widget.padding ?? EdgeInsets.zero,
      child: _buildContentWithCheckboxes(context),
    );
  }

  Widget _buildMarkdownWidget(String data) {
    return Markdown(
      data: data,
      controller: widget.scrollController,
      styleSheet: widget.styleSheet,
      selectable: widget.selectable,
      padding: widget.padding ?? const EdgeInsets.all(16.0),
      onTapLink: widget.onTapLink,
      softLineBreak: true,
    );
  }

  Widget _buildContentWithCheckboxes(BuildContext context) {
    final lines = _currentData.split('\n');
    final widgets = <Widget>[];
    int currentLine = 0;
    int checkboxIdx = 0;

    while (currentLine < lines.length) {
      // Check if current line is a checkbox
      if (checkboxIdx < _cachedCheckboxes!.length &&
          _cachedCheckboxes![checkboxIdx].lineIndex == currentLine) {
        final checkbox = _cachedCheckboxes![checkboxIdx];
        widgets.add(
          _buildCheckboxItem(
            context,
            checkbox.lineIndex,
            checkbox.isChecked,
            checkbox.text,
            checkbox.indent,
          ),
        );
        checkboxIdx++;
        currentLine++;
      } else {
        // Collect consecutive non-checkbox lines
        final startLine = currentLine;
        while (currentLine < lines.length &&
            (checkboxIdx >= _cachedCheckboxes!.length ||
                _cachedCheckboxes![checkboxIdx].lineIndex != currentLine)) {
          currentLine++;
        }

        // Render non-checkbox lines
        final contentLines = lines.sublist(startLine, currentLine);
        _addMarkdownBlocks(context, contentLines, widgets);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  void _addMarkdownBlocks(
    BuildContext context,
    List<String> lines,
    List<Widget> widgets,
  ) {
    int i = 0;
    while (i < lines.length) {
      if (lines[i].trim().isEmpty) {
        int emptyCount = 0;
        while (i < lines.length && lines[i].trim().isEmpty) {
          emptyCount++;
          i++;
        }
        if (emptyCount > 0) {
          widgets.add(SizedBox(height: AppSpacing.lg * emptyCount));
        }
      } else {
        final startIdx = i;
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          i++;
        }
        final content = lines.sublist(startIdx, i).join('\n');
        widgets.add(
          MarkdownBody(
            data: content,
            styleSheet: widget.styleSheet,
            selectable: widget.selectable,
            onTapLink: widget.onTapLink,
            softLineBreak: true,
            fitContent: true,
          ),
        );
      }
    }
  }

  Widget _buildCheckboxItem(
    BuildContext context,
    int lineIndex,
    bool isChecked,
    String text,
    int indent,
  ) {
    final baseFontSize =
        widget.styleSheet?.p?.fontSize ?? FontConstants.defaultFontSize;
    final lineHeight = widget.styleSheet?.p?.height;

    return Padding(
      padding: EdgeInsets.only(
        left: indent * MarkdownConstants.indentPerLevel,
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: widget.onCheckboxToggle != null
                ? () => _toggleCheckbox(lineIndex, isChecked)
                : null,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Icon(
                isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                size: baseFontSize * MarkdownConstants.checkboxIconScale,
                color: isChecked
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(
                        alpha: MarkdownConstants.uncheckedCheckboxOpacity,
                      ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: widget.onCheckboxToggle != null
                  ? () => _toggleCheckbox(lineIndex, isChecked)
                  : null,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: baseFontSize,
                  height: lineHeight,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  decorationColor: isChecked
                      ? Theme.of(context).colorScheme.onSurface.withValues(
                          alpha: MarkdownConstants.checkedTextOpacity,
                        )
                      : null,
                  color: isChecked
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

  void _toggleCheckbox(int lineIndex, bool currentlyChecked) {
    final lines = _currentData.split('\n');
    if (lineIndex >= lines.length) return;

    final line = lines[lineIndex];

    // Calculate character offset to the start of this line
    int lineStart = 0;
    for (int i = 0; i < lineIndex; i++) {
      lineStart += lines[i].length + 1; // +1 for \n
    }

    // Find the checkbox bracket position within the line
    final checkboxPattern = currentlyChecked
        ? RegExp(r'\[[xX]\]')
        : RegExp(r'\[ \]');
    final match = checkboxPattern.firstMatch(line);
    if (match == null) return;

    final absoluteStart = lineStart + match.start;
    final absoluteEnd = lineStart + match.end;
    final replacement = currentlyChecked ? '[ ]' : '[x]';

    // Update local state
    if (currentlyChecked) {
      lines[lineIndex] = line.replaceFirst(RegExp(r'\[[xX]\]'), '[ ]');
    } else {
      lines[lineIndex] = line.replaceFirst('[ ]', '[x]');
    }
    final updatedContent = lines.join('\n');

    setState(() {
      _currentData = updatedContent;
      _cachedNonCheckboxContent = null;
      _cachedCheckboxes = null;
      _lastDataForCache = null;
    });

    widget.onCheckboxToggle?.call(
      CheckboxToggleInfo(
        start: absoluteStart,
        end: absoluteEnd,
        replacement: replacement,
      ),
    );
  }
}

/// Helper class to store checkbox information
class _CheckboxInfo {
  final int lineIndex;
  final int placeholderIndex;
  final int indent;
  final bool isChecked;
  final String text;

  const _CheckboxInfo({
    required this.lineIndex,
    required this.placeholderIndex,
    required this.indent,
    required this.isChecked,
    required this.text,
  });
}
