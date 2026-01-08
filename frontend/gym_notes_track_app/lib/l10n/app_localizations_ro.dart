// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get appTitle => 'Gym Notes';

  @override
  String get folders => 'Foldere';

  @override
  String get notes => 'Notițe';

  @override
  String get createFolder => 'Crează Folder';

  @override
  String get createNote => 'Crează Notiță';

  @override
  String get folderName => 'Nume Folder';

  @override
  String get noteName => 'Nume Notiță';

  @override
  String get cancel => 'Anulează';

  @override
  String get create => 'Crează';

  @override
  String get edit => 'Editează';

  @override
  String get delete => 'Șterge';

  @override
  String get save => 'Salvează';

  @override
  String get search => 'Caută';

  @override
  String error(String message) {
    return 'Eroare: $message';
  }

  @override
  String created(String date) {
    return 'Creat: $date';
  }

  @override
  String updated(String date) {
    return 'Actualizat: $date';
  }

  @override
  String get deleteFolder => 'Șterge Folder';

  @override
  String deleteFolderConfirm(String name) {
    return 'Ești sigur că vrei să ștergi \"$name\"?';
  }

  @override
  String deleteFolderWithNotesConfirm(String name, int count) {
    return 'Ești sigur că vrei să ștergi \"$name\"? Aceasta va șterge și $count notiță(e).';
  }

  @override
  String get rename => 'Redenumește';

  @override
  String get renameFolder => 'Redenumește Folder';

  @override
  String get untitledNote => 'Notiță fără titlu';

  @override
  String get emptyNote => 'Notiță goală';

  @override
  String get deleteNote => 'Șterge Notiță';

  @override
  String deleteNoteConfirm(String title) {
    return 'Ești sigur că vrei să ștergi \"$title\"?';
  }

  @override
  String get deleteThisNote => 'această notiță';

  @override
  String get enterFolderName => 'Introdu numele folderului';

  @override
  String get newNote => 'Notiță Nouă';

  @override
  String get switchToEditMode => 'Comută la modul Editare';

  @override
  String get previewMarkdown => 'Previzualizare markdown';

  @override
  String get preview => 'Previzualizare';

  @override
  String get autoSaveOn =>
      'Auto-salvare ACTIVATĂ (salvează la fiecare 5s după modificări)';

  @override
  String get enableAutoSave => 'Activează auto-salvarea';

  @override
  String get autoSaveOff => 'Auto-salvare DEZACTIVATĂ';

  @override
  String get saveNote => 'Salvează notița';

  @override
  String get noContentYet => '*Fără conținut încă*';

  @override
  String get startWriting => 'Începe să scrii prima ta notiță...';

  @override
  String get noteCannotBeEmpty => 'Notița nu poate fi goală';

  @override
  String get noteSaved => 'Notiță salvată!';

  @override
  String get editTitle => 'Editează Titlu';

  @override
  String get enterNoteTitle => 'Introdu titlul notiței';

  @override
  String get autoSaveEnabled => 'Auto-salvare activată';

  @override
  String get autoSaveDisabled => 'Auto-salvare dezactivată';

  @override
  String get markdownShortcuts => 'Comenzi Rapide Markdown';

  @override
  String get markdownShortcutsDesc =>
      'Personalizează butoanele și acțiunile din bara de instrumente';

  @override
  String get resetToDefault => 'Resetează la Implicit';

  @override
  String get removeAllCustom => 'Elimină Toate Personalizate';

  @override
  String get noCustomShortcutsYet => 'Nicio comandă rapidă personalizată încă';

  @override
  String get tapToAddShortcut => 'Apasă butonul + pentru a adăuga una';

  @override
  String get deleteShortcut => 'Șterge Comanda Rapidă';

  @override
  String get deleteShortcutConfirm =>
      'Ești sigur că vrei să ștergi această comandă rapidă?';

  @override
  String get resetDialogTitle => 'Resetează la Implicit';

  @override
  String get resetDialogMessage =>
      'Aceasta va restabili toate comenzile rapide implicite la ordinea și setările originale. Comenzile rapide personalizate vor fi păstrate dar mutate la sfârșit.';

  @override
  String get reset => 'Resetează';

  @override
  String get removeCustomDialogTitle => 'Elimină Toate Personalizate';

  @override
  String get removeCustomDialogMessage =>
      'Aceasta va șterge permanent toate comenzile rapide personalizate pe care le-ai creat. Comenzile rapide implicite vor rămâne.';

  @override
  String get remove => 'Elimină';

  @override
  String get defaultLabel => 'IMPLICIT';

  @override
  String get insertsCurrentDate => 'Inserează data curentă';

  @override
  String get opensHeaderMenu => 'Deschide meniul de anteturi (H1-H6)';

  @override
  String beforeAfterText(String before, String after) {
    return 'Înainte: \"$before\" | După: \"$after\"';
  }

  @override
  String get hide => 'Ascunde';

  @override
  String get show => 'Arată';

  @override
  String get newShortcut => 'Comandă Rapidă Nouă';

  @override
  String get editShortcut => 'Editează Comanda Rapidă';

  @override
  String get icon => 'Pictogramă';

  @override
  String get tapToChangeIcon => 'Apasă pentru a schimba pictograma';

  @override
  String get selectIcon => 'Selectează Pictograma';

  @override
  String get searchIcons => 'Caută pictograme...';

  @override
  String get noIconsFound => 'Nicio pictogramă găsită';

  @override
  String get label => 'Etichetă';

  @override
  String get labelHint => 'ex., Evidențiere';

  @override
  String get insertType => 'Tip Inserare';

  @override
  String get wrapSelectedText => 'Înconjoară Textul Selectat';

  @override
  String get insertCurrentDate => 'Inserează Data Curentă';

  @override
  String get beforeDate => 'Înainte de Dată (opțional)';

  @override
  String get markdownStart => 'Început Markdown';

  @override
  String get markdownStartHint => 'ex., ==';

  @override
  String get optionalTextBeforeDate => 'Text opțional înainte de dată';

  @override
  String get afterDate => 'După Dată (opțional)';

  @override
  String get markdownEnd => 'Sfârșit Markdown';

  @override
  String get optionalTextAfterDate => 'Text opțional după dată';

  @override
  String get labelCannotBeEmpty => 'Eticheta nu poate fi goală';

  @override
  String get bold => 'Îngroșat';

  @override
  String get italic => 'Italic';

  @override
  String get headers => 'Anteturi';

  @override
  String get pointList => 'Listă cu Puncte';

  @override
  String get strikethrough => 'Tăiat';

  @override
  String get bulletList => 'Listă cu Buline';

  @override
  String get numberedList => 'Listă Numerotată';

  @override
  String get checkbox => 'Casetă de Bifat';

  @override
  String get quote => 'Citat';

  @override
  String get inlineCode => 'Cod în Linie';

  @override
  String get codeBlock => 'Bloc de Cod';

  @override
  String get link => 'Link';

  @override
  String get currentDate => 'Data Curentă';

  @override
  String get header1 => 'Antet 1';

  @override
  String get header2 => 'Antet 2';

  @override
  String get header3 => 'Antet 3';

  @override
  String get header4 => 'Antet 4';

  @override
  String get header5 => 'Antet 5';

  @override
  String get header6 => 'Antet 6';

  @override
  String get undo => 'Anulează';

  @override
  String get redo => 'Refă';

  @override
  String get decreaseFontSize => 'Micșorează Fontul';

  @override
  String get increaseFontSize => 'Mărește Fontul';

  @override
  String get settings => 'Setări';

  @override
  String get dropPosition => 'Poziție de plasare';

  @override
  String get longPressToReorder => 'Apasă lung pentru a reordona';

  @override
  String shortcutButton(String label) {
    return 'Buton $label';
  }

  @override
  String get markdownSpaceWarning =>
      'Sfat: Adaugă un spațiu după sintaxa markdown (ex., \'# \' sau \'- \') pentru formatare corectă.';

  @override
  String get reorderShortcuts => 'Reordonează comenzile rapide';

  @override
  String get doneReordering => 'Gata';

  @override
  String get noSearchResults => 'Niciun rezultat găsit';

  @override
  String get searchHint => 'Tastează pentru a căuta notițe';

  @override
  String get loadingMore => 'Se încarcă mai multe...';

  @override
  String get noMoreNotes => 'Nu mai sunt notițe';

  @override
  String get sortBy => 'Sortează după';

  @override
  String get sortByUpdated => 'Ultima actualizare';

  @override
  String get sortByCreated => 'Data creării';

  @override
  String get sortByTitle => 'Titlu';

  @override
  String get ascending => 'Crescător';

  @override
  String get descending => 'Descrescător';

  @override
  String get loadingContent => 'Se încarcă conținutul...';

  @override
  String get largeNoteWarning =>
      'Această notiță este foarte mare și poate dura un moment să se încarce';

  @override
  String noteStats(int count, int chunks) {
    return '$count caractere distincte, $chunks fragmente';
  }

  @override
  String get compressedNote => 'Comprimat';

  @override
  String get searchInFolder => 'Caută în acest folder';

  @override
  String get searchAll => 'Caută în toate notițele';

  @override
  String get recentSearches => 'Căutări recente';

  @override
  String get clearSearchHistory => 'Șterge istoricul căutărilor';

  @override
  String get filterByDate => 'Filtrează după dată';

  @override
  String get fromDate => 'De la';

  @override
  String get toDate => 'Până la';

  @override
  String get applyFilter => 'Aplică filtru';

  @override
  String get clearFilter => 'Șterge filtru';

  @override
  String matchesFound(int count) {
    return '$count potriviri găsite';
  }

  @override
  String get autoSaving => 'Se salvează automat...';

  @override
  String get changesSaved => 'Modificări salvate';

  @override
  String get unsavedChanges => 'Modificări nesalvate';

  @override
  String get discardChanges => 'Renunță la modificări';

  @override
  String get keepEditing => 'Continuă editarea';

  @override
  String get virtualScrollEnabled =>
      'Derulare virtuală activată pentru conținut mare';

  @override
  String lineCount(int count) {
    return '$count linii';
  }

  @override
  String get emptyFoldersHint => 'Se pare că ai putea dori să creezi un folder';

  @override
  String get emptyNotesHint => 'Scrie prima ta notiță';

  @override
  String get tapPlusToCreate => 'Apasă + pentru a începe';

  @override
  String charactersCount(int current, int max) {
    return '$current/$max caractere';
  }

  @override
  String get databaseSettings => 'Bază de Date';

  @override
  String get databaseSettingsDesc =>
      'Gestionează locația și stocarea bazei de date';

  @override
  String get about => 'Despre';

  @override
  String get databaseLocation => 'Locația Bazei de Date';

  @override
  String get copyPath => 'Copiază Calea';

  @override
  String get openInFinder => 'Deschide Folderul';

  @override
  String get databaseStats => 'Statistici';

  @override
  String get size => 'Dimensiune';

  @override
  String get lastModified => 'Ultima Modificare';

  @override
  String get maintenance => 'Întreținere';

  @override
  String get maintenanceDesc =>
      'Rulează SQLite VACUUM pentru a recupera spațiul nefolosit din notițele și folderele șterse. Aceasta reconstruiește fișierul bazei de date, defragmentează datele și poate reduce semnificativ dimensiunea fișierului după ștergerea unor cantități mari de conținut.';

  @override
  String get optimizeDatabase => 'Optimizează Baza de Date';

  @override
  String get dangerZone => 'Zonă Periculoasă';

  @override
  String get dangerZoneDesc =>
      'Aceste acțiuni sunt ireversibile. Toate notițele și folderele tale vor fi șterse permanent.';

  @override
  String get deleteAllData => 'Șterge Toate Datele';

  @override
  String get pathCopied => 'Calea a fost copiată în clipboard';

  @override
  String get notSupportedOnPlatform => 'Nu este suportat pe această platformă';

  @override
  String get errorOpeningFolder => 'Eroare la deschiderea folderului';

  @override
  String get optimizing => 'Se optimizează baza de date...';

  @override
  String get optimizationComplete => 'Baza de date a fost optimizată cu succes';

  @override
  String get saved => 'salvat';

  @override
  String get alreadyOptimized => 'Baza de date este deja optimizată';

  @override
  String get deleteConfirmation =>
      'Această acțiune nu poate fi anulată. Toate notițele, folderele și datele tale vor fi șterse permanent. Ești absolut sigur?';

  @override
  String get deleteNotImplemented =>
      'Funcția de ștergere nu este implementată încă din motive de siguranță';

  @override
  String get deletingData => 'Se șterg toate datele...';

  @override
  String get dataDeleted => 'Date Șterse';

  @override
  String get restartRequired =>
      'Repornirea poate fi necesară pentru efect complet';

  @override
  String get exitApp => 'Închide Aplicația';

  @override
  String get errorDeletingData => 'Error deleting data';

  @override
  String get shareDatabase => 'Partajează Baza de Date';

  @override
  String get shareDatabaseDesc =>
      'Exportă și partajează fișierul bazei de date prin email, aplicații de mesagerie sau stocare cloud pentru backup.';

  @override
  String get preparingShare => 'Se pregătește partajarea...';

  @override
  String get shareError => 'Eroare la partajarea bazei de date';

  @override
  String get databaseNotFound => 'Fișierul bazei de date nu a fost găsit';

  @override
  String get renameNote => 'Redenumește Notița';

  @override
  String get enterNewName => 'Introdu noul nume';

  @override
  String get reorderMode => 'Mod Reordonare';

  @override
  String get dragToReorder => 'Trage elementele pentru a le reordona';

  @override
  String get sortByCustom => 'Ordine Personalizată';

  @override
  String get quickSort => 'Sortare Rapidă';

  @override
  String get sortItems => 'Sortează Elementele';

  @override
  String get sortFolders => 'Sortează Folderele';

  @override
  String get sortNotes => 'Sortează Notițele';

  @override
  String get sortByName => 'După Nume';

  @override
  String get moveUp => 'Mută Sus';

  @override
  String get moveDown => 'Mută Jos';

  @override
  String get controlsSettings => 'Controale';

  @override
  String get controlsSettingsDesc => 'Gesturi, feedback haptic și interacțiuni';

  @override
  String get gesturesSection => 'Gesturi';

  @override
  String get folderSwipeGesture =>
      'Glisare pentru a deschide meniul în foldere';

  @override
  String get folderSwipeGestureDesc =>
      'Glisează de la marginea stângă pentru a deschide meniul de navigare când navighezi în foldere';

  @override
  String get noteSwipeGesture => 'Glisare pentru a deschide meniul în notițe';

  @override
  String get noteSwipeGestureDesc =>
      'Glisează de la marginea stângă pentru a deschide meniul de navigare când editezi notițe';

  @override
  String get feedbackSection => 'Feedback';

  @override
  String get hapticFeedback => 'Feedback haptic';

  @override
  String get hapticFeedbackDesc =>
      'Vibrează la interacțiuni precum comutarea comutatoarelor';

  @override
  String get confirmDelete => 'Confirmă înainte de ștergere';

  @override
  String get confirmDeleteDesc =>
      'Afișează dialogul de confirmare înainte de ștergerea notițelor sau folderelor';

  @override
  String get autoSaveSection => 'Auto-salvare';

  @override
  String get autoSave => 'Auto-salvare notițe';

  @override
  String get autoSaveDesc => 'Salvează automat notițele în timpul editării';

  @override
  String get autoSaveInterval => 'Interval auto-salvare';

  @override
  String autoSaveIntervalDesc(int seconds) {
    return 'Salvează la fiecare $seconds secunde';
  }

  @override
  String get displaySection => 'Afișare';

  @override
  String get showNotePreview => 'Arată previzualizarea notiței';

  @override
  String get showNotePreviewDesc =>
      'Afișează o previzualizare a conținutului notiței în listă';

  @override
  String get showStatsBar => 'Arată bara de statistici';

  @override
  String get showStatsBarDesc =>
      'Afișează numărul de caractere și linii în editor';

  @override
  String get resetToDefaults => 'Resetează la valorile implicite';

  @override
  String get resetToDefaultsConfirm =>
      'Ești sigur că vrei să resetezi toate setările la valorile implicite?';

  @override
  String get settingsReset => 'Setările au fost resetate la valorile implicite';

  @override
  String get shareNote => 'Partajează Notița';

  @override
  String get noteOptions => 'Opțiuni Notiță';

  @override
  String get exportingNote => 'Se exportă notița...';

  @override
  String get noteExportError => 'Eroare la exportul notiței';

  @override
  String get chooseExportFormat => 'Alege Formatul de Export';

  @override
  String get exportAsMarkdown => 'Markdown (.md)';

  @override
  String get exportAsJson => 'JSON (.json)';

  @override
  String get exportAsText => 'Text Simplu (.txt)';

  @override
  String get activeDatabaseSection => 'Baza de Date Activă';

  @override
  String get activeDatabaseDesc =>
      'Selectează ce bază de date să folosești. Crearea sau schimbarea bazelor de date va reporni aplicația.';

  @override
  String get selectDatabase => 'Selectează Baza de Date';

  @override
  String currentDatabase(String name) {
    return 'Curentă: $name';
  }

  @override
  String get createNewDatabase => 'Crează Bază de Date Nouă';

  @override
  String get newDatabaseName => 'Nume Bază de Date';

  @override
  String get enterDatabaseName => 'Introdu numele bazei de date';

  @override
  String get invalidDatabaseName =>
      'Nume invalid. Folosește doar litere, cifre, underscores și cratime (maxim 50 caractere).';

  @override
  String get databaseExists => 'O bază de date cu acest nume există deja.';

  @override
  String get creatingDatabase => 'Se crează baza de date...';

  @override
  String get databaseCreated => 'Baza de date a fost creată cu succes';

  @override
  String get renameDatabase => 'Redenumește Baza de Date';

  @override
  String get renamingDatabase => 'Se redenumește baza de date...';

  @override
  String get databaseRenamed => 'Baza de date a fost redenumită cu succes';

  @override
  String get switchingDatabase => 'Se schimbă baza de date...';

  @override
  String get availableDatabases => 'Baze de Date Disponibile';

  @override
  String get noDatabases => 'Nicio bază de date găsită';

  @override
  String get databaseOptions => 'Opțiuni Bază de Date';

  @override
  String get switchTo => 'Comută la această bază de date';

  @override
  String deleteDatabaseConfirm(String name) {
    return 'Ești sigur că vrei să ștergi baza de date \"$name\"? Această acțiune nu poate fi anulată.';
  }

  @override
  String get cannotDeleteActive =>
      'Nu poți șterge baza de date activă curent. Te rugăm să comuți la altă bază de date mai întâi.';

  @override
  String get databaseDeleted => 'Baza de date a fost ștearsă';

  @override
  String get findInNote => 'Găsește în notiță';

  @override
  String get replaceWith => 'Înlocuiește cu';

  @override
  String get replaceOne => 'Înlocuiește';

  @override
  String get replaceAll => 'Toate';

  @override
  String replacedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count potriviri înlocuite',
      one: '1 potrivire înlocuită',
    );
    return '$_temp0';
  }

  @override
  String get matchCase => 'Potrivire majuscule';

  @override
  String get wholeWord => 'Cuvânt întreg';

  @override
  String get useRegex => 'Folosește regex';

  @override
  String get findAndReplace => 'Găsește și Înlocuiește';

  @override
  String get options => 'Opțiuni';

  @override
  String get previous => 'Anterior';

  @override
  String get next => 'Următor';

  @override
  String get close => 'Închide';

  @override
  String get dateFormatSettings => 'Format Dată';

  @override
  String get selectDateFormat => 'Alege cum vor fi afișate datele:';

  @override
  String get longPressToChangeFormat => 'Apasă lung pentru a schimba formatul';

  @override
  String get languageSettings => 'Limbă';

  @override
  String get languageSettingsDesc => 'Schimbă limba de afișare a aplicației';

  @override
  String get selectLanguage => 'Selectează Limba';

  @override
  String get english => 'Engleză';

  @override
  String get german => 'Germană';

  @override
  String get romanian => 'Română';

  @override
  String get systemDefault => 'Implicit Sistem';

  @override
  String get themeSettings => 'Aspect';

  @override
  String get themeSettingsDesc => 'Mod întunecat, culori și afișare';

  @override
  String get selectTheme => 'Selectează Tema';

  @override
  String get lightTheme => 'Luminos';

  @override
  String get darkTheme => 'Întunecat';

  @override
  String get systemTheme => 'Sistem';

  @override
  String get searchSection => 'Căutare';

  @override
  String get searchCursorBehavior => 'Navigare căutare';

  @override
  String get searchCursorBehaviorDesc =>
      'Unde să poziționeze cursorul când navighezi la o potrivire';

  @override
  String get cursorAtStart => 'Înainte';

  @override
  String get cursorAtEnd => 'După';

  @override
  String get selectMatch => 'Selectează';

  @override
  String get searching => 'Se caută...';
}
