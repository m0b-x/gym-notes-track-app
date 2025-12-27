import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gym_notes_track_app/l10n/app_localizations.dart';
import 'bloc/optimized_folder/optimized_folder_bloc.dart';
import 'bloc/optimized_note/optimized_note_bloc.dart';
import 'services/folder_storage_service.dart';
import 'services/note_storage_service.dart';
import 'services/search_service.dart';
import 'utils/isolate_worker.dart';
import 'pages/optimized_folder_content_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isolatePool = IsolatePool(poolSize: 2);
  await isolatePool.initialize();

  final folderStorageService = FolderStorageService(isolatePool: isolatePool);
  await folderStorageService.initialize();

  final noteStorageService = NoteStorageService(isolatePool: isolatePool);
  await noteStorageService.initialize();

  final searchService = SearchService(
    storageService: noteStorageService,
    isolatePool: isolatePool,
  );
  await searchService.initialize();

  runApp(
    MyApp(
      isolatePool: isolatePool,
      folderStorageService: folderStorageService,
      noteStorageService: noteStorageService,
      searchService: searchService,
    ),
  );
}

class MyApp extends StatefulWidget {
  final IsolatePool isolatePool;
  final FolderStorageService folderStorageService;
  final NoteStorageService noteStorageService;
  final SearchService searchService;

  const MyApp({
    super.key,
    required this.isolatePool,
    required this.folderStorageService,
    required this.noteStorageService,
    required this.searchService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    widget.isolatePool.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              OptimizedFolderBloc(storageService: widget.folderStorageService),
        ),
        BlocProvider(
          create: (context) => OptimizedNoteBloc(
            storageService: widget.noteStorageService,
            searchService: widget.searchService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Gym Notes',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('de')],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const OptimizedFolderContentPage(
          folderId: null,
          title: 'Gym Notes',
        ),
      ),
    );
  }
}
