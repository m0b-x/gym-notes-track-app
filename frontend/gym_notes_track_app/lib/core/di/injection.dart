import 'package:get_it/get_it.dart';
import '../../database/database.dart';
import '../../repositories/note_repository.dart';
import '../../repositories/folder_repository.dart';
import '../../services/folder_storage_service.dart';
import '../../services/note_storage_service.dart';
import '../../services/search_service.dart';
import '../../bloc/optimized_folder/optimized_folder_bloc.dart';
import '../../bloc/optimized_note/optimized_note_bloc.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  await _registerDatabase();
  _registerRepositories();
  await _registerServices();
  _registerBlocs();
}

Future<void> _registerDatabase() async {
  final database = await AppDatabase.getInstance();
  getIt.registerSingleton<AppDatabase>(database);
}

void _registerRepositories() {
  final db = getIt<AppDatabase>();

  getIt.registerSingleton<NoteRepository>(NoteRepository(database: db));

  getIt.registerSingleton<FolderRepository>(FolderRepository(database: db));
}

Future<void> _registerServices() async {
  final folderStorageService = FolderStorageService(
    repository: getIt<FolderRepository>(),
  );
  await folderStorageService.initialize();
  getIt.registerSingleton<FolderStorageService>(folderStorageService);

  final noteStorageService = NoteStorageService(
    repository: getIt<NoteRepository>(),
  );
  await noteStorageService.initialize();
  getIt.registerSingleton<NoteStorageService>(noteStorageService);

  final searchService = SearchService(storageService: noteStorageService);
  await searchService.initialize();
  getIt.registerSingleton<SearchService>(searchService);
}

void _registerBlocs() {
  getIt.registerFactory<OptimizedFolderBloc>(
    () => OptimizedFolderBloc(storageService: getIt<FolderStorageService>()),
  );

  getIt.registerFactory<OptimizedNoteBloc>(
    () => OptimizedNoteBloc(
      storageService: getIt<NoteStorageService>(),
      searchService: getIt<SearchService>(),
    ),
  );
}

Future<void> resetDependencies() async {
  await getIt.reset();
}
