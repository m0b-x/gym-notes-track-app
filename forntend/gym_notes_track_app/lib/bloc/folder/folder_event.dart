import 'package:equatable/equatable.dart';

abstract class FolderEvent extends Equatable {
  const FolderEvent();

  @override
  List<Object?> get props => [];
}

class LoadFolders extends FolderEvent {}

class CreateFolder extends FolderEvent {
  final String name;
  final String? parentId;

  const CreateFolder(this.name, {this.parentId});

  @override
  List<Object?> get props => [name, parentId];
}

class DeleteFolder extends FolderEvent {
  final String folderId;

  const DeleteFolder(this.folderId);

  @override
  List<Object?> get props => [folderId];
}

class UpdateFolder extends FolderEvent {
  final String folderId;
  final String newName;

  const UpdateFolder(this.folderId, this.newName);

  @override
  List<Object?> get props => [folderId, newName];
}
