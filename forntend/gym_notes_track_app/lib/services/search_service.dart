import 'dart:convert';
import 'package:gym_notes_track_app/constants/search_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_metadata.dart';
import '../utils/isolate_worker.dart';
import 'note_storage_service.dart';

String removeDiacritics(String text) {


  final buffer = StringBuffer();
  for (int i = 0; i < text.length; i++) {
    final char = text[i];
    buffer.write(SearchConstants.diacriticsMap[char] ?? char);
  }
  return buffer.toString();
}

String normalizeForSearch(String text, {bool caseSensitive = false}) {
  String normalized = removeDiacritics(text);
  if (!caseSensitive) {
    normalized = normalized.toLowerCase();
  }
  return normalized;
}

class SearchResult {
  final NoteMetadata metadata;
  final List<SearchMatch> matches;
  final double relevanceScore;

  const SearchResult({
    required this.metadata,
    required this.matches,
    required this.relevanceScore,
  });
}

class SearchMatch {
  final String text;
  final int startIndex;
  final int endIndex;
  final SearchMatchType type;

  const SearchMatch({
    required this.text,
    required this.startIndex,
    required this.endIndex,
    required this.type,
  });
}

enum SearchMatchType { title, content }

class SearchFilter {
  final String? folderId;
  final DateTime? fromDate;
  final DateTime? toDate;
  final int? minContentLength;
  final int? maxContentLength;
  final bool caseSensitive;

  const SearchFilter({
    this.folderId,
    this.fromDate,
    this.toDate,
    this.minContentLength,
    this.maxContentLength,
    this.caseSensitive = false,
  });

  bool matches(NoteMetadata metadata) {
    if (folderId != null && metadata.folderId != folderId) {
      return false;
    }

    if (fromDate != null && metadata.updatedAt.isBefore(fromDate!)) {
      return false;
    }

    if (toDate != null && metadata.updatedAt.isAfter(toDate!)) {
      return false;
    }

    if (minContentLength != null &&
        metadata.contentLength < minContentLength!) {
      return false;
    }

    if (maxContentLength != null &&
        metadata.contentLength > maxContentLength!) {
      return false;
    }

    return true;
  }
}

class SearchIndex {
  final Map<String, Set<String>> _wordToNoteIds = {};
  final Map<String, Map<String, int>> _termFrequency = {};
  bool _isBuilt = false;

  bool get isBuilt => _isBuilt;

  void addNote(String noteId, String title, String content) {
    final text = '$title $content'.toLowerCase();
    final words = _tokenize(text);

    _termFrequency[noteId] = {};

    for (final word in words) {
      _wordToNoteIds.putIfAbsent(word, () => {});
      _wordToNoteIds[word]!.add(noteId);

      _termFrequency[noteId]!.putIfAbsent(word, () => 0);
      _termFrequency[noteId]![word] = _termFrequency[noteId]![word]! + 1;
    }
  }

  void removeNote(String noteId) {
    _termFrequency.remove(noteId);

    for (final entry in _wordToNoteIds.entries) {
      entry.value.remove(noteId);
    }

    _wordToNoteIds.removeWhere((_, noteIds) => noteIds.isEmpty);
  }

  Set<String> search(String query, {bool caseSensitive = false}) {
    final normalizedQuery = normalizeForSearch(
      query,
      caseSensitive: caseSensitive,
    );
    final queryWords = _tokenize(normalizedQuery);

    if (queryWords.isEmpty) return {};

    Set<String>? result;

    for (final word in queryWords) {
      final matchingIds = <String>{};

      for (final entry in _wordToNoteIds.entries) {
        if (entry.key.contains(word)) {
          matchingIds.addAll(entry.value);
        }
      }

      if (result == null) {
        result = matchingIds;
      } else {
        result = result.intersection(matchingIds);
      }
    }

    return result ?? {};
  }

  double getRelevanceScore(
    String noteId,
    String query, {
    bool caseSensitive = false,
  }) {
    final normalizedQuery = normalizeForSearch(
      query,
      caseSensitive: caseSensitive,
    );
    final queryWords = _tokenize(normalizedQuery);
    final noteTerms = _termFrequency[noteId];

    if (noteTerms == null || queryWords.isEmpty) return 0.0;

    double score = 0.0;
    int matchCount = 0;

    for (final word in queryWords) {
      for (final entry in noteTerms.entries) {
        if (entry.key.contains(word)) {
          score += entry.value;
          matchCount++;
        }
      }
    }

    if (matchCount == 0) return 0.0;

    return score * (matchCount / queryWords.length);
  }

  Set<String> _tokenize(String text) {
    // Normalize text by removing diacritics and converting to lowercase
    final normalizedText = normalizeForSearch(text, caseSensitive: false);
    final regex = RegExp(r'\b\w{2,}\b');
    final matches = regex.allMatches(normalizedText);
    return matches.map((m) => m.group(0)!).toSet();
  }

  void markBuilt() {
    _isBuilt = true;
  }

  void clear() {
    _wordToNoteIds.clear();
    _termFrequency.clear();
    _isBuilt = false;
  }
}

class SearchService {
  static const int _maxRecentSearches = 10;
  static const String _recentSearchesKey = 'recent_searches';

  final NoteStorageService _storageService;
  final IsolatePool _isolatePool;
  final SearchIndex _searchIndex = SearchIndex();

  List<String> _recentSearches = [];
  bool _isInitialized = false;

  SearchService({
    required NoteStorageService storageService,
    IsolatePool? isolatePool,
  }) : _storageService = storageService,
       _isolatePool = isolatePool ?? IsolatePool();

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _isolatePool.initialize();
    await _loadRecentSearches();
    _isInitialized = true;
  }

  Future<void> buildIndex() async {
    await initialize();

    _searchIndex.clear();

    final paginatedNotes = await _storageService.loadNotesPaginated(
      pageSize: 1000,
    );

    for (final metadata in paginatedNotes.notes) {
      final content = await _storageService.loadNoteContent(metadata.id);
      _searchIndex.addNote(metadata.id, metadata.title, content);
    }

    _searchIndex.markBuilt();
  }

  Future<void> updateIndex(String noteId, String title, String content) async {
    await initialize();
    _searchIndex.removeNote(noteId);
    _searchIndex.addNote(noteId, title, content);
  }

  Future<void> removeFromIndex(String noteId) async {
    await initialize();
    _searchIndex.removeNote(noteId);
  }

  Future<List<SearchResult>> search(
    String query, {
    SearchFilter? filter,
    int limit = 50,
    bool caseSensitive = false,
  }) async {
    await initialize();

    if (query.trim().isEmpty) return [];

    await _addToRecentSearches(query);

    if (!_searchIndex.isBuilt) {
      await buildIndex();
    }

    final effectiveCaseSensitive = filter?.caseSensitive ?? caseSensitive;
    final matchingIds = _searchIndex.search(
      query,
      caseSensitive: effectiveCaseSensitive,
    );
    final results = <SearchResult>[];

    for (final noteId in matchingIds) {
      final paginatedNotes = await _storageService.loadNotesPaginated(
        pageSize: 1000,
      );

      NoteMetadata? metadata;
      try {
        metadata = paginatedNotes.notes.firstWhere((m) => m.id == noteId);
      } catch (_) {
        continue;
      }

      if (filter != null && !filter.matches(metadata)) {
        continue;
      }

      final content = await _storageService.loadNoteContent(noteId);
      final matches = _findMatches(
        query,
        metadata.title,
        content,
        caseSensitive: effectiveCaseSensitive,
      );
      final relevanceScore = _searchIndex.getRelevanceScore(
        noteId,
        query,
        caseSensitive: effectiveCaseSensitive,
      );

      results.add(
        SearchResult(
          metadata: metadata,
          matches: matches,
          relevanceScore: relevanceScore,
        ),
      );
    }

    results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    return results.take(limit).toList();
  }

  Future<List<SearchResult>> quickSearch(
    String query, {
    String? folderId,
    int limit = 10,
    bool caseSensitive = false,
  }) async {
    await initialize();

    if (query.trim().isEmpty) return [];

    final paginatedNotes = await _storageService.loadNotesPaginated(
      folderId: folderId,
      pageSize: 100,
    );

    final normalizedQuery = normalizeForSearch(
      query,
      caseSensitive: caseSensitive,
    );
    final results = <SearchResult>[];

    for (final metadata in paginatedNotes.notes) {
      final normalizedTitle = normalizeForSearch(
        metadata.title,
        caseSensitive: caseSensitive,
      );
      final normalizedPreview = normalizeForSearch(
        metadata.preview,
        caseSensitive: caseSensitive,
      );

      if (normalizedTitle.contains(normalizedQuery) ||
          normalizedPreview.contains(normalizedQuery)) {
        final titleMatches = _findMatchesInText(
          query,
          metadata.title,
          SearchMatchType.title,
          caseSensitive: caseSensitive,
        );
        final previewMatches = _findMatchesInText(
          query,
          metadata.preview,
          SearchMatchType.content,
          caseSensitive: caseSensitive,
        );

        double score = 0.0;
        if (normalizedTitle.contains(normalizedQuery)) score += 2.0;
        if (normalizedPreview.contains(normalizedQuery)) score += 1.0;

        results.add(
          SearchResult(
            metadata: metadata,
            matches: [...titleMatches, ...previewMatches],
            relevanceScore: score,
          ),
        );
      }
    }

    results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    return results.take(limit).toList();
  }

  List<SearchMatch> _findMatches(
    String query,
    String title,
    String content, {
    bool caseSensitive = false,
  }) {
    final matches = <SearchMatch>[];

    matches.addAll(
      _findMatchesInText(
        query,
        title,
        SearchMatchType.title,
        caseSensitive: caseSensitive,
      ),
    );
    matches.addAll(
      _findMatchesInText(
        query,
        content,
        SearchMatchType.content,
        caseSensitive: caseSensitive,
      ),
    );

    return matches;
  }

  List<SearchMatch> _findMatchesInText(
    String query,
    String text,
    SearchMatchType type, {
    bool caseSensitive = false,
  }) {
    final matches = <SearchMatch>[];
    final normalizedQuery = normalizeForSearch(
      query,
      caseSensitive: caseSensitive,
    );
    final normalizedText = normalizeForSearch(
      text,
      caseSensitive: caseSensitive,
    );

    int index = 0;
    while (true) {
      final matchIndex = normalizedText.indexOf(normalizedQuery, index);
      if (matchIndex == -1) break;

      final contextStart = (matchIndex - 30).clamp(0, text.length);
      final contextEnd = (matchIndex + query.length + 30).clamp(0, text.length);

      matches.add(
        SearchMatch(
          text: text.substring(contextStart, contextEnd),
          startIndex: matchIndex - contextStart,
          endIndex: matchIndex - contextStart + query.length,
          type: type,
        ),
      );

      index = matchIndex + 1;

      if (matches.length >= 5) break;
    }

    return matches;
  }

  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  Future<void> _addToRecentSearches(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _recentSearches.remove(trimmed);
    _recentSearches.insert(0, trimmed);

    if (_recentSearches.length > _maxRecentSearches) {
      _recentSearches = _recentSearches.sublist(0, _maxRecentSearches);
    }

    await _saveRecentSearches();
  }

  Future<void> clearRecentSearches() async {
    _recentSearches.clear();
    await _saveRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final searchesString = prefs.getString(_recentSearchesKey);

    if (searchesString != null) {
      final List<dynamic> decoded = jsonDecode(searchesString);
      _recentSearches = decoded.cast<String>();
    }
  }

  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentSearchesKey, jsonEncode(_recentSearches));
  }

  void dispose() {
    _searchIndex.clear();
    _isolatePool.dispose();
  }
}
