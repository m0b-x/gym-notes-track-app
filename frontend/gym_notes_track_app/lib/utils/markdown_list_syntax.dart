/// Canonical markdown **list** syntax for the whole app.
///
/// This is the single source of truth consumed by both surfaces that
/// care about lists, so they can never disagree about what is (or isn't)
/// a list item:
///   * the editor ([MarkdownListUtils]) — Enter-continuation, empty-item
///     termination, Tab/Shift-Tab indent;
///   * the preview renderer ([LineBasedMarkdownBuilder]) — bullet /
///     ordered / task rendering with correct source offsets.
///
/// Supported (GFM): `-`, `*`, `+`, and `•` bullets; `N.` / `N)` ordered
/// items; and `- [ ]` / `- [x]` task items (markers `-`, `*`, `+`). All
/// detection is indentation-aware so nested lists round-trip correctly.
library;

/// The kind of list item recognized by [MarkdownListSyntax.parse].
enum MarkdownListKind { bullet, ordered, task }

/// A parsed list item. All column fields are 0-based offsets **within
/// the line**; the renderer adds the line's source-start offset to get
/// absolute positions for search-highlight and tap mapping.
class MarkdownListItem {
  final MarkdownListKind kind;

  /// Leading whitespace exactly as written (spaces and/or tabs), so
  /// continuation preserves the original indentation.
  final String indent;

  /// For bullets: the marker glyph (`-`, `*`, `+`, `•`). For ordered
  /// items: the number as written (e.g. `12`).
  final String marker;

  /// Ordered delimiter (`.` or `)`); empty for bullets and tasks.
  final String delimiter;

  /// Task only: whether the box is checked.
  final bool checked;

  /// Task only: column of the `[` (so the renderer can map a tap on the
  /// 3-char `[ ]` / `[x]` box back to source). `-1` for non-tasks.
  final int bracketStart;

  /// Column where the item's content text begins (after the marker /
  /// checkbox and any spacing).
  final int contentStart;

  /// The content text after the marker / checkbox (may be empty).
  final String content;

  const MarkdownListItem({
    required this.kind,
    required this.indent,
    required this.marker,
    required this.delimiter,
    required this.checked,
    required this.bracketStart,
    required this.contentStart,
    required this.content,
  });

  /// Whether this item has no content after the marker — the signal to
  /// terminate the list when Enter is pressed on it.
  bool get isEmpty => content.trim().isEmpty;

  /// Visual nesting level derived from [indent] (tabs count as two
  /// columns; every [MarkdownListSyntax.indentUnit] columns is one
  /// level).
  int get level => MarkdownListSyntax.indentLevel(indent);
}

/// Pure, allocation-light parsing of a single line into an optional
/// [MarkdownListItem]. Compiled regexes are reused across calls.
class MarkdownListSyntax {
  MarkdownListSyntax._();

  /// Columns per indent level (and spaces inserted per Tab indent).
  static const int indentUnit = 2;

  // Detection order is task → bullet → ordered, so `- [ ]` is a task
  // (not a plain `-` bullet whose content happens to start with `[`).
  static final _task = RegExp(r'^(\s*)([-*+])\s+\[([ xX])\]');
  static final _bullet = RegExp(r'^(\s*)([-*+•])\s+');
  static final _ordered = RegExp(r'^(\s*)(\d+)([.)])\s+');

  /// Parses [line], or returns `null` when it is not a list item.
  static MarkdownListItem? parse(String line) {
    final t = _task.firstMatch(line);
    if (t != null) {
      final indent = t.group(1)!;
      final bracketStart = line.indexOf('[', indent.length);
      // Move past the 3-char box (`[x]`) then any spacing to the content.
      int contentStart = bracketStart + 3;
      contentStart = _skipSpaces(line, contentStart);
      return MarkdownListItem(
        kind: MarkdownListKind.task,
        indent: indent,
        marker: t.group(2)!,
        delimiter: '',
        checked: t.group(3)!.toLowerCase() == 'x',
        bracketStart: bracketStart,
        contentStart: contentStart,
        content: line.substring(contentStart),
      );
    }

    final b = _bullet.firstMatch(line);
    if (b != null) {
      final indent = b.group(1)!;
      final marker = b.group(2)!;
      final contentStart = _skipSpaces(line, indent.length + marker.length);
      return MarkdownListItem(
        kind: MarkdownListKind.bullet,
        indent: indent,
        marker: marker,
        delimiter: '',
        checked: false,
        bracketStart: -1,
        contentStart: contentStart,
        content: line.substring(contentStart),
      );
    }

    final o = _ordered.firstMatch(line);
    if (o != null) {
      final indent = o.group(1)!;
      final number = o.group(2)!;
      final delimiter = o.group(3)!;
      final contentStart = _skipSpaces(
        line,
        indent.length + number.length + delimiter.length,
      );
      return MarkdownListItem(
        kind: MarkdownListKind.ordered,
        indent: indent,
        marker: number,
        delimiter: delimiter,
        checked: false,
        bracketStart: -1,
        contentStart: contentStart,
        content: line.substring(contentStart),
      );
    }

    return null;
  }

  /// Whether [line] begins a list item.
  static bool isListLine(String line) => parse(line) != null;

  /// Visual nesting level for a leading-whitespace string (or any line —
  /// only the leading whitespace is inspected). Tabs count as two
  /// columns; every [indentUnit] columns is one level.
  static int indentLevel(String text) {
    int cols = 0;
    for (int i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c == 0x20) {
        cols += 1;
      } else if (c == 0x09) {
        cols += 2; // tab
      } else {
        break;
      }
    }
    return cols ~/ indentUnit;
  }

  static int _skipSpaces(String line, int from) {
    int i = from;
    while (i < line.length && line.codeUnitAt(i) == 0x20) {
      i++;
    }
    return i;
  }
}
