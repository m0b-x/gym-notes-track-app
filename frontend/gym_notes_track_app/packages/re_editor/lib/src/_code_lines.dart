part of re_editor;

class _CodeLineSegmentQuckLineCount extends CodeLineSegment {

  late int _lineCount;
  late int _charCount;

  _CodeLineSegmentQuckLineCount({
    required super.codeLines,
    required super.dirty,
  }) {
    _lineCount = super.lineCount;
    _charCount = super.charCount;
  }

  @override
  int get lineCount => _lineCount;

  @override
  int get charCount => _charCount;

  @override
  set length(int newLength) {
    super.length = newLength;
    _lineCount = super.lineCount;
    _charCount = super.charCount;
  }

  @override
  void add(CodeLine element) {
    super.add(element);
    _lineCount = super.lineCount;
    _charCount = super.charCount;
  }

  @override
  void operator []=(int index, CodeLine value) {
    super[index] = value;
    _lineCount = super.lineCount;
    _charCount = super.charCount;
  }
  
}

