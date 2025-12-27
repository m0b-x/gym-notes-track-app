import 'package:equatable/equatable.dart';
import '../../services/folder_storage_service.dart';

abstract class OptimizedFolderState extends Equatable {
  const OptimizedFolderState();

  @override
  List<Object?> get props => [];
}

class OptimizedFolderInitial extends OptimizedFolderState {}

class OptimizedFolderLoading extends OptimizedFolderState {
  final String? parentId;

  const OptimizedFolderLoading({this.parentId});

  @override
  List<Object?> get props => [parentId];
}

class OptimizedFolderLoaded extends OptimizedFolderState {
  final PaginatedFolders paginatedFolders;
  final bool isLoadingMore;
  final String? parentId;

  const OptimizedFolderLoaded({
    required this.paginatedFolders,
    this.isLoadingMore = false,
    this.parentId,
  });

  OptimizedFolderLoaded copyWith({
    PaginatedFolders? paginatedFolders,
    bool? isLoadingMore,
    String? parentId,
  }) {
    return OptimizedFolderLoaded(
      paginatedFolders: paginatedFolders ?? this.paginatedFolders,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      parentId: parentId ?? this.parentId,
    );
  }

  @override
  List<Object?> get props => [paginatedFolders, isLoadingMore, parentId];
}

class OptimizedFolderError extends OptimizedFolderState {
  final String message;
  final String? parentId;

  const OptimizedFolderError(this.message, {this.parentId});

  @override
  List<Object?> get props => [message, parentId];
}
