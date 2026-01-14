class MarkdownListUtils {
  MarkdownListUtils._();

  static final _emptyPatterns = ['•', '-', '- [ ]', '- [x]', '- [X]'];
  static final _numberedPattern = RegExp(r'^\d+\.$');
  static final _numberedWithSpacePattern = RegExp(r'^(\d+)\.\s');

  static bool isEmptyListItem(String line) {
    line = line.trim();
    for (var pattern in _emptyPatterns) {
      if (line == pattern) return true;
    }
    return _numberedPattern.hasMatch(line);
  }

  static String? getListPrefix(String line) {
    line = line.trimLeft();

    if (line.startsWith('• ')) return '• ';
    if (line.startsWith('- ') && !line.startsWith('- [')) return '- ';
    if (line.startsWith('- [ ] ')) return '- [ ] ';
    if (line.startsWith('- [x] ') || line.startsWith('- [X] ')) return '- [ ] ';

    final numberedMatch = _numberedWithSpacePattern.firstMatch(line);
    if (numberedMatch != null) {
      final currentNumber = int.parse(numberedMatch.group(1)!);
      return '${currentNumber + 1}. ';
    }

    return null;
  }
}
