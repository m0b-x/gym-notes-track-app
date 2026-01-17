// NOTE: This widget is only used for displaying markdown in dialogs (not in the main editor preview).
// If you are looking for the main preview implementation, see SourceMappedMarkdownView.
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../constants/font_constants.dart';
import '../constants/markdown_constants.dart';

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

class FullMarkdownView extends StatefulWidget {
  final String data;
  final Function(CheckboxToggleInfo)? onCheckboxToggle;
  final MarkdownStyleSheet? styleSheet;
  final bool selectable;
  final ScrollController? scrollController;
  final EdgeInsets? padding;
  final MarkdownTapLinkCallback? onTapLink;

  const FullMarkdownView({
    super.key,
    required this.data,
    this.onCheckboxToggle,
    this.styleSheet,
    this.selectable = false,
    this.scrollController,
    this.padding,
    this.onTapLink,
  });

  @override
  State<FullMarkdownView> createState() => _FullMarkdownViewState();
}

class _FullMarkdownViewState extends State<FullMarkdownView> {
  late String _currentData;
  List<_CheckboxInfo>? _cachedCheckboxes;
  String? _lastDataForCache;
  int _buildCallIndex = 0;

  static final _checkboxPattern = RegExp(
    r'^([\s]*)-\s+\[([xX\s])\]\s+(.*)$',
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
      if (_lastDataForCache != _currentData) {
        _cachedCheckboxes = null;
      }
    }
  }

  void _parseCheckboxes() {
    if (_lastDataForCache == _currentData && _cachedCheckboxes != null) {
      return;
    }

    final checkboxes = <_CheckboxInfo>[];
    int currentPos = 0;
    int lineIndex = 0;

    for (final line in _currentData.split('\n')) {
      final match = _checkboxPattern.firstMatch(line);
      if (match != null) {
        final isChecked = match.group(2)?.toLowerCase() == 'x';
        checkboxes.add(
          _CheckboxInfo(
            lineIndex: lineIndex,
            charOffset: currentPos,
            isChecked: isChecked,
          ),
        );
      }
      currentPos += line.length + 1;
      lineIndex++;
    }

    _cachedCheckboxes = checkboxes;
    _lastDataForCache = _currentData;
  }

  void _toggleCheckbox(int checkboxIndex) {
    if (widget.onCheckboxToggle == null) return;
    _parseCheckboxes();
    if (checkboxIndex < 0 || checkboxIndex >= _cachedCheckboxes!.length) return;

    final checkbox = _cachedCheckboxes![checkboxIndex];
    final lines = _currentData.split('\n');
    if (checkbox.lineIndex >= lines.length) return;

    final line = lines[checkbox.lineIndex];
    final checkboxPatternInLine = checkbox.isChecked
        ? RegExp(r'\[[xX]\]')
        : RegExp(r'\[ \]');
    final match = checkboxPatternInLine.firstMatch(line);
    if (match == null) return;

    final absoluteStart = checkbox.charOffset + match.start;
    final absoluteEnd = checkbox.charOffset + match.end;
    final replacement = checkbox.isChecked ? '[ ]' : '[x]';

    if (checkbox.isChecked) {
      lines[checkbox.lineIndex] = line.replaceFirst(RegExp(r'\[[xX]\]'), '[ ]');
    } else {
      lines[checkbox.lineIndex] = line.replaceFirst('[ ]', '[x]');
    }
    final updatedContent = lines.join('\n');

    setState(() {
      _currentData = updatedContent;
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

  @override
  Widget build(BuildContext context) {
    _parseCheckboxes();
    _buildCallIndex = 0;

    final hasInteractiveCheckboxes =
        widget.onCheckboxToggle != null && _cachedCheckboxes!.isNotEmpty;

    return Markdown(
      key: hasInteractiveCheckboxes ? ValueKey(_currentData.hashCode) : null,
      data: _currentData,
      controller: widget.scrollController,
      styleSheet: widget.styleSheet,
      selectable: widget.selectable,
      padding: widget.padding ?? const EdgeInsets.all(16.0),
      onTapLink: widget.onTapLink,
      softLineBreak: true,
      listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.start,
      checkboxBuilder: hasInteractiveCheckboxes ? _buildCheckbox : null,
    );
  }

  Widget _buildCheckbox(bool checked) {
    final checkboxIndex = _buildCallIndex;
    _buildCallIndex++;

    final baseFontSize =
        widget.styleSheet?.p?.fontSize ?? FontConstants.defaultFontSize;

    return GestureDetector(
      onTap: () => _toggleCheckbox(checkboxIndex),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Icon(
          checked ? Icons.check_box : Icons.check_box_outline_blank,
          size: baseFontSize * MarkdownConstants.checkboxIconScale,
          color: checked
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: MarkdownConstants.uncheckedCheckboxOpacity,
                ),
        ),
      ),
    );
  }
}

class _CheckboxInfo {
  final int lineIndex;
  final int charOffset;
  final bool isChecked;

  const _CheckboxInfo({
    required this.lineIndex,
    required this.charOffset,
    required this.isChecked,
  });
}
