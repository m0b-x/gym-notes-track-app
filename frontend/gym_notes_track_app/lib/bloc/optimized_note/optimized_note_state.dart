import 'package:equatable/equatable.dart';
import '../../models/note_metadata.dart';
import '../../services/search_service.dart';

abstract class OptimizedNoteState extends Equatable {
  const OptimizedNoteState();

  @override
  List<Object?> get props => [];
}

class OptimizedNoteInitial extends OptimizedNoteState {}

class OptimizedNoteLoading extends OptimizedNoteState {
  final String? folderId;

  const OptimizedNoteLoading({this.folderId});

  @override
  List<Object?> get props => [folderId];
}

class OptimizedNoteLoaded extends OptimizedNoteState {
  final PaginatedNotes paginatedNotes;
  final Map<String, String> loadedContent;
  final bool isLoadingMore;
  final String? folderId;

  const OptimizedNoteLoaded({
    required this.paginatedNotes,
    this.loadedContent = const {},
    this.isLoadingMore = false,
    this.folderId,
  });

  OptimizedNoteLoaded copyWith({
    PaginatedNotes? paginatedNotes,
    Map<String, String>? loadedContent,
    bool? isLoadingMore,
    String? folderId,
  }) {
    return OptimizedNoteLoaded(
      paginatedNotes: paginatedNotes ?? this.paginatedNotes,
      loadedContent: loadedContent ?? this.loadedContent,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      folderId: folderId ?? this.folderId,
    );
  }

  @override
  List<Object?> get props => [
    paginatedNotes,
    loadedContent,
    isLoadingMore,
    folderId,
  ];
}

class OptimizedNoteContentLoaded extends OptimizedNoteState {
  final LazyNote note;
  final PaginatedNotes? previousPaginatedNotes;
  final String? folderId;

  const OptimizedNoteContentLoaded({
    required this.note,
    this.previousPaginatedNotes,
    this.folderId,
  });

  @override
  List<Object?> get props => [note, previousPaginatedNotes, folderId];
}

class OptimizedNoteSearchResults extends OptimizedNoteState {
  final List<SearchResult> results;
  final String query;
  final bool isSearching;

  const OptimizedNoteSearchResults({
    required this.results,
    required this.query,
    this.isSearching = false,
  });

  OptimizedNoteSearchResults copyWith({
    List<SearchResult>? results,
    String? query,
    bool? isSearching,
  }) {
    return OptimizedNoteSearchResults(
      results: results ?? this.results,
      query: query ?? this.query,
      isSearching: isSearching ?? this.isSearching,
    );
  }

  @override
  List<Object?> get props => [results, query, isSearching];
}

class OptimizedNoteError extends OptimizedNoteState {
  final String message;
  final String? folderId;

  const OptimizedNoteError(this.message, {this.folderId});

  @override
  List<Object?> get props => [message, folderId];
}
