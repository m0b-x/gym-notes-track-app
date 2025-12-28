import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../models/note_metadata.dart';
import '../utils/compression_utils.dart';
import '../utils/isolate_worker.dart';
import 'chunked_storage_service.dart';

class NoteStorageService {
  static const String _metadataStorageKey = 'note_metadata';
  static const String _legacyNotesKey = 'notes';
  static const int defaultPageSize = 20;

  final ChunkedStorageService _chunkedStorage;
  final Uuid _uuid;
  final IsolatePool _isolatePool;

  List<NoteMetadata>? _metadataCache;
  bool _isInitialized = false;

  NoteStorageService({
    ChunkedStorageService? chunkedStorage,
    Uuid? uuid,
    IsolatePool? isolatePool,
  }) : _chunkedStorage = chunkedStorage ?? ChunkedStorageService(),
       _uuid = uuid ?? const Uuid(),
       _isolatePool = isolatePool ?? IsolatePool();

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _isolatePool.initialize();
    await _migrateIfNeeded();
    _isInitialized = true;
  }

  Future<void> _migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyNotes = prefs.getString(_legacyNotesKey);

    if (legacyNotes == null) return;

    final existingMetadata = prefs.getString(_metadataStorageKey);
    if (existingMetadata != null) return;

    final result = await _isolatePool.execute<List<dynamic>>(
      'jsonDecode',
      legacyNotes,
    );

    if (!result.isSuccess || result.data == null) return;

    final List<dynamic> notesJson = result.data!;

    for (final noteJson in notesJson) {
      final note = Note.fromJson(noteJson as Map<String, dynamic>);
      await _saveNoteInternal(note);
    }
  }

  Future<PaginatedNotes> loadNotesPaginated({
    String? folderId,
    int page = 1,
    int pageSize = defaultPageSize,
    NotesSortOrder sortOrder = NotesSortOrder.updatedDesc,
  }) async {
    await initialize();

    final allMetadata = await _loadAllMetadata();

    var filteredMetadata = folderId != null
        ? allMetadata.where((m) => m.folderId == folderId).toList()
        : allMetadata;

    filteredMetadata = _sortMetadata(filteredMetadata, sortOrder);

    final totalCount = filteredMetadata.length;
    final totalPages = (totalCount / pageSize).ceil();
    final startIndex = (page - 1) * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, totalCount);

    final pageNotes = startIndex < totalCount
        ? filteredMetadata.sublist(startIndex, endIndex)
        : <NoteMetadata>[];

    return PaginatedNotes(
      notes: pageNotes,
      currentPage: page,
      totalPages: totalPages,
      totalCount: totalCount,
      hasMore: page < totalPages,
    );
  }

  Future<List<NoteMetadata>> loadAllMetadataForFolder(String folderId) async {
    await initialize();

    final allMetadata = await _loadAllMetadata();
    return allMetadata.where((m) => m.folderId == folderId).toList();
  }

  Future<LazyNote?> loadNoteWithContent(String noteId) async {
    await initialize();

    final metadata = await _getMetadataById(noteId);
    if (metadata == null) return null;

    final content = await _chunkedStorage.loadContent(noteId);

    return LazyNote(
      metadata: metadata,
      content: content,
      isContentLoaded: true,
    );
  }

  Future<String> loadNoteContent(String noteId) async {
    await initialize();
    return _chunkedStorage.loadContent(noteId);
  }

  Future<NoteMetadata> createNote({
    required String folderId,
    required String title,
    required String content,
  }) async {
    await initialize();

    final now = DateTime.now();
    final noteId = _uuid.v4();

    final shouldCompress = CompressionUtils.shouldCompress(content);

    final metadata = NoteMetadata(
      id: noteId,
      folderId: folderId,
      title: title,
      preview: NoteMetadata.generatePreview(content),
      contentLength: content.length,
      chunkCount: (content.length / ChunkedStorageService.defaultChunkSize)
          .ceil()
          .clamp(1, double.maxFinite.toInt()),
      isCompressed: shouldCompress,
      createdAt: now,
      updatedAt: now,
    );

    await _chunkedStorage.saveContent(noteId: noteId, content: content);
    await _saveMetadata(metadata);

    _metadataCache = null;

    return metadata;
  }

  Future<NoteMetadata?> updateNote({
    required String noteId,
    String? title,
    String? content,
  }) async {
    await initialize();

    final existingMetadata = await _getMetadataById(noteId);
    if (existingMetadata == null) return null;

    String? newPreview;
    int? newContentLength;
    int? newChunkCount;
    bool? newIsCompressed;

    if (content != null) {
      await _chunkedStorage.saveContent(noteId: noteId, content: content);
      newPreview = NoteMetadata.generatePreview(content);
      newContentLength = content.length;
      newChunkCount = (content.length / ChunkedStorageService.defaultChunkSize)
          .ceil()
          .clamp(1, double.maxFinite.toInt());
      newIsCompressed = CompressionUtils.shouldCompress(content);
    }

    final updatedMetadata = existingMetadata.copyWith(
      title: title,
      preview: newPreview,
      contentLength: newContentLength,
      chunkCount: newChunkCount,
      isCompressed: newIsCompressed,
      updatedAt: DateTime.now(),
    );

    await _updateMetadata(updatedMetadata);
    _metadataCache = null;

    return updatedMetadata;
  }

  Future<void> deleteNote(String noteId) async {
    await initialize();

    await _chunkedStorage.deleteContent(noteId);
    await _deleteMetadata(noteId);
    _metadataCache = null;
  }

  Future<List<NoteMetadata>> _loadAllMetadata() async {
    if (_metadataCache != null) return _metadataCache!;

    final prefs = await SharedPreferences.getInstance();
    final metadataString = prefs.getString(_metadataStorageKey);

    if (metadataString == null) {
      _metadataCache = [];
      return _metadataCache!;
    }

    final result = await _isolatePool.execute<List<dynamic>>(
      'jsonDecode',
      metadataString,
    );

    if (!result.isSuccess || result.data == null) {
      _metadataCache = [];
      return _metadataCache!;
    }

    _metadataCache = result.data!
        .map((json) => NoteMetadata.fromJson(json as Map<String, dynamic>))
        .toList();

    return _metadataCache!;
  }

  Future<NoteMetadata?> _getMetadataById(String noteId) async {
    final allMetadata = await _loadAllMetadata();
    try {
      return allMetadata.firstWhere((m) => m.id == noteId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveMetadata(NoteMetadata metadata) async {
    final allMetadata = await _loadAllMetadata();
    allMetadata.add(metadata);
    await _persistMetadata(allMetadata);
  }

  Future<void> _updateMetadata(NoteMetadata metadata) async {
    final allMetadata = await _loadAllMetadata();
    final index = allMetadata.indexWhere((m) => m.id == metadata.id);

    if (index != -1) {
      allMetadata[index] = metadata;
      await _persistMetadata(allMetadata);
    }
  }

  Future<void> _deleteMetadata(String noteId) async {
    final allMetadata = await _loadAllMetadata();
    allMetadata.removeWhere((m) => m.id == noteId);
    await _persistMetadata(allMetadata);
  }

  Future<void> _persistMetadata(List<NoteMetadata> metadata) async {
    final prefs = await SharedPreferences.getInstance();
    final metadataJson = metadata.map((m) => m.toJson()).toList();
    await prefs.setString(_metadataStorageKey, jsonEncode(metadataJson));
    _metadataCache = metadata;
  }

  Future<void> _saveNoteInternal(Note note) async {
    final shouldCompress = CompressionUtils.shouldCompress(note.content);

    final metadata = NoteMetadata(
      id: note.id,
      folderId: note.folderId,
      title: note.title,
      preview: NoteMetadata.generatePreview(note.content),
      contentLength: note.content.length,
      chunkCount: (note.content.length / ChunkedStorageService.defaultChunkSize)
          .ceil()
          .clamp(1, double.maxFinite.toInt()),
      isCompressed: shouldCompress,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
    );

    await _chunkedStorage.saveContent(noteId: note.id, content: note.content);
    await _saveMetadata(metadata);
  }

  List<NoteMetadata> _sortMetadata(
    List<NoteMetadata> metadata,
    NotesSortOrder sortOrder,
  ) {
    final sorted = List<NoteMetadata>.from(metadata);

    switch (sortOrder) {
      case NotesSortOrder.updatedDesc:
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case NotesSortOrder.updatedAsc:
        sorted.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      case NotesSortOrder.createdDesc:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case NotesSortOrder.createdAsc:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case NotesSortOrder.titleAsc:
        sorted.sort((a, b) => a.title.compareTo(b.title));
      case NotesSortOrder.titleDesc:
        sorted.sort((a, b) => b.title.compareTo(a.title));
    }

    return sorted;
  }

  void dispose() {
    _isolatePool.dispose();
  }
}

enum NotesSortOrder {
  updatedDesc,
  updatedAsc,
  createdDesc,
  createdAsc,
  titleAsc,
  titleDesc,
}
