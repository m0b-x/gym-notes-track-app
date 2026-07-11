part of re_editor;

/// A root span for a single editor line whose soft-wrapped continuation
/// lines should align under the content instead of the line start — a
/// hanging indent, as list items get in Obsidian.
///
/// The first [hangingChars] code units (the list-marker prefix: indent,
/// bullet/number/checkbox, trailing space) become their own single-line
/// paragraph at the line's left edge, and the remaining content is laid
/// out at the marker's exact advance width, so the first line looks
/// unchanged while wrapped lines start under the content.
///
/// Only meaningful as the root span a span builder returns for a line;
/// the paragraph provider falls back to a plain single paragraph when
/// the prefix is empty, covers the whole line, is wider than half the
/// viewport, or the line got truncated for length.
class CodeHangingTextSpan extends TextSpan {
  final int hangingChars;

  const CodeHangingTextSpan({
    required this.hangingChars,
    super.style,
    super.children,
  });

  @override
  bool operator ==(Object other) =>
      other is CodeHangingTextSpan &&
      other.hangingChars == hangingChars &&
      super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, hangingChars);
}

abstract class IParagraph {
  double get width;
  double get height;
  double get preferredLineHeight;
  bool get trucated;
  int get length;
  int get lineCount;

  void draw(Canvas canvas, Offset offset);

  TextPosition getPosition(Offset offset);

  TextRange getWord(Offset offset);

  InlineSpan? getSpanForPosition(TextPosition position);

  TextRange getRangeForSpan(InlineSpan span);

  TextRange getLineBoundary(TextPosition position);

  Offset? getOffset(TextPosition position);

  List<Rect> getRangeRects(TextRange range);
}
