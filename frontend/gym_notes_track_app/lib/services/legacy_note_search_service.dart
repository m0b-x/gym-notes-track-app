import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

sealed class ReplaceResult {
  const ReplaceResult();
}

final class ReplaceSuccess extends ReplaceResult {
  final String newContent;
  final int replacementCount;
  final int cursorPosition;

  const ReplaceSuccess({
    required this.newContent,
    required this.replacementCount,
    required this.cursorPosition,
  });
}

final class ReplaceFailure extends ReplaceResult {
  final String reason;

  const ReplaceFailure(this.reason);
}

class NoteSearchMatch {
  final int start;
  final int end;
  final int lineNumber;
  final String matchedText;

  const NoteSearchMatch({
    required this.start,
    required this.end,
    required this.lineNumber,
    required this.matchedText,
  });

  int get length => end - start;
}

class NoteSearchService {
  String _content = '';
  String _query = '';
  String _replacement = '';
  bool _caseSensitive = false;
  bool _useRegex = false;
  bool _wholeWord = false;
  List<NoteSearchMatch> _matches = [];
  List<int> _lineStarts = [0];

  String get content => _content;
  String get query => _query;
  String get replacement => _replacement;
  bool get caseSensitive => _caseSensitive;
  bool get useRegex => _useRegex;
  bool get wholeWord => _wholeWord;
  List<NoteSearchMatch> get matches => List.unmodifiable(_matches);
  int get matchCount => _matches.length;
  bool get hasMatches => _matches.isNotEmpty;

  void updateContent(String content) {
    if (_content != content) {
      _content = content;
      _buildLineStarts();
      if (_query.isNotEmpty) {
        performSearch();
      }
    }
  }

  void updateQuery(String query) {
    _query = query;
    performSearch();
  }

  void updateReplacement(String replacement) {
    _replacement = replacement;
  }

  void setCaseSensitive(bool value) {
    if (_caseSensitive != value) {
      _caseSensitive = value;
      if (_query.isNotEmpty) {
        performSearch();
      }
    }
  }

  void setUseRegex(bool value) {
    if (_useRegex != value) {
      _useRegex = value;
      if (_query.isNotEmpty) {
        performSearch();
      }
    }
  }

  void setWholeWord(bool value) {
    if (_wholeWord != value) {
      _wholeWord = value;
      if (_query.isNotEmpty) {
        performSearch();
      }
    }
  }

  void _buildLineStarts() {
    _lineStarts = [0];
    for (int i = 0; i < _content.length; i++) {
      if (_content[i] == '\n') {
        _lineStarts.add(i + 1);
      }
    }
  }

  bool _hasMoreMatches = false;

  /// Whether there are more matches beyond the limit
  bool get hasMoreMatches => _hasMoreMatches;

  void performSearch() {
    _matches = [];
    _hasMoreMatches = false;

    if (_query.isEmpty || _content.isEmpty) {
      return;
    }

    try {
      final Pattern pattern = _buildPattern();
      final regexMatches = pattern.allMatches(_content);

      int count = 0;
      for (final match in regexMatches) {
        if (count >= AppConstants.maxSearchMatches) {
          _hasMoreMatches = true;
          break;
        }

        final lineNumber = _findLineNumber(match.start);
        _matches.add(
          NoteSearchMatch(
            start: match.start,
            end: match.end,
            lineNumber: lineNumber,
            matchedText: match.group(0) ?? '',
          ),
        );
        count++;
      }
    } catch (e) {
      debugPrint('Search error: $e');
      _matches = [];
    }
  }

  Pattern _buildPattern() {
    String patternString;

    if (_useRegex) {
      patternString = _query;
    } else {
      patternString = RegExp.escape(_query);
    }

    if (_wholeWord && !_useRegex) {
      patternString = '\\b$patternString\\b';
    }

    return RegExp(
      patternString,
      caseSensitive: _caseSensitive,
      multiLine: true,
    );
  }

  int _findLineNumber(int offset) {
    int low = 0;
    int high = _lineStarts.length - 1;

    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (_lineStarts[mid] <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }

    return low;
  }

  NoteSearchMatch? getMatchAt(int index) {
    if (index >= 0 && index < _matches.length) {
      return _matches[index];
    }
    return null;
  }

  int findMatchIndexAtOffset(int offset) {
    for (int i = 0; i < _matches.length; i++) {
      if (_matches[i].start <= offset && offset <= _matches[i].end) {
        return i;
      }
      if (_matches[i].start > offset) {
        return i > 0 ? i - 1 : 0;
      }
    }
    return _matches.isNotEmpty ? _matches.length - 1 : -1;
  }

  ReplaceResult replaceSingle(int matchIndex) {
    if (matchIndex < 0 || matchIndex >= _matches.length) {
      return const ReplaceFailure('Invalid match index');
    }

    final match = _matches[matchIndex];
    String replacementText = _replacement;

    if (_useRegex) {
      try {
        final pattern = _buildPattern() as RegExp;
        replacementText = match.matchedText.replaceFirstMapped(
          pattern,
          (m) => _processRegexReplacement(_replacement, m),
        );
      } catch (e) {
        return ReplaceFailure('Regex replacement error: $e');
      }
    }

    final newContent =
        _content.substring(0, match.start) +
        replacementText +
        _content.substring(match.end);

    final cursorPosition = match.start + replacementText.length;

    return ReplaceSuccess(
      newContent: newContent,
      replacementCount: 1,
      cursorPosition: cursorPosition,
    );
  }

  ReplaceResult replaceAll() {
    if (_matches.isEmpty) {
      return const ReplaceFailure('No matches to replace');
    }

    final buffer = StringBuffer();
    int lastEnd = 0;
    int replacementCount = 0;

    for (final match in _matches) {
      buffer.write(_content.substring(lastEnd, match.start));

      String replacementText = _replacement;
      if (_useRegex) {
        try {
          final pattern = _buildPattern() as RegExp;
          replacementText = match.matchedText.replaceFirstMapped(
            pattern,
            (m) => _processRegexReplacement(_replacement, m),
          );
        } catch (e) {
          return ReplaceFailure('Regex replacement error: $e');
        }
      }

      buffer.write(replacementText);
      lastEnd = match.end;
      replacementCount++;
    }

    buffer.write(_content.substring(lastEnd));

    return ReplaceSuccess(
      newContent: buffer.toString(),
      replacementCount: replacementCount,
      cursorPosition: 0,
    );
  }

  String _processRegexReplacement(String replacement, Match match) {
    String result = replacement;

    result = result.replaceAll(r'$&', match.group(0) ?? '');

    for (int i = 0; i <= match.groupCount; i++) {
      result = result.replaceAll('\$$i', match.group(i) ?? '');
    }

    return result;
  }

  void clear() {
    _content = '';
    _query = '';
    _replacement = '';
    _matches = [];
    _lineStarts = [0];
  }

  void clearMatches() {
    _query = '';
    _matches = [];
  }
}
