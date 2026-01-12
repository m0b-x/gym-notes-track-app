import 'dart:async';

import 'package:flutter/foundation.dart';
import '../services/legacy_note_search_service.dart';

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

sealed class ReplaceResultState {
  const ReplaceResultState();
}

final class ReplaceSuccessState extends ReplaceResultState {
  final String newContent;
  final int replacementCount;
  final int cursorPosition;

  const ReplaceSuccessState({
    required this.newContent,
    required this.replacementCount,
    required this.cursorPosition,
  });
}

final class ReplaceFailureState extends ReplaceResultState {
  final String reason;

  const ReplaceFailureState(this.reason);
}

class NoteSearchController extends ChangeNotifier {
  final NoteSearchService _searchService = NoteSearchService();

  String _replacement = '';
  int _currentMatchIndex = -1;
  bool _isSearching = false;
  bool _showReplace = false;
  int _lastReplacementCount = 0;

  // Debounce timer for search
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 150);

  // Pending search query (for debounce)
  String _pendingQuery = '';
  bool _isSearchPending = false;

  String get query => _searchService.query;
  String get replacement => _replacement;
  List<SearchMatch> get matches => _searchService.matches
      .map(
        (m) =>
            SearchMatch(start: m.start, end: m.end, lineNumber: m.lineNumber),
      )
      .toList();
  int get currentMatchIndex => _currentMatchIndex;
  int get matchCount => _searchService.matchCount;
  bool get hasMatches => _searchService.hasMatches;
  bool get hasMoreMatches => _searchService.hasMoreMatches;
  bool get caseSensitive => _searchService.caseSensitive;
  bool get useRegex => _searchService.useRegex;
  bool get wholeWord => _searchService.wholeWord;
  bool get isSearching => _isSearching;
  bool get showReplace => _showReplace;
  int get lastReplacementCount => _lastReplacementCount;

  SearchMatch? get currentMatch {
    if (_currentMatchIndex >= 0 && _currentMatchIndex < matchCount) {
      final m = _searchService.getMatchAt(_currentMatchIndex);
      if (m != null) {
        return SearchMatch(
          start: m.start,
          end: m.end,
          lineNumber: m.lineNumber,
        );
      }
    }
    return null;
  }

  /// Whether a search is currently being debounced
  bool get isSearchPending => _isSearchPending;

  void updateContent(String content) {
    _searchService.updateContent(content);
    _adjustCurrentMatchIndex();
    notifyListeners();
  }

  /// Search with debounce - prevents excessive searches on fast typing
  void search(String query) {
    _pendingQuery = query;

    // Cancel previous debounce timer
    _debounceTimer?.cancel();

    // For empty query, execute immediately
    if (query.isEmpty) {
      _isSearchPending = false;
      _executeSearch(query);
      return;
    }

    // Debounce the search
    _isSearchPending = true;
    notifyListeners(); // Notify that search is pending

    _debounceTimer = Timer(_debounceDuration, () {
      _isSearchPending = false;
      _executeSearch(_pendingQuery);
    });
  }

  /// Execute search immediately without debounce (for navigation, toggles)
  void searchImmediate(String query) {
    _debounceTimer?.cancel();
    _isSearchPending = false;
    _pendingQuery = query;
    _executeSearch(query);
  }

  void _executeSearch(String query) {
    _searchService.updateQuery(query);
    _currentMatchIndex = _searchService.hasMatches ? 0 : -1;
    notifyListeners();
  }

  void updateReplacement(String replacement) {
    _replacement = replacement;
  }

  void toggleCaseSensitive() {
    _searchService.setCaseSensitive(!_searchService.caseSensitive);
    _adjustCurrentMatchIndex();
    notifyListeners();
  }

  void toggleRegex() {
    _searchService.setUseRegex(!_searchService.useRegex);
    _adjustCurrentMatchIndex();
    notifyListeners();
  }

  void toggleWholeWord() {
    _searchService.setWholeWord(!_searchService.wholeWord);
    _adjustCurrentMatchIndex();
    notifyListeners();
  }

  void toggleShowReplace() {
    _showReplace = !_showReplace;
    notifyListeners();
  }

  void openSearch() {
    _isSearching = true;
    _lastReplacementCount = 0;
    notifyListeners();
  }

  void closeSearch() {
    _isSearching = false;
    _showReplace = false;
    _replacement = '';
    _currentMatchIndex = -1;
    _lastReplacementCount = 0;
    _searchService.clearMatches();
    notifyListeners();
  }

  void nextMatch() {
    if (!hasMatches) return;
    _currentMatchIndex = (_currentMatchIndex + 1) % matchCount;
    notifyListeners();
  }

  void previousMatch() {
    if (!hasMatches) return;
    _currentMatchIndex = (_currentMatchIndex - 1 + matchCount) % matchCount;
    notifyListeners();
  }

  void goToMatch(int index) {
    if (index >= 0 && index < matchCount) {
      _currentMatchIndex = index;
      notifyListeners();
    }
  }

  void _adjustCurrentMatchIndex() {
    if (_searchService.hasMatches) {
      if (_currentMatchIndex < 0 || _currentMatchIndex >= matchCount) {
        _currentMatchIndex = 0;
      }
    } else {
      _currentMatchIndex = -1;
    }
  }

  ReplaceResultState replaceCurrent() {
    if (!hasMatches || _currentMatchIndex < 0) {
      return const ReplaceFailureState('No match selected');
    }

    _searchService.updateReplacement(_replacement);
    final result = _searchService.replaceSingle(_currentMatchIndex);

    switch (result) {
      case ReplaceSuccess(:final newContent, :final cursorPosition):
        _lastReplacementCount = 1;
        return ReplaceSuccessState(
          newContent: newContent,
          replacementCount: 1,
          cursorPosition: cursorPosition,
        );
      case ReplaceFailure(:final reason):
        return ReplaceFailureState(reason);
    }
  }

  ReplaceResultState replaceAll() {
    if (!hasMatches) {
      return const ReplaceFailureState('No matches to replace');
    }

    _searchService.updateReplacement(_replacement);
    final result = _searchService.replaceAll();

    switch (result) {
      case ReplaceSuccess(:final newContent, :final replacementCount):
        _lastReplacementCount = replacementCount;
        return ReplaceSuccessState(
          newContent: newContent,
          replacementCount: replacementCount,
          cursorPosition: 0,
        );
      case ReplaceFailure(:final reason):
        return ReplaceFailureState(reason);
    }
  }

  String? replaceCurrentMatch(String replacement) {
    _replacement = replacement;
    final result = replaceCurrent();
    if (result is ReplaceSuccessState) {
      return result.newContent;
    }
    return null;
  }

  String replaceAllMatches(String replacement) {
    _replacement = replacement;
    final result = replaceAll();
    if (result is ReplaceSuccessState) {
      return result.newContent;
    }
    return _searchService.content;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchService.clear();
    super.dispose();
  }
}
