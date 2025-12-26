import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../models/folder.dart';
import '../../config/app_constants.dart';
import 'folder_event.dart';
import 'folder_state.dart';

class FolderBloc extends Bloc<FolderEvent, FolderState> {
  final List<Folder> _folders = [];
  final Uuid _uuid = const Uuid();

  FolderBloc() : super(FolderInitial()) {
    on<LoadFolders>(_onLoadFolders);
    on<CreateFolder>(_onCreateFolder);
    on<DeleteFolder>(_onDeleteFolder);
    on<UpdateFolder>(_onUpdateFolder);
  }

  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = _folders.map((f) => f.toJson()).toList();
    await prefs.setString(
      AppConstants.foldersStorageKey,
      jsonEncode(foldersJson),
    );
  }

  Future<void> _loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final foldersString = prefs.getString(AppConstants.foldersStorageKey);
    if (foldersString != null) {
      final List<dynamic> foldersJson = jsonDecode(foldersString);
      _folders.clear();
      _folders.addAll(
        foldersJson.map(
          (json) => Folder.fromJson(json as Map<String, dynamic>),
        ),
      );
    }
  }

  Future<void> _onLoadFolders(
    LoadFolders event,
    Emitter<FolderState> emit,
  ) async {
    emit(FolderLoading());
    try {
      await _loadFolders();
      emit(FolderLoaded(List.from(_folders)));
    } catch (e) {
      emit(FolderError('Failed to load folders: $e'));
    }
  }

  Future<void> _onCreateFolder(
    CreateFolder event,
    Emitter<FolderState> emit,
  ) async {
    try {
      final newFolder = Folder(
        id: _uuid.v4(),
        name: event.name,
        parentId: event.parentId,
        createdAt: DateTime.now(),
      );
      _folders.add(newFolder);
      await _saveFolders();
      emit(FolderLoaded(List.from(_folders)));
    } catch (e) {
      emit(FolderError('Failed to create folder: $e'));
    }
  }

  Future<void> _onDeleteFolder(
    DeleteFolder event,
    Emitter<FolderState> emit,
  ) async {
    try {
      _folders.removeWhere((folder) => folder.id == event.folderId);
      await _saveFolders();
      emit(FolderLoaded(List.from(_folders)));
    } catch (e) {
      emit(FolderError('Failed to delete folder: $e'));
    }
  }

  Future<void> _onUpdateFolder(
    UpdateFolder event,
    Emitter<FolderState> emit,
  ) async {
    try {
      final index = _folders.indexWhere((f) => f.id == event.folderId);
      if (index != -1) {
        _folders[index] = _folders[index].copyWith(name: event.newName);
        await _saveFolders();
        emit(FolderLoaded(List.from(_folders)));
      }
    } catch (e) {
      emit(FolderError('Failed to update folder: $e'));
    }
  }
}
