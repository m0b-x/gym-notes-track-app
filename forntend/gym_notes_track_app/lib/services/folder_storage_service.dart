import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/folder.dart';
import '../utils/isolate_worker.dart';

enum FoldersSortOrder { nameAsc, nameDesc, createdAsc, createdDesc }

class PaginatedFolders {
  final List<Folder> folders;
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
    List<Folder>? folders,
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
  static const String _foldersStorageKey = 'optimized_folders';
  static const int defaultPageSize = 20;

  final Uuid _uuid;
  final IsolatePool _isolatePool;

  List<Folder>? _foldersCache;
  bool _isInitialized = false;

  FolderStorageService({Uuid? uuid, IsolatePool? isolatePool})
    : _uuid = uuid ?? const Uuid(),
      _isolatePool = isolatePool ?? IsolatePool();

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _isolatePool.initialize();
    await _migrateIfNeeded();
    _isInitialized = true;
  }

  Future<void> _migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyFolders = prefs.getString('folders');

    if (legacyFolders == null) return;

    final existingOptimized = prefs.getString(_foldersStorageKey);
    if (existingOptimized != null) return;

    final result = await _isolatePool.execute<List<dynamic>>(
      'jsonDecode',
      legacyFolders,
    );

    if (!result.isSuccess || result.data == null) return;

    await prefs.setString(_foldersStorageKey, legacyFolders);
  }

  Future<PaginatedFolders> loadFoldersPaginated({
    String? parentId,
    int page = 1,
    int pageSize = defaultPageSize,
    FoldersSortOrder sortOrder = FoldersSortOrder.nameAsc,
  }) async {
    await initialize();

    final allFolders = await _loadAllFolders();

    var filteredFolders = allFolders
        .where((f) => f.parentId == parentId)
        .toList();

    filteredFolders = _sortFolders(filteredFolders, sortOrder);

    final totalCount = filteredFolders.length;
    final totalPages = (totalCount / pageSize).ceil().clamp(
      1,
      double.maxFinite.toInt(),
    );
    final startIndex = (page - 1) * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, totalCount);

    final pageFolders = startIndex < totalCount
        ? filteredFolders.sublist(startIndex, endIndex)
        : <Folder>[];

    return PaginatedFolders(
      folders: pageFolders,
      currentPage: page,
      totalPages: totalPages,
      totalCount: totalCount,
      hasMore: page < totalPages,
    );
  }

  Future<List<Folder>> loadAllFoldersForParent(String? parentId) async {
    await initialize();

    final allFolders = await _loadAllFolders();
    return allFolders.where((f) => f.parentId == parentId).toList();
  }

  Future<Folder?> getFolderById(String folderId) async {
    await initialize();

    final allFolders = await _loadAllFolders();
    try {
      return allFolders.firstWhere((f) => f.id == folderId);
    } catch (_) {
      return null;
    }
  }

  Future<int> getSubfolderCount(String folderId) async {
    await initialize();

    final allFolders = await _loadAllFolders();
    return allFolders.where((f) => f.parentId == folderId).length;
  }

  Future<Folder> createFolder({required String name, String? parentId}) async {
    await initialize();

    final now = DateTime.now();
    final folder = Folder(
      id: _uuid.v4(),
      name: name,
      parentId: parentId,
      createdAt: now,
    );

    final allFolders = await _loadAllFolders();
    allFolders.add(folder);
    await _saveFolders(allFolders);

    _foldersCache = null;

    return folder;
  }

  Future<Folder?> updateFolder({
    required String folderId,
    String? name,
    String? parentId,
  }) async {
    await initialize();

    final allFolders = await _loadAllFolders();
    final index = allFolders.indexWhere((f) => f.id == folderId);

    if (index == -1) return null;

    final updatedFolder = allFolders[index].copyWith(
      name: name,
      parentId: parentId,
    );

    allFolders[index] = updatedFolder;
    await _saveFolders(allFolders);

    _foldersCache = null;

    return updatedFolder;
  }

  Future<void> deleteFolder(String folderId) async {
    await initialize();

    final allFolders = await _loadAllFolders();

    final idsToDelete = _getAllDescendantIds(folderId, allFolders);
    idsToDelete.add(folderId);

    allFolders.removeWhere((f) => idsToDelete.contains(f.id));
    await _saveFolders(allFolders);

    _foldersCache = null;
  }

  Set<String> _getAllDescendantIds(String folderId, List<Folder> allFolders) {
    final descendants = <String>{};
    final directChildren = allFolders.where((f) => f.parentId == folderId);

    for (final child in directChildren) {
      descendants.add(child.id);
      descendants.addAll(_getAllDescendantIds(child.id, allFolders));
    }

    return descendants;
  }

  Future<List<Folder>> _loadAllFolders() async {
    if (_foldersCache != null) return List.from(_foldersCache!);

    final prefs = await SharedPreferences.getInstance();
    final foldersString = prefs.getString(_foldersStorageKey);

    if (foldersString == null) {
      _foldersCache = [];
      return [];
    }

    final result = await _isolatePool.execute<List<dynamic>>(
      'jsonDecode',
      foldersString,
    );

    if (!result.isSuccess || result.data == null) {
      _foldersCache = [];
      return [];
    }

    final folders = result.data!
        .map((json) => Folder.fromJson(json as Map<String, dynamic>))
        .toList();

    _foldersCache = folders;
    return List.from(folders);
  }

  Future<void> _saveFolders(List<Folder> folders) async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = folders.map((f) => f.toJson()).toList();

    final result = await _isolatePool.execute<String>(
      'jsonEncode',
      foldersJson,
    );

    if (result.isSuccess && result.data != null) {
      await prefs.setString(_foldersStorageKey, result.data!);
    } else {
      await prefs.setString(_foldersStorageKey, jsonEncode(foldersJson));
    }

    _foldersCache = folders;
  }

  List<Folder> _sortFolders(List<Folder> folders, FoldersSortOrder sortOrder) {
    final sorted = List<Folder>.from(folders);

    switch (sortOrder) {
      case FoldersSortOrder.nameAsc:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case FoldersSortOrder.nameDesc:
        sorted.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
      case FoldersSortOrder.createdAsc:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case FoldersSortOrder.createdDesc:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return sorted;
  }

  void clearCache() {
    _foldersCache = null;
  }
}
