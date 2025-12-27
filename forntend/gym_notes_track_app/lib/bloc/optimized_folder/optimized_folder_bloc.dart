import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/folder_storage_service.dart';
import 'optimized_folder_event.dart';
import 'optimized_folder_state.dart';

class OptimizedFolderBloc
    extends Bloc<OptimizedFolderEvent, OptimizedFolderState> {
  final FolderStorageService _storageService;

  String? _currentParentId;
  int _currentPage = 1;
  FoldersSortOrder _currentSortOrder = FoldersSortOrder.nameAsc;

  OptimizedFolderBloc({FolderStorageService? storageService})
    : _storageService = storageService ?? FolderStorageService(),
      super(OptimizedFolderInitial()) {
    on<LoadFoldersPaginated>(_onLoadFoldersPaginated);
    on<LoadMoreFolders>(_onLoadMoreFolders);
    on<CreateOptimizedFolder>(_onCreateFolder);
    on<UpdateOptimizedFolder>(_onUpdateFolder);
    on<DeleteOptimizedFolder>(_onDeleteFolder);
    on<RefreshFolders>(_onRefreshFolders);
  }

  Future<void> _onLoadFoldersPaginated(
    LoadFoldersPaginated event,
    Emitter<OptimizedFolderState> emit,
  ) async {
    emit(OptimizedFolderLoading());

    try {
      await _storageService.initialize();

      _currentParentId = event.parentId;
      _currentPage = event.page;
      _currentSortOrder = event.sortOrder;

      final paginatedFolders = await _storageService.loadFoldersPaginated(
        parentId: event.parentId,
        page: event.page,
        pageSize: event.pageSize,
        sortOrder: event.sortOrder,
      );

      emit(OptimizedFolderLoaded(paginatedFolders: paginatedFolders));
    } catch (e) {
      emit(OptimizedFolderError('Failed to load folders: $e'));
    }
  }

  Future<void> _onLoadMoreFolders(
    LoadMoreFolders event,
    Emitter<OptimizedFolderState> emit,
  ) async {
    final currentState = state;

    if (currentState is! OptimizedFolderLoaded) return;
    if (!currentState.paginatedFolders.hasMore) return;
    if (currentState.isLoadingMore) return;

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      _currentPage++;

      final morePaginatedFolders = await _storageService.loadFoldersPaginated(
        parentId: event.parentId ?? _currentParentId,
        page: _currentPage,
        sortOrder: _currentSortOrder,
      );

      final combinedFolders = [
        ...currentState.paginatedFolders.folders,
        ...morePaginatedFolders.folders,
      ];

      final updatedPaginatedFolders = morePaginatedFolders.copyWith(
        folders: combinedFolders,
      );

      emit(
        currentState.copyWith(
          paginatedFolders: updatedPaginatedFolders,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onCreateFolder(
    CreateOptimizedFolder event,
    Emitter<OptimizedFolderState> emit,
  ) async {
    try {
      await _storageService.createFolder(
        name: event.name,
        parentId: event.parentId,
      );

      add(RefreshFolders(parentId: event.parentId));
    } catch (e) {
      emit(OptimizedFolderError('Failed to create folder: $e'));
    }
  }

  Future<void> _onUpdateFolder(
    UpdateOptimizedFolder event,
    Emitter<OptimizedFolderState> emit,
  ) async {
    try {
      final folder = await _storageService.getFolderById(event.folderId);

      await _storageService.updateFolder(
        folderId: event.folderId,
        name: event.name,
      );

      add(RefreshFolders(parentId: folder?.parentId));
    } catch (e) {
      emit(OptimizedFolderError('Failed to update folder: $e'));
    }
  }

  Future<void> _onDeleteFolder(
    DeleteOptimizedFolder event,
    Emitter<OptimizedFolderState> emit,
  ) async {
    try {
      await _storageService.deleteFolder(event.folderId);

      add(RefreshFolders(parentId: event.parentId));
    } catch (e) {
      emit(OptimizedFolderError('Failed to delete folder: $e'));
    }
  }

  Future<void> _onRefreshFolders(
    RefreshFolders event,
    Emitter<OptimizedFolderState> emit,
  ) async {
    _storageService.clearCache();
    _currentPage = 1;

    add(
      LoadFoldersPaginated(
        parentId: event.parentId ?? _currentParentId,
        sortOrder: _currentSortOrder,
      ),
    );
  }
}
