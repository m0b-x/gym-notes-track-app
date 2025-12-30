import '../database/database.dart';
import '../database/daos/note_dao.dart';
import '../database/daos/content_chunk_dao.dart';
import '../repositories/note_repository.dart';
import '../models/note_metadata.dart';
import '../utils/compression_utils.dart';
import '../constants/app_constants.dart';

enum NotesSortOrder {
  updatedDesc,
  updatedAsc,
  createdDesc,
  createdAsc,
  titleAsc,
  titleDesc,
}

class NoteStorageService {
  static const int defaultPageSize = AppConstants.defaultPageSize;

  final NoteRepository _repository;
  bool _isInitialized = false;

  NoteStorageService({required NoteRepository repository})
    : _repository = repository;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  Future<PaginatedNotes> loadNotesPaginated({
    String? folderId,
    int page = 1,
    int pageSize = defaultPageSize,
    NotesSortOrder sortOrder = NotesSortOrder.updatedDesc,
  }) async {
    await initialize();

    final totalCount = await _repository.getNoteCount(folderId);
    final totalPages = (totalCount / pageSize).ceil().clamp(
      1,
      double.maxFinite.toInt(),
    );
    final offset = (page - 1) * pageSize;

    final (sortField, ascending) = _mapSortOrder(sortOrder);

    final notes = await _repository.getNotesPaginated(
      folderId: folderId,
      limit: pageSize,
      offset: offset,
      sortField: sortField,
      ascending: ascending,
    );

    final metadata = notes.map(_noteToMetadata).toList();

    return PaginatedNotes(
      notes: metadata,
      currentPage: page,
      totalPages: totalPages,
      totalCount: totalCount,
      hasMore: page < totalPages,
    );
  }

  Future<List<NoteMetadata>> loadAllMetadataForFolder(String folderId) async {
    await initialize();
    final notes = await _repository.getNotesByFolder(folderId);
    return notes.map(_noteToMetadata).toList();
  }

  Future<LazyNote?> loadNoteWithContent(String noteId) async {
    await initialize();

    final note = await _repository.getNoteById(noteId);
    if (note == null) return null;

    final content = await _repository.loadContent(noteId);

    return LazyNote(
      metadata: _noteToMetadata(note),
      content: content,
      isContentLoaded: true,
    );
  }

  Future<String> loadNoteContent(String noteId) async {
    await initialize();
    return _repository.loadContent(noteId);
  }

  Future<NoteMetadata> createNote({
    required String folderId,
    required String title,
    required String content,
  }) async {
    await initialize();

    final shouldCompress = CompressionUtils.shouldCompress(content);
    final preview = NoteMetadata.generatePreview(content);
    final chunkCount = (content.length / ContentChunkDao.defaultChunkSize)
        .ceil()
        .clamp(1, double.maxFinite.toInt());

    final note = await _repository.createNote(
      folderId: folderId,
      title: title,
      content: content,
      preview: preview,
      contentLength: content.length,
      chunkCount: chunkCount,
      isCompressed: shouldCompress,
    );

    return _noteToMetadata(note);
  }

  Future<NoteMetadata?> updateNote({
    required String noteId,
    String? title,
    String? content,
  }) async {
    await initialize();

    final existingNote = await _repository.getNoteById(noteId);
    if (existingNote == null) return null;

    String? newPreview;
    int? newContentLength;
    int? newChunkCount;
    bool? newIsCompressed;

    if (content != null) {
      newPreview = NoteMetadata.generatePreview(content);
      newContentLength = content.length;
      newChunkCount = (content.length / ContentChunkDao.defaultChunkSize)
          .ceil()
          .clamp(1, double.maxFinite.toInt());
      newIsCompressed = CompressionUtils.shouldCompress(content);
    }

    final updatedNote = await _repository.updateNote(
      id: noteId,
      title: title,
      preview: newPreview,
      contentLength: newContentLength,
      chunkCount: newChunkCount,
      isCompressed: newIsCompressed,
      content: content,
    );

    return updatedNote != null ? _noteToMetadata(updatedNote) : null;
  }

  Future<void> deleteNote(String noteId) async {
    await initialize();
    await _repository.deleteNote(noteId);
  }

  Future<List<NoteMetadata>> searchNotes(
    String query, {
    String? folderId,
  }) async {
    await initialize();
    final notes = await _repository.searchNotes(query, folderId: folderId);
    return notes.map(_noteToMetadata).toList();
  }

  Future<List<NoteMetadata>> fullTextSearch(
    String query, {
    String? folderId,
  }) async {
    await initialize();
    try {
      final notes = await _repository.fullTextSearch(query, folderId: folderId);
      return notes.map(_noteToMetadata).toList();
    } catch (_) {
      return searchNotes(query, folderId: folderId);
    }
  }

  NoteMetadata _noteToMetadata(Note note) {
    return NoteMetadata(
      id: note.id,
      folderId: note.folderId,
      title: note.title,
      preview: note.preview,
      contentLength: note.contentLength,
      chunkCount: note.chunkCount,
      isCompressed: note.isCompressed,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
    );
  }

  (NoteSortField, bool) _mapSortOrder(NotesSortOrder sortOrder) {
    switch (sortOrder) {
      case NotesSortOrder.updatedDesc:
        return (NoteSortField.updatedAt, false);
      case NotesSortOrder.updatedAsc:
        return (NoteSortField.updatedAt, true);
      case NotesSortOrder.createdDesc:
        return (NoteSortField.createdAt, false);
      case NotesSortOrder.createdAsc:
        return (NoteSortField.createdAt, true);
      case NotesSortOrder.titleAsc:
        return (NoteSortField.title, true);
      case NotesSortOrder.titleDesc:
        return (NoteSortField.title, false);
    }
  }

  Future<void> deleteNotesInFolder(String folderId) async {
    await initialize();
    final notes = await _repository.getNotesByFolder(folderId);
    for (final note in notes) {
      await _repository.deleteNote(note.id);
    }
  }

  Stream<List<NoteMetadata>> watchNotesByFolder(String? folderId) {
    return _repository
        .watchNotesByFolder(folderId)
        .map((notes) => notes.map(_noteToMetadata).toList());
  }

  void invalidateCache() {
    _repository.invalidateAll();
  }

  void dispose() {}
}
