import 'package:get_it/get_it.dart';
import '../../database/database.dart';
import '../../repositories/note_repository.dart';
import '../../repositories/folder_repository.dart';
import '../../services/folder_storage_service.dart';
import '../../services/note_storage_service.dart';
import '../../services/folder_search_service.dart';
import '../../services/markdown_bar_service.dart';
import '../../services/counter_service.dart';
import '../../services/mixed_reorder_service.dart';
import '../../services/move_history_service.dart';
import '../../services/move_history_store.dart';
import '../../services/recent_destinations_service.dart';
import '../../services/folder_name_index.dart';
import '../../bloc/optimized_folder/optimized_folder_bloc.dart';
import '../../bloc/optimized_note/optimized_note_bloc.dart';
import '../../bloc/markdown_bar/markdown_bar_bloc.dart';
import '../../bloc/counter/counter_bloc.dart';

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

  final folderSearchService = FolderSearchService(
    storageService: noteStorageService,
  );
  await folderSearchService.initialize();
  getIt.registerSingleton<FolderSearchService>(folderSearchService);

  final markdownBarService = await MarkdownBarService.getInstance();
  getIt.registerSingleton<MarkdownBarService>(markdownBarService);

  final counterService = await CounterService.getInstance();
  getIt.registerSingleton<CounterService>(counterService);

  getIt.registerSingleton<MoveHistoryService>(
    MoveHistoryService(store: InMemoryMoveHistoryStore()),
    dispose: (s) => s.dispose(),
  );

  getIt.registerSingleton<RecentDestinationsService>(
    RecentDestinationsService(),
    dispose: (s) => s.dispose(),
  );

  getIt.registerSingleton<FolderNameIndex>(
    FolderNameIndex(folderService: folderStorageService),
    dispose: (s) => s.dispose(),
  );

  getIt.registerSingleton<MixedReorderService>(
    MixedReorderService(
      folderRepository: getIt<FolderRepository>(),
      noteRepository: getIt<NoteRepository>(),
    ),
  );
}

void _registerBlocs() {
  getIt.registerFactory<OptimizedFolderBloc>(
    () => OptimizedFolderBloc(storageService: getIt<FolderStorageService>()),
  );

  getIt.registerFactory<OptimizedNoteBloc>(
    () => OptimizedNoteBloc(
      storageService: getIt<NoteStorageService>(),
      searchService: getIt<FolderSearchService>(),
    ),
  );

  getIt.registerFactory<MarkdownBarBloc>(
    () => MarkdownBarBloc(barService: getIt<MarkdownBarService>()),
  );

  getIt.registerFactory<CounterBloc>(
    () => CounterBloc(counterService: getIt<CounterService>()),
  );
}

Future<void> resetDependencies() async {
  await getIt.reset();
}
