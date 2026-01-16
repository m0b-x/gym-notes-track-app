import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:re_editor/re_editor.dart';

/// Result states for replace operations
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

/// Search match representation for external use
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

/// A search controller that wraps re_editor's CodeFindController
/// to leverage native search functionality for better performance.
///
/// This controller maintains the same API as the old NoteSearchController
/// so the UI doesn't need to change.
class ReEditorSearchController extends ChangeNotifier {
  CodeFindController? _findController;
  CodeLineEditingController? _editingController;
  bool _findControllerDisposed = false;

  bool _isSearching = false;
  bool _showReplace = false;
  bool _wholeWord = false;
  int _lastReplacementCount = 0;

  // Track options locally since CodeFindController doesn't expose wholeWord
  String _currentQuery = '';
  String _replacement = '';

  bool get _hasFindController =>
      _findController != null && !_findControllerDisposed;

  /// Set the CodeFindController from findBuilder callback
  /// This should be called from the findBuilder in CodeEditor
  void setFindController(CodeFindController controller) {
    if (_findController != controller) {
      _findController?.removeListener(_onFindControllerChanged);
      _findController = controller;
      _findControllerDisposed = false;
      _findController!.addListener(_onFindControllerChanged);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  void clearFindController() {
    _findController?.removeListener(_onFindControllerChanged);
    _findController = null;
    _findControllerDisposed = true;
  }

  /// Initialize with the editing controller (for offset calculations)
  void initialize(CodeLineEditingController editingController) {
    _editingController = editingController;
  }

  void _onFindControllerChanged() {
    notifyListeners();
  }

  /// The underlying CodeFindController for use with findBuilder
  CodeFindController? get findController => _findController;

  /// Current search query
  String get query => _currentQuery;

  /// Replacement text
  String get replacement => _replacement;

  /// List of matches converted to SearchMatch format
  List<SearchMatch> get matches {
    if (!_hasFindController) return [];
    final value = _findController?.value;
    if (value?.result == null) return [];

    final result = value!.result!;
    return result.matches.asMap().entries.map((entry) {
      final match = entry.value;
      return SearchMatch(
        start: _selectionToOffset(match.start),
        end: _selectionToOffset(match.end),
        lineNumber: match.startIndex,
      );
    }).toList();
  }

  int _selectionToOffset(CodeLinePosition pos) {
    if (_editingController == null) return 0;
    final lines = _editingController!.codeLines;
    int offset = 0;
    for (int i = 0; i < pos.index && i < lines.length; i++) {
      offset += lines[i].text.length + 1; // +1 for newline
    }
    return offset + pos.offset;
  }

  /// Current match index (0-based)
  int get currentMatchIndex {
    if (!_hasFindController) return -1;
    final value = _findController?.value;
    return value?.result?.index ?? -1;
  }

  /// Total number of matches
  int get matchCount {
    if (!_hasFindController) return 0;
    final value = _findController?.value;
    return value?.result?.matches.length ?? 0;
  }

  /// Whether there are any matches
  bool get hasMatches => matchCount > 0;

  /// Whether there might be more matches (re_editor doesn't limit)
  bool get hasMoreMatches => false;

  /// Case sensitive search option
  bool get caseSensitive {
    if (!_hasFindController) return false;
    final value = _findController?.value;
    return value?.option.caseSensitive ?? false;
  }

  /// Regex search option
  bool get useRegex {
    if (!_hasFindController) return false;
    final value = _findController?.value;
    return value?.option.regex ?? false;
  }

  /// Whole word search option (handled locally)
  bool get wholeWord => _wholeWord;

  /// Whether search is currently active
  bool get isSearching => _isSearching;

  /// Whether replace panel should be shown
  bool get showReplace => _showReplace;

  /// Last replacement count
  int get lastReplacementCount => _lastReplacementCount;

  /// Get the current match
  SearchMatch? get currentMatch {
    if (!_hasFindController) return null;
    final value = _findController?.value;
    if (value?.result == null || value!.result!.matches.isEmpty) return null;

    final idx = value.result!.index;
    if (idx < 0 || idx >= value.result!.matches.length) return null;

    final match = value.result!.matches[idx];
    return SearchMatch(
      start: _selectionToOffset(match.start),
      end: _selectionToOffset(match.end),
      lineNumber: match.startIndex,
    );
  }

  /// Whether a search is pending (re_editor handles this internally)
  bool get isSearchPending {
    if (!_hasFindController) return false;
    final value = _findController?.value;
    return value?.searching ?? false;
  }

  /// Update content - not needed as CodeFindController listens to editing controller
  void updateContent(String content) {
    // No-op: CodeFindController automatically tracks content changes
  }

  /// Search with the given query
  void search(String query) {
    _currentQuery = query;
    if (_hasFindController) {
      _findController?.findInputController.text = _applyWholeWord(query);
    }
  }

  /// Execute search immediately (same as search for CodeFindController)
  void searchImmediate(String query) {
    search(query);
  }

  String _applyWholeWord(String query) {
    if (_wholeWord && query.isNotEmpty && !useRegex) {
      // Wrap with word boundaries for whole word matching
      return '\\b${RegExp.escape(query)}\\b';
    }
    return query;
  }

  /// Update replacement text
  void updateReplacement(String replacement) {
    _replacement = replacement;
    if (_hasFindController) {
      _findController?.replaceInputController.text = replacement;
    }
  }

  /// Toggle case sensitivity
  void toggleCaseSensitive() {
    if (_hasFindController) {
      _findController?.toggleCaseSensitive();
    }
    notifyListeners();
  }

  /// Toggle regex mode
  void toggleRegex() {
    if (_hasFindController) {
      _findController?.toggleRegex();
    }
    // Re-apply whole word if needed after regex toggle
    if (_currentQuery.isNotEmpty) {
      search(_currentQuery);
    }
    notifyListeners();
  }

  /// Toggle whole word matching
  void toggleWholeWord() {
    _wholeWord = !_wholeWord;
    // Re-apply search with whole word
    if (_currentQuery.isNotEmpty && _hasFindController) {
      _findController?.findInputController.text = _applyWholeWord(
        _currentQuery,
      );
    }
    notifyListeners();
  }

  /// Toggle show replace panel
  void toggleShowReplace() {
    _showReplace = !_showReplace;
    if (_hasFindController) {
      if (_showReplace) {
        _findController?.replaceMode();
      } else {
        _findController?.findMode();
      }
    }
    notifyListeners();
  }

  /// Open search
  void openSearch() {
    _isSearching = true;
    _lastReplacementCount = 0;
    if (_hasFindController) {
      _findController?.findMode();
    }
    notifyListeners();
  }

  /// Close search
  void closeSearch() {
    _isSearching = false;
    _showReplace = false;
    _replacement = '';
    _currentQuery = '';
    if (_hasFindController) {
      _findController?.close();
    }
    notifyListeners();
  }

  /// Navigate to next match
  void nextMatch() {
    if (_hasFindController) {
      _findController?.nextMatch();
    }
  }

  /// Navigate to previous match
  void previousMatch() {
    if (_hasFindController) {
      _findController?.previousMatch();
    }
  }

  /// Go to specific match index
  void goToMatch(int index) {
    // CodeFindController doesn't have direct index navigation,
    // so we navigate from current position
    final current = currentMatchIndex;
    if (index == current) return;

    if (index > current) {
      for (int i = current; i < index; i++) {
        _findController?.nextMatch();
      }
    } else {
      for (int i = current; i > index; i--) {
        _findController?.previousMatch();
      }
    }
  }

  /// Replace current match
  ReplaceResultState replaceCurrent() {
    if (!hasMatches || !_hasFindController) {
      return const ReplaceFailureState('No match selected');
    }

    _findController!.replaceInputController.text = _replacement;
    _findController!.replaceMatch();
    _lastReplacementCount = 1;

    return ReplaceSuccessState(
      newContent: _editingController?.text ?? '',
      replacementCount: 1,
      cursorPosition: 0,
    );
  }

  /// Replace all matches
  ReplaceResultState replaceAll() {
    if (!hasMatches || !_hasFindController) {
      return const ReplaceFailureState('No matches to replace');
    }

    final count = matchCount;
    _findController!.replaceInputController.text = _replacement;
    _findController!.replaceAllMatches();
    _lastReplacementCount = count;

    return ReplaceSuccessState(
      newContent: _editingController?.text ?? '',
      replacementCount: count,
      cursorPosition: 0,
    );
  }

  /// Replace current match and return new content (legacy API)
  String? replaceCurrentMatch(String replacement) {
    _replacement = replacement;
    final result = replaceCurrent();
    if (result is ReplaceSuccessState) {
      return result.newContent;
    }
    return null;
  }

  /// Replace all matches and return new content (legacy API)
  String replaceAllMatches(String replacement) {
    _replacement = replacement;
    final result = replaceAll();
    if (result is ReplaceSuccessState) {
      return result.newContent;
    }
    return _editingController?.text ?? '';
  }

  @override
  void dispose() {
    _findController?.removeListener(_onFindControllerChanged);
    // Don't dispose _findController - it's owned by CodeEditor
    super.dispose();
  }
}
