import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gym_notes_track_app/l10n/app_localizations.dart';
import 'bloc/optimized_folder/optimized_folder_bloc.dart';
import 'bloc/optimized_note/optimized_note_bloc.dart';
import 'core/di/injection.dart';
import 'pages/optimized_folder_content_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await configureDependencies();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<OptimizedFolderBloc>()),
        BlocProvider(create: (_) => getIt<OptimizedNoteBloc>()),
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
