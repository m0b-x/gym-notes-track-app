import 'package:equatable/equatable.dart';
import '../../models/note_metadata.dart';
import '../../services/search_service.dart';

abstract class OptimizedNoteState extends Equatable {
  const OptimizedNoteState();

  @override
  List<Object?> get props => [];
}

class OptimizedNoteInitial extends OptimizedNoteState {}

class OptimizedNoteLoading extends OptimizedNoteState {}

class OptimizedNoteLoaded extends OptimizedNoteState {
  final PaginatedNotes paginatedNotes;
  final Map<String, String> loadedContent;
  final bool isLoadingMore;

  const OptimizedNoteLoaded({
    required this.paginatedNotes,
    this.loadedContent = const {},
    this.isLoadingMore = false,
  });

  OptimizedNoteLoaded copyWith({
    PaginatedNotes? paginatedNotes,
    Map<String, String>? loadedContent,
    bool? isLoadingMore,
  }) {
    return OptimizedNoteLoaded(
      paginatedNotes: paginatedNotes ?? this.paginatedNotes,
      loadedContent: loadedContent ?? this.loadedContent,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [paginatedNotes, loadedContent, isLoadingMore];
}

class OptimizedNoteContentLoaded extends OptimizedNoteState {
  final LazyNote note;
  final PaginatedNotes? previousPaginatedNotes;

  const OptimizedNoteContentLoaded({
    required this.note,
    this.previousPaginatedNotes,
  });

  @override
  List<Object?> get props => [note, previousPaginatedNotes];
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

  const OptimizedNoteError(this.message);

  @override
  List<Object?> get props => [message];
}
