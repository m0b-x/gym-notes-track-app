import 'dart:async';
import '../database/database.dart';
import '../database/daos/note_dao.dart';
import '../database/daos/content_chunk_dao.dart';
import '../models/note_metadata.dart';
import '../constants/app_constants.dart';

/// Event types for note changes
enum NoteChangeType { created, updated, deleted }

/// Represents a change to a note
class NoteChange {
  final NoteChangeType type;
  final String noteId;
  final String? folderId;
  final Note? note;

  const NoteChange({
    required this.type,
    required this.noteId,
    this.folderId,
    this.note,
  });
}

class NoteRepository {
  final AppDatabase _db;

  final Map<String, Note> _noteCache = {};
  final Map<String, String> _contentCache = {};
  final Map<String?, List<Note>> _folderNotesCache = {};
  final Map<String?, int> _countCache = {};

  static const int _maxContentCacheSize = AppConstants.maxContentCacheSize;
  static const int _maxNoteCacheSize = AppConstants.maxNoteCacheSize;
  static const Duration _cacheExpiry = AppConstants.cacheExpiry;

  DateTime? _lastCacheClean;

  /// Stream controller for note changes (reactive updates)
  final _noteChangesController = StreamController<NoteChange>.broadcast();

  /// Stream of all note changes for reactive UI updates
  Stream<NoteChange> get noteChanges => _noteChangesController.stream;

  /// Stream of changes filtered by folder
  Stream<NoteChange> noteChangesForFolder(String? folderId) {
    return _noteChangesController.stream.where(
      (change) => change.folderId == folderId,
    );
  }

  NoteRepository({required AppDatabase database}) : _db = database;

  NoteDao get _noteDao => _db.noteDao;
  ContentChunkDao get _chunkDao => _db.contentChunkDao;

  Future<Note?> getNoteById(String id, {bool forceRefresh = false}) async {
    _cleanCacheIfNeeded();

    if (!forceRefresh && _noteCache.containsKey(id)) {
      return _noteCache[id];
    }

    final note = await _noteDao.getNoteById(id);
    if (note != null) {
      _noteCache[id] = note;
      _trimNoteCache();
    }
    return note;
  }

  Future<List<Note>> getNotesByFolder(
    String? folderId, {
    bool forceRefresh = false,
  }) async {
    _cleanCacheIfNeeded();

    if (!forceRefresh && _folderNotesCache.containsKey(folderId)) {
      return _folderNotesCache[folderId]!;
    }

    final notes = await _noteDao.getNotesByFolder(folderId);
    _folderNotesCache[folderId] = notes;

    for (final note in notes) {
      _noteCache[note.id] = note;
    }
    _trimNoteCache();

    return notes;
  }

  Future<int> getNoteCount(
    String? folderId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _countCache.containsKey(folderId)) {
      return _countCache[folderId]!;
    }

    final count = await _noteDao.getNoteCount(folderId);
    _countCache[folderId] = count;
    return count;
  }

  Future<List<Note>> getNotesPaginated({
    String? folderId,
    required int limit,
    required int offset,
    required NoteSortField sortField,
    required bool ascending,
  }) async {
    final notes = await _noteDao.getNotesPaginated(
      folderId: folderId,
      limit: limit,
      offset: offset,
      sortField: sortField,
      ascending: ascending,
    );

    for (final note in notes) {
      _noteCache[note.id] = note;
    }
    _trimNoteCache();

    return notes;
  }

  Future<String> loadContent(String noteId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _contentCache.containsKey(noteId)) {
      return _contentCache[noteId]!;
    }

    final content = await _chunkDao.loadContent(noteId);
    _contentCache[noteId] = content;
    _trimContentCache();

    return content;
  }

  Future<Note> createNote({
    required String folderId,
    required String title,
    required String content,
    required String preview,
    required int contentLength,
    required int chunkCount,
    required bool isCompressed,
  }) async {
    final note = await _noteDao.createNote(
      folderId: folderId,
      title: title,
      preview: preview,
      contentLength: contentLength,
      chunkCount: chunkCount,
      isCompressed: isCompressed,
    );

    await _chunkDao.saveContent(noteId: note.id, content: content);

    _noteCache[note.id] = note;
    _contentCache[note.id] = content;
    _invalidateFolderCache(folderId);

    // Emit change event for reactive updates
    _noteChangesController.add(
      NoteChange(
        type: NoteChangeType.created,
        noteId: note.id,
        folderId: folderId,
        note: note,
      ),
    );

    return note;
  }

  Future<Note?> updateNote({
    required String id,
    String? title,
    String? preview,
    int? contentLength,
    int? chunkCount,
    bool? isCompressed,
    String? content,
  }) async {
    if (content != null) {
      await _chunkDao.saveContent(noteId: id, content: content);
      _contentCache[id] = content;
    }

    final note = await _noteDao.updateNote(
      id: id,
      title: title,
      preview: preview,
      contentLength: contentLength,
      chunkCount: chunkCount,
      isCompressed: isCompressed,
    );

    if (note != null) {
      _noteCache[id] = note;
      _invalidateFolderCache(note.folderId);

      // Emit change event for reactive updates
      _noteChangesController.add(
        NoteChange(
          type: NoteChangeType.updated,
          noteId: id,
          folderId: note.folderId,
          note: note,
        ),
      );
    }

    return note;
  }

  Future<void> deleteNote(String noteId) async {
    final note = await getNoteById(noteId);

    // Soft delete chunks for CRDT sync consistency
    await _chunkDao.softDeleteChunksForNote(noteId);
    await _noteDao.softDeleteNote(noteId);

    _noteCache.remove(noteId);
    _contentCache.remove(noteId);
    if (note != null) {
      _invalidateFolderCache(note.folderId);

      // Emit change event for reactive updates
      _noteChangesController.add(
        NoteChange(
          type: NoteChangeType.deleted,
          noteId: noteId,
          folderId: note.folderId,
        ),
      );
    }
  }

  Future<List<Note>> searchNotes(String query, {String? folderId}) async {
    return _noteDao.searchNotes(query, folderId: folderId);
  }

  Future<List<Note>> fullTextSearch(
    String query, {
    String? folderId,
    int limit = 50,
  }) async {
    return _noteDao.fullTextSearch(query, folderId: folderId, limit: limit);
  }

  Stream<List<Note>> watchNotesByFolder(String? folderId) {
    return _noteDao.watchNotesByFolder(folderId).map((notes) {
      for (final note in notes) {
        _noteCache[note.id] = note;
      }
      _folderNotesCache[folderId] = notes;
      return notes;
    });
  }

  Future<List<Note>> getNotesSince(String hlcTimestamp) {
    return _noteDao.getNotesSince(hlcTimestamp);
  }

  Future<void> mergeNote(Note remote) async {
    await _noteDao.mergeNote(remote);
    _noteCache.remove(remote.id);
    _invalidateFolderCache(remote.folderId);
  }

  void _invalidateFolderCache(String? folderId) {
    _folderNotesCache.remove(folderId);
    _countCache.remove(folderId);
  }

  void invalidateAll() {
    _noteCache.clear();
    _contentCache.clear();
    _folderNotesCache.clear();
    _countCache.clear();
  }

  void _trimNoteCache() {
    if (_noteCache.length > _maxNoteCacheSize) {
      final keysToRemove = _noteCache.keys
          .take(_noteCache.length - _maxNoteCacheSize)
          .toList();
      for (final key in keysToRemove) {
        _noteCache.remove(key);
      }
    }
  }

  void _trimContentCache() {
    if (_contentCache.length > _maxContentCacheSize) {
      final keysToRemove = _contentCache.keys
          .take(_contentCache.length - _maxContentCacheSize)
          .toList();
      for (final key in keysToRemove) {
        _contentCache.remove(key);
      }
    }
  }

  void _cleanCacheIfNeeded() {
    final now = DateTime.now();
    if (_lastCacheClean == null ||
        now.difference(_lastCacheClean!) > _cacheExpiry) {
      _folderNotesCache.clear();
      _countCache.clear();
      _lastCacheClean = now;
    }
  }

  NoteMetadata noteToMetadata(Note note) {
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

  /// Dispose resources
  void dispose() {
    _noteChangesController.close();
  }
}
