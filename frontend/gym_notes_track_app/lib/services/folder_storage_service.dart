import '../database/database.dart';
import '../database/daos/folder_dao.dart';
import '../repositories/folder_repository.dart';
import '../models/folder.dart' as model;
import '../constants/app_constants.dart';

enum FoldersSortOrder {
  nameAsc,
  nameDesc,
  createdAsc,
  createdDesc,
  positionAsc,
  positionDesc,
}

class PaginatedFolders {
  final List<model.Folder> folders;
  final int currentPage;
  final int totalPages;
  final int totalCount;
  final bool hasMore;

  const PaginatedFolders({
    required this.folders,
    required this.currentPage,
    required this.totalPages,
    required this.totalCount,
    required this.hasMore,
  });

  PaginatedFolders copyWith({
    List<model.Folder>? folders,
    int? currentPage,
    int? totalPages,
    int? totalCount,
    bool? hasMore,
  }) {
    return PaginatedFolders(
      folders: folders ?? this.folders,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class FolderStorageService {
  static const int defaultPageSize = AppConstants.defaultPageSize;

  final FolderRepository _repository;
  bool _isInitialized = false;

  FolderStorageService({required FolderRepository repository})
    : _repository = repository;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  Future<PaginatedFolders> loadFoldersPaginated({
    String? parentId,
    int page = 1,
    int pageSize = defaultPageSize,
    FoldersSortOrder sortOrder = FoldersSortOrder.nameAsc,
  }) async {
    await initialize();

    final totalCount = await _repository.getFolderCount(parentId);
    final totalPages = (totalCount / pageSize).ceil().clamp(
      1,
      double.maxFinite.toInt(),
    );
    final offset = (page - 1) * pageSize;

    final (sortField, ascending) = _mapSortOrder(sortOrder);

    final folders = await _repository.getFoldersPaginated(
      parentId: parentId,
      limit: pageSize,
      offset: offset,
      sortField: sortField,
      ascending: ascending,
    );

    final modelFolders = folders.map(_folderToModel).toList();

    return PaginatedFolders(
      folders: modelFolders,
      currentPage: page,
      totalPages: totalPages,
      totalCount: totalCount,
      hasMore: page < totalPages,
    );
  }

  Future<List<model.Folder>> loadAllFoldersForParent(String? parentId) async {
    await initialize();
    final folders = await _repository.getFoldersByParent(parentId);
    return folders.map(_folderToModel).toList();
  }

  Future<model.Folder?> getFolderById(String folderId) async {
    await initialize();
    final folder = await _repository.getFolderById(folderId);
    return folder != null ? _folderToModel(folder) : null;
  }

  Future<int> getSubfolderCount(String folderId) async {
    await initialize();
    return _repository.getFolderCount(folderId);
  }

  Future<model.Folder> createFolder({
    required String name,
    String? parentId,
  }) async {
    await initialize();
    final folder = await _repository.createFolder(
      name: name,
      parentId: parentId,
    );
    return _folderToModel(folder);
  }

  Future<model.Folder?> updateFolder({
    required String folderId,
    String? name,
    String? parentId,
  }) async {
    await initialize();
    final folder = await _repository.updateFolder(
      id: folderId,
      name: name,
      parentId: parentId,
      updateParent: parentId != null,
    );
    return folder != null ? _folderToModel(folder) : null;
  }

  Future<void> deleteFolder(String folderId) async {
    await initialize();
    await _repository.deleteFolder(folderId);
  }

  /// Get the total note count that would be deleted with this folder
  Future<int> getNoteCountForDeletion(String folderId) async {
    await initialize();
    return _repository.getNoteCountForDeletion(folderId);
  }

  /// Reorder folders within a parent
  Future<void> reorderFolders({
    String? parentId,
    required List<String> orderedIds,
  }) async {
    await initialize();
    await _repository.reorderFolders(
      parentId: parentId,
      orderedIds: orderedIds,
    );
  }

  /// Update sort preferences for a folder
  Future<model.Folder?> updateFolderSortPreferences({
    required String folderId,
    String? noteSortOrder,
    String? subfolderSortOrder,
    bool clearNoteSortOrder = false,
    bool clearSubfolderSortOrder = false,
  }) async {
    await initialize();
    final folder = await _repository.updateFolderSortPreferences(
      id: folderId,
      noteSortOrder: noteSortOrder,
      subfolderSortOrder: subfolderSortOrder,
      clearNoteSortOrder: clearNoteSortOrder,
      clearSubfolderSortOrder: clearSubfolderSortOrder,
    );
    return folder != null ? _folderToModel(folder) : null;
  }

  model.Folder _folderToModel(Folder folder) {
    return model.Folder(
      id: folder.id,
      name: folder.name,
      parentId: folder.parentId,
      createdAt: folder.createdAt,
      noteSortOrder: folder.noteSortOrder,
      subfolderSortOrder: folder.subfolderSortOrder,
    );
  }

  (FolderSortField, bool) _mapSortOrder(FoldersSortOrder sortOrder) {
    switch (sortOrder) {
      case FoldersSortOrder.nameAsc:
        return (FolderSortField.name, true);
      case FoldersSortOrder.nameDesc:
        return (FolderSortField.name, false);
      case FoldersSortOrder.createdAsc:
        return (FolderSortField.createdAt, true);
      case FoldersSortOrder.createdDesc:
        return (FolderSortField.createdAt, false);
      case FoldersSortOrder.positionAsc:
        return (FolderSortField.position, true);
      case FoldersSortOrder.positionDesc:
        return (FolderSortField.position, false);
    }
  }

  void invalidateCache() {
    _repository.invalidateAll();
  }
}
