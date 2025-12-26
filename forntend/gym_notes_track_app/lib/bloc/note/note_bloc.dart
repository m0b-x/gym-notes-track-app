import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../models/note.dart';
import 'note_event.dart';
import 'note_state.dart';

class NoteBloc extends Bloc<NoteEvent, NoteState> {
  static const String _storageKey = 'notes';
  final List<Note> _notes = [];
  final Uuid _uuid = const Uuid();

  NoteBloc() : super(NoteInitial()) {
    on<LoadNotes>(_onLoadNotes);
    on<CreateNote>(_onCreateNote);
    on<UpdateNote>(_onUpdateNote);
    on<DeleteNote>(_onDeleteNote);
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = _notes.map((n) => n.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(notesJson));
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesString = prefs.getString(_storageKey);
    if (notesString != null) {
      final List<dynamic> notesJson = jsonDecode(notesString);
      _notes.clear();
      _notes.addAll(
        notesJson.map((json) => Note.fromJson(json as Map<String, dynamic>)),
      );
    }
  }

  Future<void> _onLoadNotes(LoadNotes event, Emitter<NoteState> emit) async {
    emit(NoteLoading());
    try {
      await _loadNotes();

      final folderNotes = _notes
          .where((note) => note.folderId == event.folderId)
          .toList();

      emit(NoteLoaded(folderNotes));
    } catch (e) {
      emit(NoteError('Failed to load notes: $e'));
    }
  }

  Future<void> _onCreateNote(CreateNote event, Emitter<NoteState> emit) async {
    try {
      final now = DateTime.now();
      final newNote = Note(
        id: _uuid.v4(),
        folderId: event.folderId,
        title: event.title,
        content: event.content,
        createdAt: now,
        updatedAt: now,
      );
      _notes.add(newNote);
      await _saveNotes();

      final folderNotes = _notes
          .where((note) => note.folderId == event.folderId)
          .toList();
      emit(NoteLoaded(folderNotes));
    } catch (e) {
      emit(NoteError('Failed to create note: $e'));
    }
  }

  Future<void> _onUpdateNote(UpdateNote event, Emitter<NoteState> emit) async {
    try {
      final index = _notes.indexWhere((n) => n.id == event.noteId);
      if (index != -1) {
        final updatedNote = _notes[index].copyWith(
          title: event.title ?? _notes[index].title,
          content: event.content ?? _notes[index].content,
          updatedAt: DateTime.now(),
        );
        _notes[index] = updatedNote;
        await _saveNotes();

        final folderNotes = _notes
            .where((note) => note.folderId == updatedNote.folderId)
            .toList();
        emit(NoteLoaded(folderNotes));
      }
    } catch (e) {
      emit(NoteError('Failed to update note: $e'));
    }
  }

  Future<void> _onDeleteNote(DeleteNote event, Emitter<NoteState> emit) async {
    try {
      final note = _notes.firstWhere((n) => n.id == event.noteId);
      final folderId = note.folderId;

      _notes.removeWhere((n) => n.id == event.noteId);
      await _saveNotes();

      final folderNotes = _notes
          .where((note) => note.folderId == folderId)
          .toList();
      emit(NoteLoaded(folderNotes));
    } catch (e) {
      emit(NoteError('Failed to delete note: $e'));
    }
  }
}
