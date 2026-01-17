import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

import '../constants/markdown_constants.dart';

typedef LinkTapCallback = void Function(String url);
typedef CheckboxTapCallback = void Function(int start, int end, bool isChecked);

class MarkdownStyle {
  final double baseFontSize;
  final Color textColor;
  final Color primaryColor;
  final Color codeBackground;
  final Color blockquoteColor;
  final Color tableBorderColor;
  final Color highlightColor;
  final Color currentHighlightColor;

  const MarkdownStyle({
    required this.baseFontSize,
    required this.textColor,
    required this.primaryColor,
    required this.codeBackground,
    required this.blockquoteColor,
    required this.tableBorderColor,
    required this.highlightColor,
    required this.currentHighlightColor,
  });

  factory MarkdownStyle.fromTheme(ThemeData theme, double fontSize) {
    final isDark = theme.brightness == Brightness.dark;
    return MarkdownStyle(
      baseFontSize: fontSize,
      textColor: theme.textTheme.bodyLarge?.color ?? Colors.black,
      primaryColor: theme.colorScheme.primary,
      codeBackground: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
      blockquoteColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
      tableBorderColor: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
      highlightColor: theme.colorScheme.primaryContainer,
      currentHighlightColor: theme.colorScheme.primary.withValues(alpha: 0.5),
    );
  }
}

class MarkdownSpanBuilder {
  final MarkdownStyle style;
  final LinkTapCallback? onLinkTap;
  final CheckboxTapCallback? onCheckboxTap;
  final List<TextRange>? searchHighlights;
  final int? currentHighlightIndex;

  late String _source;
  int _sourceOffset = 0;
  final List<_CheckboxData> _checkboxes = [];

  /// Maps (blockIndex, localCheckboxIndex) to checkbox data.
  /// Stored as "blockIndex:localIndex" strings to avoid object references.
  final Map<String, _CheckboxData> _nodeCheckboxMap = {};

  /// Tracks which block we're currently building spans for.
  int _currentBuildingBlock = -1;

  /// Counter for checkboxes within the current block being built.
  int _blockCheckboxCounter = 0;

  static final _checkboxLinePattern = RegExp(r'^(\s*)-\s+\[([xX\s])\]\s');

  MarkdownSpanBuilder({
    required this.style,
    this.onLinkTap,
    this.onCheckboxTap,
    this.searchHighlights,
    this.currentHighlightIndex,
  });

  /// Parse markdown and return AST nodes (cheap operation)
  /// Returns a LazyMarkdownBlocks that builds spans on demand
  LazyMarkdownBlocks buildLazy(String source) {
    _source = source; // Keep original for checkbox position calculations
    _sourceOffset = 0;
    _checkboxes.clear();
    _nodeCheckboxMap.clear();

    _parseCheckboxPositions();

    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    );

    final nodes = document.parse(source);

    // Pre-assign checkbox data to blocks in document order.
    // Maps "blockIndex:localCheckboxIndex" to checkbox data.
    int globalCheckboxIndex = 0;
    for (int blockIdx = 0; blockIdx < nodes.length; blockIdx++) {
      globalCheckboxIndex = _assignCheckboxesToBlock(
        nodes[blockIdx],
        globalCheckboxIndex,
        blockIdx,
      );
    }

    return LazyMarkdownBlocks(
      nodes: nodes,
      builder: this,
      baseStyle: _baseStyle,
      blankLineMarker: null, // No longer using blank line markers
    );
  }

  /// Counts checkboxes in a block and assigns their data.
  int _assignCheckboxesToBlock(
    md.Node node,
    int globalCheckboxIndex,
    int blockIndex,
  ) {
    int localIndex = 0;

    void traverse(md.Node n) {
      if (n is md.Element) {
        if (n.tag == 'li' && _hasCheckboxChild(n)) {
          if (globalCheckboxIndex < _checkboxes.length) {
            _nodeCheckboxMap['$blockIndex:$localIndex'] =
                _checkboxes[globalCheckboxIndex];
            globalCheckboxIndex++;
            localIndex++;
          }
        }
        for (final child in n.children ?? []) {
          traverse(child);
        }
      }
    }

    traverse(node);
    return globalCheckboxIndex;
  }

  /// Build spans for a single AST node (called lazily)
  /// [blockIndex] is used to look up pre-computed checkbox positions.
  List<InlineSpan> buildNodeSpans(
    md.Node node,
    TextStyle baseStyle, [
    int blockIndex = 0,
  ]) {
    _currentBuildingBlock = blockIndex;
    _blockCheckboxCounter = 0;
    // Reset source offset for each block since blocks may be built out of order
    // due to lazy rendering. This allows _findSourceOffset to search from the
    // beginning of the source for each block.
    _sourceOffset = 0;
    return _buildNode(node, baseStyle);
  }

  void _parseCheckboxPositions() {
    final lines = _source.split('\n');
    int offset = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final match = _checkboxLinePattern.firstMatch(line);

      if (match != null) {
        final indent = match.group(1) ?? '';
        final checkState = match.group(2)!;
        final bracketStart = offset + indent.length + 2;

        _checkboxes.add(
          _CheckboxData(
            lineIndex: i,
            bracketStart: bracketStart,
            bracketEnd: bracketStart + 3,
            isChecked: checkState.toLowerCase() == 'x',
          ),
        );
      }

      offset += line.length + 1;
    }
  }

  TextStyle get _baseStyle => TextStyle(
    fontSize: style.baseFontSize,
    height: MarkdownConstants.lineHeight,
    color: style.textColor,
  );

  List<InlineSpan> _buildNode(md.Node node, TextStyle currentStyle) {
    if (node is md.Text) {
      return [_buildTextSpan(node.text, currentStyle)];
    }

    if (node is md.Element) {
      return _buildElement(node, currentStyle);
    }

    return [];
  }

  List<InlineSpan> _buildElement(md.Element element, TextStyle currentStyle) {
    switch (element.tag) {
      case 'h1':
        return _buildBlock(
          element,
          currentStyle.copyWith(
            fontSize: style.baseFontSize * MarkdownConstants.h1Scale,
            fontWeight: FontWeight.bold,
          ),
          addNewline: true,
        );

      case 'h2':
        return _buildBlock(
          element,
          currentStyle.copyWith(
            fontSize: style.baseFontSize * MarkdownConstants.h2Scale,
            fontWeight: FontWeight.bold,
          ),
          addNewline: true,
        );

      case 'h3':
        return _buildBlock(
          element,
          currentStyle.copyWith(
            fontSize: style.baseFontSize * MarkdownConstants.h3Scale,
            fontWeight: FontWeight.bold,
          ),
          addNewline: true,
        );

      case 'h4':
        return _buildBlock(
          element,
          currentStyle.copyWith(
            fontSize: style.baseFontSize * MarkdownConstants.h4Scale,
            fontWeight: FontWeight.bold,
          ),
          addNewline: true,
        );

      case 'h5':
        return _buildBlock(
          element,
          currentStyle.copyWith(
            fontSize: style.baseFontSize * MarkdownConstants.h5Scale,
            fontWeight: FontWeight.bold,
          ),
          addNewline: true,
        );

      case 'h6':
        return _buildBlock(
          element,
          currentStyle.copyWith(
            fontSize: style.baseFontSize * MarkdownConstants.h6Scale,
            fontWeight: FontWeight.bold,
          ),
          addNewline: true,
        );

      case 'p':
        return _buildBlock(element, currentStyle, addNewline: true);

      case 'strong':
      case 'b':
        return _buildInline(
          element,
          currentStyle.copyWith(fontWeight: FontWeight.bold),
        );

      case 'em':
      case 'i':
        return _buildInline(
          element,
          currentStyle.copyWith(fontStyle: FontStyle.italic),
        );

      case 'del':
      case 's':
        return _buildInline(
          element,
          currentStyle.copyWith(decoration: TextDecoration.lineThrough),
        );

      case 'code':
        return _buildInlineCode(element, currentStyle);

      case 'pre':
        return _buildCodeBlock(element, currentStyle);

      case 'a':
        return _buildLink(element, currentStyle);

      case 'ul':
        return _buildUnorderedList(element, currentStyle);

      case 'ol':
        return _buildOrderedList(element, currentStyle);

      case 'li':
        return _buildListItem(element, currentStyle);

      case 'blockquote':
        return _buildBlockquote(element, currentStyle);

      case 'hr':
        return _buildHorizontalRule(currentStyle);

      case 'table':
        return _buildTable(element, currentStyle);

      case 'br':
        return [const TextSpan(text: '\n')];

      case 'input':
        return _buildCheckbox(element, currentStyle);

      default:
        return _buildChildren(element, currentStyle);
    }
  }

  List<InlineSpan> _buildBlock(
    md.Element element,
    TextStyle blockStyle, {
    bool addNewline = false,
  }) {
    final spans = <InlineSpan>[];
    spans.addAll(_buildChildren(element, blockStyle));

    if (addNewline) {
      spans.add(TextSpan(text: '\n\n', style: blockStyle));
    }

    return spans;
  }

  List<InlineSpan> _buildInline(md.Element element, TextStyle inlineStyle) {
    return _buildChildren(element, inlineStyle);
  }

  List<InlineSpan> _buildChildren(md.Element element, TextStyle style) {
    final spans = <InlineSpan>[];

    if (element.children != null) {
      for (final child in element.children!) {
        spans.addAll(_buildNode(child, style));
      }
    }

    return spans;
  }

  TextSpan _buildTextSpan(String text, TextStyle style) {
    if (searchHighlights == null || searchHighlights!.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final sourceStart = _findSourceOffset(text);
    if (sourceStart == -1) {
      return TextSpan(text: text, style: style);
    }

    final sourceEnd = sourceStart + text.length;
    final overlapping = <_HighlightRange>[];

    for (int i = 0; i < searchHighlights!.length; i++) {
      final h = searchHighlights![i];
      if (h.start < sourceEnd && h.end > sourceStart) {
        overlapping.add(
          _HighlightRange(
            start: (h.start - sourceStart).clamp(0, text.length),
            end: (h.end - sourceStart).clamp(0, text.length),
            isCurrent: i == currentHighlightIndex,
          ),
        );
      }
    }

    if (overlapping.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    overlapping.sort((a, b) => a.start.compareTo(b.start));

    final children = <TextSpan>[];
    int pos = 0;

    for (final range in overlapping) {
      if (range.start > pos) {
        children.add(TextSpan(text: text.substring(pos, range.start)));
      }

      final bgColor = range.isCurrent
          ? this.style.currentHighlightColor
          : this.style.highlightColor;
      children.add(
        TextSpan(
          text: text.substring(range.start, range.end),
          style: TextStyle(backgroundColor: bgColor),
        ),
      );

      pos = range.end;
    }

    if (pos < text.length) {
      children.add(TextSpan(text: text.substring(pos)));
    }

    return TextSpan(style: style, children: children);
  }

  int _findSourceOffset(String text) {
    final index = _source.indexOf(text, _sourceOffset);
    if (index != -1) {
      _sourceOffset = index + text.length;
    }
    return index;
  }

  List<InlineSpan> _buildInlineCode(md.Element element, TextStyle baseStyle) {
    final text = element.textContent;
    final codeStyle = baseStyle.copyWith(
      fontFamily: 'monospace',
      fontSize: baseStyle.fontSize! * 0.9,
      backgroundColor: style.codeBackground,
    );
    // Use _buildTextSpan to support search highlighting in inline code
    return [_buildTextSpan(text, codeStyle)];
  }

  List<InlineSpan> _buildCodeBlock(md.Element element, TextStyle baseStyle) {
    String? language;
    String code = '';

    if (element.children != null && element.children!.isNotEmpty) {
      final codeElement = element.children!.first;
      if (codeElement is md.Element && codeElement.tag == 'code') {
        language = codeElement.attributes['class']?.replaceFirst(
          'language-',
          '',
        );
        code = codeElement.textContent;
      } else {
        code = element.textContent;
      }
    }

    final codeStyle = baseStyle.copyWith(
      fontFamily: 'monospace',
      fontSize: style.baseFontSize * 0.85,
      color: _getCodeColor(language),
    );

    return [
      WidgetSpan(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: style.codeBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (language != null && language.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    language.toUpperCase(),
                    style: TextStyle(
                      fontSize: style.baseFontSize * 0.7,
                      fontWeight: FontWeight.bold,
                      color: style.textColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              SelectableText(code.trimRight(), style: codeStyle),
            ],
          ),
        ),
      ),
      const TextSpan(text: '\n'),
    ];
  }

  Color _getCodeColor(String? language) {
    if (language == null) return style.textColor;

    return switch (language.toLowerCase()) {
      'dart' || 'flutter' => Colors.blue.shade700,
      'javascript' || 'js' || 'typescript' || 'ts' => Colors.amber.shade700,
      'python' || 'py' => Colors.green.shade700,
      'rust' || 'rs' => Colors.orange.shade700,
      'go' => Colors.cyan.shade700,
      'java' || 'kotlin' => Colors.red.shade700,
      'swift' => Colors.orange.shade600,
      'sql' => Colors.purple.shade700,
      'json' || 'yaml' || 'yml' => Colors.teal.shade700,
      'html' || 'css' || 'xml' => Colors.pink.shade700,
      'bash' || 'sh' || 'shell' || 'zsh' => Colors.grey.shade700,
      _ => style.textColor,
    };
  }

  List<InlineSpan> _buildLink(md.Element element, TextStyle baseStyle) {
    final url = element.attributes['href'] ?? '';
    final text = element.textContent;

    final linkStyle = baseStyle.copyWith(
      color: style.primaryColor,
      decoration: TextDecoration.underline,
    );

    if (onLinkTap != null) {
      return [
        TextSpan(
          text: text,
          style: linkStyle,
          recognizer: TapGestureRecognizer()..onTap = () => onLinkTap!(url),
        ),
      ];
    }

    return [TextSpan(text: text, style: linkStyle)];
  }

  List<InlineSpan> _buildUnorderedList(
    md.Element element,
    TextStyle baseStyle,
  ) {
    final spans = <InlineSpan>[];

    if (element.children != null) {
      for (final child in element.children!) {
        if (child is md.Element && child.tag == 'li') {
          spans.addAll(_buildUnorderedListItem(child, baseStyle, 0));
        }
      }
    }

    return spans;
  }

  List<InlineSpan> _buildOrderedList(md.Element element, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    int index = 1;

    final startAttr = element.attributes['start'];
    if (startAttr != null) {
      index = int.tryParse(startAttr) ?? 1;
    }

    if (element.children != null) {
      for (final child in element.children!) {
        if (child is md.Element && child.tag == 'li') {
          spans.addAll(_buildOrderedListItem(child, baseStyle, index, 0));
          index++;
        }
      }
    }

    return spans;
  }

  List<InlineSpan> _buildUnorderedListItem(
    md.Element element,
    TextStyle baseStyle,
    int depth,
  ) {
    final spans = <InlineSpan>[];
    final indent = '  ' * depth;
    final bullet = depth == 0 ? '•' : (depth == 1 ? '◦' : '▪');

    final hasCheckbox = _hasCheckboxChild(element);

    if (hasCheckbox) {
      spans.addAll(_buildCheckboxListItem(element, baseStyle, indent));
    } else {
      spans.add(
        TextSpan(
          text: '$indent$bullet ',
          style: baseStyle.copyWith(
            color: style.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      spans.addAll(_buildListItemContent(element, baseStyle, depth));
    }

    return spans;
  }

  List<InlineSpan> _buildOrderedListItem(
    md.Element element,
    TextStyle baseStyle,
    int index,
    int depth,
  ) {
    final spans = <InlineSpan>[];
    final indent = '  ' * depth;

    spans.add(
      TextSpan(
        text: '$indent$index. ',
        style: baseStyle.copyWith(
          color: style.primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    spans.addAll(_buildListItemContent(element, baseStyle, depth));

    return spans;
  }

  bool _hasCheckboxChild(md.Element element) {
    if (element.children == null) return false;

    for (final child in element.children!) {
      if (child is md.Element && child.tag == 'input') {
        final type = child.attributes['type'];
        if (type == 'checkbox') return true;
      }
    }

    return false;
  }

  List<InlineSpan> _buildCheckboxListItem(
    md.Element element,
    TextStyle baseStyle,
    String indent,
  ) {
    final spans = <InlineSpan>[];
    bool isChecked = false;

    // Look up pre-assigned checkbox data using block:local index key.
    // This avoids holding element references and ensures correct positions.
    final key = '$_currentBuildingBlock:$_blockCheckboxCounter';
    final checkboxData = _nodeCheckboxMap[key];
    _blockCheckboxCounter++;

    if (element.children != null) {
      for (final child in element.children!) {
        if (child is md.Element && child.tag == 'input') {
          isChecked = child.attributes['checked'] != null;
          break;
        }
      }
    }

    spans.add(TextSpan(text: indent, style: baseStyle));

    // Use consistent box characters that render at the same size
    final checkboxChar = isChecked ? '☒' : '☐';
    final checkboxStyle = baseStyle.copyWith(
      color: isChecked
          ? style.primaryColor
          : style.textColor.withValues(alpha: 0.7),
    );

    if (checkboxData != null && onCheckboxTap != null) {
      final data = checkboxData; // Local variable for closure capture
      spans.add(
        TextSpan(
          text: '$checkboxChar ',
          style: checkboxStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => onCheckboxTap!(
              data.bracketStart,
              data.bracketEnd,
              data.isChecked,
            ),
        ),
      );
    } else {
      spans.add(TextSpan(text: '$checkboxChar ', style: checkboxStyle));
    }

    final contentStyle = isChecked
        ? baseStyle.copyWith(
            color: style.textColor.withValues(alpha: 0.5),
            decoration: TextDecoration.lineThrough,
            decorationColor: style.textColor.withValues(alpha: 0.5),
            decorationThickness: 1.5,
          )
        : baseStyle;

    if (element.children != null) {
      for (final child in element.children!) {
        if (child is md.Element && child.tag == 'input') continue;
        spans.addAll(_buildNode(child, contentStyle));
      }
    }

    spans.add(const TextSpan(text: '\n'));

    return spans;
  }

  List<InlineSpan> _buildListItemContent(
    md.Element element,
    TextStyle baseStyle,
    int depth,
  ) {
    final spans = <InlineSpan>[];

    if (element.children != null) {
      for (final child in element.children!) {
        if (child is md.Element) {
          if (child.tag == 'ul') {
            spans.add(const TextSpan(text: '\n'));
            for (final subItem in child.children ?? []) {
              if (subItem is md.Element && subItem.tag == 'li') {
                spans.addAll(
                  _buildUnorderedListItem(subItem, baseStyle, depth + 1),
                );
              }
            }
            continue;
          } else if (child.tag == 'ol') {
            spans.add(const TextSpan(text: '\n'));
            int subIndex = 1;
            for (final subItem in child.children ?? []) {
              if (subItem is md.Element && subItem.tag == 'li') {
                spans.addAll(
                  _buildOrderedListItem(
                    subItem,
                    baseStyle,
                    subIndex,
                    depth + 1,
                  ),
                );
                subIndex++;
              }
            }
            continue;
          } else if (child.tag == 'p') {
            spans.addAll(_buildChildren(child, baseStyle));
            continue;
          }
        }

        spans.addAll(_buildNode(child, baseStyle));
      }
    }

    spans.add(const TextSpan(text: '\n'));

    return spans;
  }

  List<InlineSpan> _buildListItem(md.Element element, TextStyle baseStyle) {
    return _buildChildren(element, baseStyle);
  }

  List<InlineSpan> _buildBlockquote(md.Element element, TextStyle baseStyle) {
    final quoteStyle = baseStyle.copyWith(
      fontStyle: FontStyle.italic,
      color: style.textColor.withValues(alpha: 0.8),
    );

    return [
      WidgetSpan(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: style.primaryColor, width: 4),
            ),
            color: style.blockquoteColor.withValues(alpha: 0.3),
          ),
          child: Text.rich(
            TextSpan(
              children: _buildChildren(element, quoteStyle).cast<InlineSpan>(),
            ),
          ),
        ),
      ),
      const TextSpan(text: '\n'),
    ];
  }

  List<InlineSpan> _buildHorizontalRule(TextStyle baseStyle) {
    return [
      WidgetSpan(
        child: Container(
          width: double.infinity,
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 16),
          color: style.textColor.withValues(alpha: 0.3),
        ),
      ),
      const TextSpan(text: '\n'),
    ];
  }

  List<InlineSpan> _buildTable(md.Element element, TextStyle baseStyle) {
    final rows = <List<String>>[];
    bool hasHeader = false;

    if (element.children != null) {
      for (final child in element.children!) {
        if (child is md.Element) {
          if (child.tag == 'thead') {
            hasHeader = true;
            for (final row in child.children ?? []) {
              if (row is md.Element && row.tag == 'tr') {
                rows.add(_extractTableRow(row));
              }
            }
          } else if (child.tag == 'tbody') {
            for (final row in child.children ?? []) {
              if (row is md.Element && row.tag == 'tr') {
                rows.add(_extractTableRow(row));
              }
            }
          } else if (child.tag == 'tr') {
            rows.add(_extractTableRow(child));
          }
        }
      }
    }

    if (rows.isEmpty) {
      return [];
    }

    return [
      WidgetSpan(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: style.tableBorderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Table(
              border: TableBorder(
                horizontalInside: BorderSide(color: style.tableBorderColor),
                verticalInside: BorderSide(color: style.tableBorderColor),
              ),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: rows.asMap().entries.map((entry) {
                final rowIndex = entry.key;
                final cells = entry.value;
                final isHeader = hasHeader && rowIndex == 0;

                return TableRow(
                  decoration: isHeader
                      ? BoxDecoration(color: style.codeBackground)
                      : null,
                  children: cells.map((cell) {
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        cell,
                        style: baseStyle.copyWith(
                          fontWeight: isHeader ? FontWeight.bold : null,
                        ),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      const TextSpan(text: '\n'),
    ];
  }

  List<String> _extractTableRow(md.Element row) {
    final cells = <String>[];

    if (row.children != null) {
      for (final cell in row.children!) {
        if (cell is md.Element && (cell.tag == 'td' || cell.tag == 'th')) {
          cells.add(cell.textContent.trim());
        }
      }
    }

    return cells;
  }

  List<InlineSpan> _buildCheckbox(md.Element element, TextStyle baseStyle) {
    return [];
  }
}

class _CheckboxData {
  final int lineIndex;
  final int bracketStart;
  final int bracketEnd;
  final bool isChecked;

  _CheckboxData({
    required this.lineIndex,
    required this.bracketStart,
    required this.bracketEnd,
    required this.isChecked,
  });
}

class _HighlightRange {
  final int start;
  final int end;
  final bool isCurrent;

  _HighlightRange({
    required this.start,
    required this.end,
    required this.isCurrent,
  });
}

/// Lazy markdown blocks that build TextSpans on demand.
/// Only visible blocks are converted to spans, saving memory and CPU.
class LazyMarkdownBlocks {
  final List<md.Node> nodes;
  final MarkdownSpanBuilder builder;
  final TextStyle baseStyle;
  final String? blankLineMarker;

  /// Cache of already-built blocks (sparse - only built blocks are stored)
  final Map<int, List<InlineSpan>> _cache = {};

  LazyMarkdownBlocks({
    required this.nodes,
    required this.builder,
    required this.baseStyle,
    this.blankLineMarker,
  });

  /// Number of top-level blocks
  int get length => nodes.length;

  /// Get spans for a block at index, building lazily if needed
  List<InlineSpan> operator [](int index) {
    if (_cache.containsKey(index)) {
      return _cache[index]!;
    }

    final node = nodes[index];

    // Check if this is a blank line marker paragraph
    if (blankLineMarker != null && _isBlankLineMarker(node)) {
      // Return just a newline for spacing
      final spans = <InlineSpan>[TextSpan(text: '\n', style: baseStyle)];
      _cache[index] = spans;
      return spans;
    }

    // Pass block index for checkbox lookup
    final spans = builder.buildNodeSpans(node, baseStyle, index);
    _cache[index] = spans;
    return spans;
  }

  bool _isBlankLineMarker(md.Node node) {
    if (node is md.Element && node.tag == 'p') {
      final text = node.textContent;
      return text == blankLineMarker;
    }
    return false;
  }

  /// Check if a block has been built
  bool isBuilt(int index) => _cache.containsKey(index);

  /// Clear the cache (call when content changes)
  void clearCache() => _cache.clear();

  /// Estimate how much memory is saved
  int get cachedBlockCount => _cache.length;
}
