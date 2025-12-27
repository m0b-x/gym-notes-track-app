import 'package:equatable/equatable.dart';
import '../../services/folder_storage_service.dart';

abstract class OptimizedFolderState extends Equatable {
  const OptimizedFolderState();

  @override
  List<Object?> get props => [];
}

class OptimizedFolderInitial extends OptimizedFolderState {}

class OptimizedFolderLoading extends OptimizedFolderState {}

class OptimizedFolderLoaded extends OptimizedFolderState {
  final PaginatedFolders paginatedFolders;
  final bool isLoadingMore;

  const OptimizedFolderLoaded({
    required this.paginatedFolders,
    this.isLoadingMore = false,
  });

  OptimizedFolderLoaded copyWith({
    PaginatedFolders? paginatedFolders,
    bool? isLoadingMore,
  }) {
    return OptimizedFolderLoaded(
      paginatedFolders: paginatedFolders ?? this.paginatedFolders,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [paginatedFolders, isLoadingMore];
}

class OptimizedFolderError extends OptimizedFolderState {
  final String message;

  const OptimizedFolderError(this.message);

  @override
  List<Object?> get props => [message];
}
