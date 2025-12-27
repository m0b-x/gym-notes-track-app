import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/note_metadata.dart';
import '../../services/note_storage_service.dart';
import '../../services/search_service.dart';
import 'optimized_note_event.dart';
import 'optimized_note_state.dart';

class OptimizedNoteBloc extends Bloc<OptimizedNoteEvent, OptimizedNoteState> {
  final NoteStorageService _storageService;
  final SearchService _searchService;

  String? _currentFolderId;
  int _currentPage = 1;
  NotesSortOrder _currentSortOrder = NotesSortOrder.updatedDesc;
  PaginatedNotes? _lastPaginatedNotes;

  OptimizedNoteBloc({
    NoteStorageService? storageService,
    SearchService? searchService,
  }) : _storageService = storageService ?? NoteStorageService(),
       _searchService =
           searchService ??
           SearchService(
             storageService: storageService ?? NoteStorageService(),
           ),
       super(OptimizedNoteInitial()) {
    on<LoadNotesPaginated>(_onLoadNotesPaginated);
    on<LoadMoreNotes>(_onLoadMoreNotes);
    on<LoadNoteContent>(_onLoadNoteContent);
    on<CreateOptimizedNote>(_onCreateNote);
    on<UpdateOptimizedNote>(_onUpdateNote);
    on<DeleteOptimizedNote>(_onDeleteNote);
    on<SearchNotes>(_onSearchNotes);
    on<QuickSearchNotes>(_onQuickSearchNotes);
    on<ClearSearch>(_onClearSearch);
    on<RefreshNotes>(_onRefreshNotes);
  }

  Future<void> _onLoadNotesPaginated(
    LoadNotesPaginated event,
    Emitter<OptimizedNoteState> emit,
  ) async {
    emit(OptimizedNoteLoading(folderId: event.folderId));

    try {
      await _storageService.initialize();

      _currentFolderId = event.folderId;
      _currentPage = event.page;
      _currentSortOrder = event.sortOrder;

      final paginatedNotes = await _storageService.loadNotesPaginated(
        folderId: event.folderId,
        page: event.page,
        pageSize: event.pageSize,
        sortOrder: event.sortOrder,
      );

      _lastPaginatedNotes = paginatedNotes;

      emit(
        OptimizedNoteLoaded(
          paginatedNotes: paginatedNotes,
          folderId: event.folderId,
        ),
      );
    } catch (e) {
      emit(
        OptimizedNoteError(
          'Failed to load notes: $e',
          folderId: event.folderId,
        ),
      );
    }
  }

  Future<void> _onLoadMoreNotes(
    LoadMoreNotes event,
    Emitter<OptimizedNoteState> emit,
  ) async {
    final currentState = state;

    if (currentState is! OptimizedNoteLoaded) return;
    if (!currentState.paginatedNotes.hasMore) return;
    if (currentState.isLoadingMore) return;

    emit(
      currentState.copyWith(
        isLoadingMore: true,
        folderId: event.folderId ?? _currentFolderId,
      ),
    );

    try {
      _currentPage++;

      final morePaginatedNotes = await _storageService.loadNotesPaginated(
        folderId: event.folderId ?? _currentFolderId,
        page: _currentPage,
        sortOrder: _currentSortOrder,
      );

      final combinedNotes = [
        ...currentState.paginatedNotes.notes,
        ...morePaginatedNotes.notes,
      ];

      final updatedPaginatedNotes = morePaginatedNotes.copyWith(
        notes: combinedNotes,
      );

      _lastPaginatedNotes = updatedPaginatedNotes;

      emit(
        currentState.copyWith(
          paginatedNotes: updatedPaginatedNotes,
          isLoadingMore: false,
          folderId: event.folderId ?? _currentFolderId,
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          isLoadingMore: false,
          folderId: event.folderId ?? _currentFolderId,
        ),
      );
    }
  }

  Future<void> _onLoadNoteContent(
    LoadNoteContent event,
    Emitter<OptimizedNoteState> emit,
  ) async {
    try {
      final lazyNote = await _storageService.loadNoteWithContent(event.noteId);

      if (lazyNote == null) {
        emit(const OptimizedNoteError('Note not found'));
        return;
      }

      emit(
        OptimizedNoteContentLoaded(
          note: lazyNote,
          previousPaginatedNotes: _lastPaginatedNotes,
          folderId: _currentFolderId,
        ),
      );
    } catch (e) {
      emit(
        OptimizedNoteError(
          'Failed to load note content: $e',
          folderId: _currentFolderId,
        ),
      );
    }
  }

  Future<void> _onCreateNote(
    CreateOptimizedNote event,
    Emitter<OptimizedNoteState> emit,
  ) async {
    try {
      final metadata = await _storageService.createNote(
        folderId: event.folderId,
        title: event.title,
        content: event.content,
      );

      await _searchService.updateIndex(metadata.id, event.title, event.content);

      add(RefreshNotes(folderId: event.folderId));
    } catch (e) {
      emit(
        OptimizedNoteError(
          'Failed to create note: $e',
          folderId: event.folderId,
        ),
      );
    }
  }

  Future<void> _onUpdateNote(
    UpdateOptimizedNote event,
    Emitter<OptimizedNoteState> emit,
  ) async {
    try {
      final metadata = await _storageService.updateNote(
        noteId: event.noteId,
        title: event.title,
        content: event.content,
      );

      if (metadata != null) {
        final content =
            event.content ??
            await _storageService.loadNoteContent(event.noteId);
        await _searchService.updateIndex(metadata.id, metadata.title, content);
      }

      if (_currentFolderId != null) {
        add(RefreshNotes(folderId: _currentFolderId));
      }
    } catch (e) {
      emit(
        OptimizedNoteError(
          'Failed to update note: $e',
          folderId: _currentFolderId,
        ),
      );
    }
  }

  Future<void> _onDeleteNote(
    DeleteOptimizedNote event,
    Emitter<OptimizedNoteState> emit,
  ) async {
    try {
      await _storageService.deleteNote(event.noteId);
      await _searchService.removeFromIndex(event.noteId);

      add(RefreshNotes(folderId: _currentFolderId));
    } catch (e) {
      emit(
        OptimizedNoteError(
          'Failed to delete note: $e',
          folderId: _currentFolderId,
        ),
      );
    }
  }

  Future<void> _onSearchNotes(
    SearchNotes event,
    Emitter<OptimizedNoteState> emit,
  ) async {
    emit(
      const OptimizedNoteSearchResults(
        results: [],
        query: '',
        isSearching: true,
      ),
    );

    try {
      await _searchService.initialize();

      final results = await _searchService.search(
        event.query,
        filter: event.folderId != null
            ? SearchFilter(folderId: event.folderId)
            : null,
      );

      emit(
        OptimizedNoteSearchResults(
          results: results,
          query: event.query,
          isSearching: false,
        ),
      );
    } catch (e) {
      emit(OptimizedNoteError('Search failed: $e', folderId: event.folderId));
    }
  }

  Future<void> _onQuickSearchNotes(
    QuickSearchNotes event,
    Emitter<OptimizedNoteState> emit,
  ) async {
    final currentState = state;

    if (currentState is OptimizedNoteSearchResults) {
      emit(currentState.copyWith(isSearching: true));
    } else {
      emit(
        const OptimizedNoteSearchResults(
          results: [],
          query: '',
          isSearching: true,
        ),
      );
    }

    try {
      await _searchService.initialize();

      final results = await _searchService.quickSearch(
        event.query,
        folderId: event.folderId,
      );

      emit(
        OptimizedNoteSearchResults(
          results: results,
          query: event.query,
          isSearching: false,
        ),
      );
    } catch (e) {
      emit(
        OptimizedNoteError('Quick search failed: $e', folderId: event.folderId),
      );
    }
  }

  Future<void> _onClearSearch(
    ClearSearch event,
    Emitter<OptimizedNoteState> emit,
  ) async {
    if (_lastPaginatedNotes != null) {
      emit(
        OptimizedNoteLoaded(
          paginatedNotes: _lastPaginatedNotes!,
          folderId: _currentFolderId,
        ),
      );
    } else {
      add(LoadNotesPaginated(folderId: _currentFolderId));
    }
  }

  Future<void> _onRefreshNotes(
    RefreshNotes event,
    Emitter<OptimizedNoteState> emit,
  ) async {
    _currentPage = 1;

    final paginatedNotes = await _storageService.loadNotesPaginated(
      folderId: event.folderId ?? _currentFolderId,
      page: 1,
      sortOrder: _currentSortOrder,
    );

    _lastPaginatedNotes = paginatedNotes;

    emit(
      OptimizedNoteLoaded(
        paginatedNotes: paginatedNotes,
        folderId: event.folderId ?? _currentFolderId,
      ),
    );
  }

  @override
  Future<void> close() {
    _storageService.dispose();
    _searchService.dispose();
    return super.close();
  }
}
