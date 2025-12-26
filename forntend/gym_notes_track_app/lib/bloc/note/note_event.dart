import 'package:equatable/equatable.dart';

/// Base class for all note events
abstract class NoteEvent extends Equatable {
  const NoteEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load notes for a specific folder
class LoadNotes extends NoteEvent {
  final String folderId;

  const LoadNotes(this.folderId);

  @override
  List<Object?> get props => [folderId];
}

/// Event to create a new note
class CreateNote extends NoteEvent {
  final String folderId;
  final String title;
  final String content;

  const CreateNote({
    required this.folderId,
    required this.title,
    required this.content,
  });

  @override
  List<Object?> get props => [folderId, title, content];
}

class UpdateNote extends NoteEvent {
  final String noteId;
  final String? title;
  final String? content;

  const UpdateNote({
    required this.noteId,
    this.title,
    this.content,
  });

  @override
  List<Object?> get props => [noteId, title, content];
}

class DeleteNote extends NoteEvent {
  final String noteId;

  const DeleteNote(this.noteId);

  @override
  List<Object?> get props => [noteId];
}
