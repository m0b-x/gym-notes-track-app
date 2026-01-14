class TextPositionUtils {
  TextPositionUtils._();

  static int getLineFromOffset(String text, int offset) {
    int line = 0;
    for (int i = 0; i < offset && i < text.length; i++) {
      if (text.codeUnitAt(i) == 10) line++;
    }
    return line;
  }

  static int getColumnFromOffset(String text, int offset) {
    int lastNewline = text.lastIndexOf('\n', offset - 1);
    return offset - (lastNewline + 1);
  }

  static ({int line, int column}) getPosition(String text, int offset) {
    return (
      line: getLineFromOffset(text, offset),
      column: getColumnFromOffset(text, offset),
    );
  }
}
