import 'package:flutter/foundation.dart';

/// Represents a single search match in the text
class SearchMatch {
  final int start;
  final int end;
  final int lineNumber;

  const SearchMatch({
    required this.start,
    required this.end,
    required this.lineNumber,
  });

  int get length => end - start;
}

/// Efficient search controller for note content
/// Supports case-insensitive search, match navigation, and regex
class NoteSearchController extends ChangeNotifier {
  String _query = '';
  String _content = '';
  List<SearchMatch> _matches = [];
  int _currentMatchIndex = -1;
  bool _caseSensitive = false;
  bool _useRegex = false;
  bool _isSearching = false;

  // Getters
  String get query => _query;
  List<SearchMatch> get matches => _matches;
  int get currentMatchIndex => _currentMatchIndex;
  int get matchCount => _matches.length;
  bool get hasMatches => _matches.isNotEmpty;
  bool get caseSensitive => _caseSensitive;
  bool get useRegex => _useRegex;
  bool get isSearching => _isSearching;

  SearchMatch? get currentMatch {
    if (_currentMatchIndex >= 0 && _currentMatchIndex < _matches.length) {
      return _matches[_currentMatchIndex];
    }
    return null;
  }

  /// Updates the content to search in
  void updateContent(String content) {
    if (_content != content) {
      _content = content;
      if (_query.isNotEmpty) {
        _performSearch();
      }
    }
  }

  /// Sets the search query and performs search
  void search(String query) {
    _query = query;
    _performSearch();
  }

  /// Toggles case sensitivity
  void toggleCaseSensitive() {
    _caseSensitive = !_caseSensitive;
    if (_query.isNotEmpty) {
      _performSearch();
    }
    notifyListeners();
  }

  /// Toggles regex mode
  void toggleRegex() {
    _useRegex = !_useRegex;
    if (_query.isNotEmpty) {
      _performSearch();
    }
    notifyListeners();
  }

  /// Opens the search UI
  void openSearch() {
    _isSearching = true;
    notifyListeners();
  }

  /// Closes the search UI and clears results
  void closeSearch() {
    _isSearching = false;
    _query = '';
    _matches = [];
    _currentMatchIndex = -1;
    notifyListeners();
  }

  /// Navigates to the next match
  void nextMatch() {
    if (_matches.isEmpty) return;

    _currentMatchIndex = (_currentMatchIndex + 1) % _matches.length;
    notifyListeners();
  }

  /// Navigates to the previous match
  void previousMatch() {
    if (_matches.isEmpty) return;

    _currentMatchIndex =
        (_currentMatchIndex - 1 + _matches.length) % _matches.length;
    notifyListeners();
  }

  /// Jumps to a specific match by index
  void goToMatch(int index) {
    if (index >= 0 && index < _matches.length) {
      _currentMatchIndex = index;
      notifyListeners();
    }
  }

  /// Performs the actual search
  void _performSearch() {
    _matches = [];
    _currentMatchIndex = -1;

    if (_query.isEmpty || _content.isEmpty) {
      notifyListeners();
      return;
    }

    try {
      final Pattern pattern;
      if (_useRegex) {
        pattern = RegExp(
          _query,
          caseSensitive: _caseSensitive,
          multiLine: true,
        );
      } else {
        // Escape special regex characters for literal search
        final escaped = RegExp.escape(_query);
        pattern = RegExp(escaped, caseSensitive: _caseSensitive);
      }

      // Pre-calculate line starts for efficient line number lookup
      final lineStarts = <int>[0];
      for (int i = 0; i < _content.length; i++) {
        if (_content[i] == '\n') {
          lineStarts.add(i + 1);
        }
      }

      // Find all matches
      final regexMatches = pattern.allMatches(_content);

      for (final match in regexMatches) {
        // Binary search for line number
        final lineNumber = _findLineNumber(lineStarts, match.start);

        _matches.add(
          SearchMatch(
            start: match.start,
            end: match.end,
            lineNumber: lineNumber,
          ),
        );
      }

      // Auto-select first match if any found
      if (_matches.isNotEmpty) {
        _currentMatchIndex = 0;
      }
    } catch (e) {
      // Invalid regex - clear matches
      _matches = [];
      _currentMatchIndex = -1;
    }

    notifyListeners();
  }

  /// Binary search to find line number for a given offset
  int _findLineNumber(List<int> lineStarts, int offset) {
    int low = 0;
    int high = lineStarts.length - 1;

    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (lineStarts[mid] <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }

    return low;
  }

  /// Replace current match with replacement text
  /// Returns the new content if successful, null otherwise
  String? replaceCurrentMatch(String replacement) {
    final match = currentMatch;
    if (match == null) return null;

    final newContent =
        _content.substring(0, match.start) +
        replacement +
        _content.substring(match.end);

    return newContent;
  }

  /// Replace all matches with replacement text
  /// Returns the new content
  String replaceAllMatches(String replacement) {
    if (_matches.isEmpty) return _content;

    final buffer = StringBuffer();
    int lastEnd = 0;

    for (final match in _matches) {
      buffer.write(_content.substring(lastEnd, match.start));
      buffer.write(replacement);
      lastEnd = match.end;
    }

    buffer.write(_content.substring(lastEnd));
    return buffer.toString();
  }

  @override
  void dispose() {
    _matches = [];
    super.dispose();
  }
}
