import 'dart:async';
import '../database/database.dart';
import '../database/daos/folder_dao.dart';
import '../constants/app_constants.dart';

/// Event types for folder changes
enum FolderChangeType { created, updated, deleted }

/// Represents a change to a folder
class FolderChange {
  final FolderChangeType type;
  final String folderId;
  final String? parentId;
  final Folder? folder;

  const FolderChange({
    required this.type,
    required this.folderId,
    this.parentId,
    this.folder,
  });
}

class FolderRepository {
  final AppDatabase _db;

  final Map<String, Folder> _folderCache = {};
  final Map<String?, List<Folder>> _parentFoldersCache = {};
  final Map<String?, int> _countCache = {};

  static const int _maxFolderCacheSize = AppConstants.maxFolderCacheSize;
  static const Duration _cacheExpiry = AppConstants.cacheExpiry;

  DateTime? _lastCacheClean;

  /// Stream controller for folder changes (reactive updates)
  final _folderChangesController = StreamController<FolderChange>.broadcast();

  /// Stream of all folder changes for reactive UI updates
  Stream<FolderChange> get folderChanges => _folderChangesController.stream;

  /// Stream of changes filtered by parent folder
  Stream<FolderChange> folderChangesForParent(String? parentId) {
    return _folderChangesController.stream.where(
      (change) => change.parentId == parentId,
    );
  }

  FolderRepository({required AppDatabase database}) : _db = database;

  FolderDao get _folderDao => _db.folderDao;

  Future<Folder?> getFolderById(String id, {bool forceRefresh = false}) async {
    _cleanCacheIfNeeded();

    if (!forceRefresh && _folderCache.containsKey(id)) {
      return _folderCache[id];
    }

    final folder = await _folderDao.getFolderById(id);
    if (folder != null) {
      _folderCache[id] = folder;
      _trimFolderCache();
    }
    return folder;
  }

  Future<List<Folder>> getAllFolders({
    bool includeDeleted = false,
    bool forceRefresh = false,
  }) async {
    final folders = await _folderDao.getAllFolders(
      includeDeleted: includeDeleted,
    );

    for (final folder in folders) {
      _folderCache[folder.id] = folder;
    }
    _trimFolderCache();

    return folders;
  }

  Future<List<Folder>> getFoldersByParent(
    String? parentId, {
    bool includeDeleted = false,
    bool forceRefresh = false,
  }) async {
    _cleanCacheIfNeeded();

    final cacheKey = parentId;
    if (!forceRefresh &&
        !includeDeleted &&
        _parentFoldersCache.containsKey(cacheKey)) {
      return _parentFoldersCache[cacheKey]!;
    }

    final folders = await _folderDao.getFoldersByParent(
      parentId,
      includeDeleted: includeDeleted,
    );

    if (!includeDeleted) {
      _parentFoldersCache[cacheKey] = folders;
    }

    for (final folder in folders) {
      _folderCache[folder.id] = folder;
    }
    _trimFolderCache();

    return folders;
  }

  Future<int> getFolderCount(
    String? parentId, {
    bool includeDeleted = false,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && !includeDeleted && _countCache.containsKey(parentId)) {
      return _countCache[parentId]!;
    }

    final count = await _folderDao.getFolderCount(
      parentId,
      includeDeleted: includeDeleted,
    );

    if (!includeDeleted) {
      _countCache[parentId] = count;
    }

    return count;
  }

  Future<List<Folder>> getFoldersPaginated({
    String? parentId,
    required int limit,
    required int offset,
    required FolderSortField sortField,
    required bool ascending,
  }) async {
    final folders = await _folderDao.getFoldersPaginated(
      parentId: parentId,
      limit: limit,
      offset: offset,
      sortField: sortField,
      ascending: ascending,
    );

    for (final folder in folders) {
      _folderCache[folder.id] = folder;
    }
    _trimFolderCache();

    return folders;
  }

  Future<Folder> createFolder({required String name, String? parentId}) async {
    final folder = await _folderDao.createFolder(
      name: name,
      parentId: parentId,
    );

    _folderCache[folder.id] = folder;
    _invalidateParentCache(parentId);

    // Emit change event for reactive updates
    _folderChangesController.add(
      FolderChange(
        type: FolderChangeType.created,
        folderId: folder.id,
        parentId: parentId,
        folder: folder,
      ),
    );

    return folder;
  }

  Future<Folder?> updateFolder({
    required String id,
    String? name,
    String? parentId,
    bool updateParent = false,
  }) async {
    final existing = await getFolderById(id);
    final oldParentId = existing?.parentId;

    final folder = await _folderDao.updateFolder(
      id: id,
      name: name,
      parentId: parentId,
      updateParent: updateParent,
    );

    if (folder != null) {
      _folderCache[id] = folder;

      if (updateParent) {
        _invalidateParentCache(oldParentId);
        _invalidateParentCache(parentId);
      } else {
        _invalidateParentCache(folder.parentId);
      }

      // Emit change event for reactive updates
      _folderChangesController.add(
        FolderChange(
          type: FolderChangeType.updated,
          folderId: id,
          parentId: folder.parentId,
          folder: folder,
        ),
      );
    }

    return folder;
  }

  Future<void> deleteFolder(String id) async {
    final folder = await getFolderById(id);

    await _folderDao.softDeleteFolderWithDescendants(id);

    _folderCache.remove(id);
    if (folder != null) {
      _invalidateParentCache(folder.parentId);

      // Emit change event for reactive updates
      _folderChangesController.add(
        FolderChange(
          type: FolderChangeType.deleted,
          folderId: id,
          parentId: folder.parentId,
        ),
      );
    }

    final descendants = await _folderDao.getAllDescendantIds(id);
    for (final descendantId in descendants) {
      _folderCache.remove(descendantId);
    }
  }

  /// Get the total note count that would be deleted with this folder
  Future<int> getNoteCountForDeletion(String folderId) async {
    return _folderDao.getNoteCountWithDescendants(folderId);
  }

  /// Reorder folders within a parent
  Future<void> reorderFolders({
    String? parentId,
    required List<String> orderedIds,
  }) async {
    await _folderDao.reorderFolders(parentId: parentId, orderedIds: orderedIds);
    _invalidateParentCache(parentId);

    // Emit change events for all reordered folders
    for (final folderId in orderedIds) {
      final folder = await getFolderById(folderId, forceRefresh: true);
      if (folder != null) {
        _folderChangesController.add(
          FolderChange(
            type: FolderChangeType.updated,
            folderId: folderId,
            parentId: parentId,
            folder: _folderCache[folderId],
          ),
        );
      }
    }
  }

  /// Update sort preferences for a folder
  Future<Folder?> updateFolderSortPreferences({
    required String id,
    String? noteSortOrder,
    String? subfolderSortOrder,
    bool clearNoteSortOrder = false,
    bool clearSubfolderSortOrder = false,
  }) async {
    final folder = await _folderDao.updateFolderSortPreferences(
      id: id,
      noteSortOrder: noteSortOrder,
      subfolderSortOrder: subfolderSortOrder,
      clearNoteSortOrder: clearNoteSortOrder,
      clearSubfolderSortOrder: clearSubfolderSortOrder,
    );

    if (folder != null) {
      _folderCache[id] = folder;
      _invalidateParentCache(folder.parentId);

      // Emit change event for reactive updates
      _folderChangesController.add(
        FolderChange(
          type: FolderChangeType.updated,
          folderId: id,
          parentId: folder.parentId,
          folder: folder,
        ),
      );
    }

    return folder;
  }

  Future<List<String>> getAllDescendantIds(String folderId) {
    return _folderDao.getAllDescendantIds(folderId);
  }

  Future<List<Folder>> getFoldersSince(String hlcTimestamp) {
    return _folderDao.getFoldersSince(hlcTimestamp);
  }

  Future<void> mergeFolder(Folder remote) async {
    await _folderDao.mergeFolder(remote);
    _folderCache.remove(remote.id);
    _invalidateParentCache(remote.parentId);
  }

  void _invalidateParentCache(String? parentId) {
    _parentFoldersCache.remove(parentId);
    _countCache.remove(parentId);
  }

  void invalidateAll() {
    _folderCache.clear();
    _parentFoldersCache.clear();
    _countCache.clear();
  }

  void _trimFolderCache() {
    if (_folderCache.length > _maxFolderCacheSize) {
      final keysToRemove = _folderCache.keys
          .take(_folderCache.length - _maxFolderCacheSize)
          .toList();
      for (final key in keysToRemove) {
        _folderCache.remove(key);
      }
    }
  }

  void _cleanCacheIfNeeded() {
    final now = DateTime.now();
    if (_lastCacheClean == null ||
        now.difference(_lastCacheClean!) > _cacheExpiry) {
      _parentFoldersCache.clear();
      _countCache.clear();
      _lastCacheClean = now;
    }
  }

  /// Dispose resources
  void dispose() {
    _folderChangesController.close();
  }
}
