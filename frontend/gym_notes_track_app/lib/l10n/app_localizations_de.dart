// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Gym Notizen';

  @override
  String get folders => 'Ordner';

  @override
  String get notes => 'Notizen';

  @override
  String get createFolder => 'Ordner erstellen';

  @override
  String get createNote => 'Notiz erstellen';

  @override
  String get folderName => 'Ordnername';

  @override
  String get noteName => 'Notizname';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get create => 'Erstellen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get delete => 'Löschen';

  @override
  String get save => 'Speichern';

  @override
  String get search => 'Suchen';

  @override
  String error(String message) {
    return 'Fehler: $message';
  }

  @override
  String created(String date) {
    return 'Erstellt: $date';
  }

  @override
  String updated(String date) {
    return 'Aktualisiert: $date';
  }

  @override
  String get deleteFolder => 'Ordner löschen';

  @override
  String deleteFolderConfirm(String name) {
    return 'Möchten Sie \"$name\" wirklich löschen?';
  }

  @override
  String deleteFolderWithNotesConfirm(String name, int count) {
    return 'Möchten Sie \"$name\" wirklich löschen? Dies löscht auch $count Notiz(en).';
  }

  @override
  String get rename => 'Umbenennen';

  @override
  String get renameFolder => 'Ordner umbenennen';

  @override
  String get untitledNote => 'Unbenannte Notiz';

  @override
  String get emptyNote => 'Leere Notiz';

  @override
  String get deleteNote => 'Notiz löschen';

  @override
  String deleteNoteConfirm(String title) {
    return 'Möchten Sie \"$title\" wirklich löschen?';
  }

  @override
  String get deleteThisNote => 'diese Notiz';

  @override
  String get enterFolderName => 'Ordnernamen eingeben';

  @override
  String get newNote => 'Neue Notiz';

  @override
  String get switchToEditMode => 'Zum Bearbeitungsmodus wechseln';

  @override
  String get previewMarkdown => 'Markdown-Vorschau';

  @override
  String get preview => 'Vorschau';

  @override
  String get autoSaveOn =>
      'Auto-Speichern ist EIN (speichert alle 5s nach Änderungen)';

  @override
  String get enableAutoSave => 'Auto-Speichern aktivieren';

  @override
  String get autoSaveOff => 'Auto-Speichern AUS';

  @override
  String get saveNote => 'Notiz speichern';

  @override
  String get noContentYet => '*Noch kein Inhalt*';

  @override
  String get startWriting => 'Beginnen Sie zu schreiben...';

  @override
  String get noteCannotBeEmpty => 'Notiz darf nicht leer sein';

  @override
  String get noteSaved => 'Notiz gespeichert!';

  @override
  String get editTitle => 'Titel bearbeiten';

  @override
  String get enterNoteTitle => 'Notiztitel eingeben';

  @override
  String get autoSaveEnabled => 'Auto-Speichern aktiviert';

  @override
  String get autoSaveDisabled => 'Auto-Speichern deaktiviert';

  @override
  String get markdownShortcuts => 'Markdown-Verknüpfungen';

  @override
  String get markdownShortcutsDesc =>
      'Symbolleisten-Schaltflächen und Aktionen anpassen';

  @override
  String get resetToDefault => 'Auf Standard zurücksetzen';

  @override
  String get removeAllCustom => 'Alle benutzerdefinierten entfernen';

  @override
  String get noCustomShortcutsYet =>
      'Noch keine benutzerdefinierten Verknüpfungen';

  @override
  String get tapToAddShortcut =>
      'Tippen Sie auf die Schaltfläche +, um eine hinzuzufügen';

  @override
  String get deleteShortcut => 'Verknüpfung löschen';

  @override
  String get deleteShortcutConfirm =>
      'Möchten Sie diese Verknüpfung wirklich löschen?';

  @override
  String get resetDialogTitle => 'Auf Standard zurücksetzen';

  @override
  String get resetDialogMessage =>
      'Dies stellt alle Standardverknüpfungen in ihrer ursprünglichen Reihenfolge und Einstellungen wieder her. Benutzerdefinierte Verknüpfungen werden behalten, aber ans Ende verschoben.';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get removeCustomDialogTitle => 'Alle benutzerdefinierten entfernen';

  @override
  String get removeCustomDialogMessage =>
      'Dies löscht dauerhaft alle von Ihnen erstellten benutzerdefinierten Verknüpfungen. Standardverknüpfungen bleiben erhalten.';

  @override
  String get remove => 'Entfernen';

  @override
  String get defaultLabel => 'STANDARD';

  @override
  String get insertsCurrentDate => 'Fügt aktuelles Datum ein';

  @override
  String get opensHeaderMenu => 'Öffnet Überschriftenmenü (H1-H6)';

  @override
  String beforeAfterText(String before, String after) {
    return 'Vorher: \"$before\" | Nachher: \"$after\"';
  }

  @override
  String get hide => 'Verbergen';

  @override
  String get show => 'Anzeigen';

  @override
  String get newShortcut => 'Neue Verknüpfung';

  @override
  String get editShortcut => 'Verknüpfung bearbeiten';

  @override
  String get icon => 'Symbol';

  @override
  String get tapToChangeIcon => 'Tippen Sie, um das Symbol zu ändern';

  @override
  String get selectIcon => 'Symbol auswählen';

  @override
  String get searchIcons => 'Symbole suchen...';

  @override
  String get noIconsFound => 'Keine Symbole gefunden';

  @override
  String get label => 'Beschriftung';

  @override
  String get labelHint => 'z.B. Hervorheben';

  @override
  String get insertType => 'Einfügungstyp';

  @override
  String get wrapSelectedText => 'Ausgewählten Text umschließen';

  @override
  String get insertCurrentDate => 'Aktuelles Datum einfügen';

  @override
  String get beforeDate => 'Vor Datum (optional)';

  @override
  String get markdownStart => 'Markdown-Start';

  @override
  String get markdownStartHint => 'z.B. ==';

  @override
  String get optionalTextBeforeDate => 'Optionaler Text vor Datum';

  @override
  String get afterDate => 'Nach Datum (optional)';

  @override
  String get markdownEnd => 'Markdown-Ende';

  @override
  String get optionalTextAfterDate => 'Optionaler Text nach Datum';

  @override
  String get labelCannotBeEmpty => 'Beschriftung darf nicht leer sein';

  @override
  String get bold => 'Fett';

  @override
  String get italic => 'Kursiv';

  @override
  String get headers => 'Überschriften';

  @override
  String get pointList => 'Punktliste';

  @override
  String get strikethrough => 'Durchgestrichen';

  @override
  String get bulletList => 'Aufzählungsliste';

  @override
  String get numberedList => 'Nummerierte Liste';

  @override
  String get checkbox => 'Kontrollkästchen';

  @override
  String get quote => 'Zitat';

  @override
  String get inlineCode => 'Inline-Code';

  @override
  String get codeBlock => 'Codeblock';

  @override
  String get link => 'Link';

  @override
  String get currentDate => 'Aktuelles Datum';

  @override
  String get header1 => 'Überschrift 1';

  @override
  String get header2 => 'Überschrift 2';

  @override
  String get header3 => 'Überschrift 3';

  @override
  String get header4 => 'Überschrift 4';

  @override
  String get header5 => 'Überschrift 5';

  @override
  String get header6 => 'Überschrift 6';

  @override
  String get undo => 'Rückgängig';

  @override
  String get redo => 'Wiederholen';

  @override
  String get decreaseFontSize => 'Schriftgröße verkleinern';

  @override
  String get increaseFontSize => 'Schriftgröße vergrößern';

  @override
  String get settings => 'Einstellungen';

  @override
  String get dropPosition => 'Ablageposition';

  @override
  String get longPressToReorder => 'Lange drücken zum Neuordnen';

  @override
  String shortcutButton(String label) {
    return '$label Schaltfläche';
  }

  @override
  String get markdownSpaceWarning =>
      'Tipp: Fügen Sie ein Leerzeichen nach der Markdown-Syntax hinzu (z.B. \'# \' oder \'- \') für die richtige Formatierung.';

  @override
  String get reorderShortcuts => 'Verknüpfungen neu anordnen';

  @override
  String get doneReordering => 'Fertig';

  @override
  String get noSearchResults => 'Keine Ergebnisse gefunden';

  @override
  String get searchHint => 'Tippen um Notizen zu suchen';

  @override
  String get loadingMore => 'Lade mehr...';

  @override
  String get noMoreNotes => 'Keine weiteren Notizen';

  @override
  String get sortBy => 'Sortieren nach';

  @override
  String get sortByUpdated => 'Zuletzt aktualisiert';

  @override
  String get sortByCreated => 'Erstellungsdatum';

  @override
  String get sortByTitle => 'Titel';

  @override
  String get ascending => 'Aufsteigend';

  @override
  String get descending => 'Absteigend';

  @override
  String get loadingContent => 'Lade Inhalt...';

  @override
  String get largeNoteWarning =>
      'Diese Notiz ist sehr groß und kann einen Moment zum Laden benötigen';

  @override
  String noteStats(int count, int chunks) {
    return '$count Zeichen, $chunks Teile';
  }

  @override
  String get compressedNote => 'Komprimiert';

  @override
  String get searchInFolder => 'In diesem Ordner suchen';

  @override
  String get searchAll => 'Alle Notizen durchsuchen';

  @override
  String get recentSearches => 'Letzte Suchen';

  @override
  String get clearSearchHistory => 'Suchverlauf löschen';

  @override
  String get filterByDate => 'Nach Datum filtern';

  @override
  String get fromDate => 'Von';

  @override
  String get toDate => 'Bis';

  @override
  String get applyFilter => 'Filter anwenden';

  @override
  String get clearFilter => 'Filter löschen';

  @override
  String matchesFound(int count) {
    return '$count Treffer gefunden';
  }

  @override
  String get autoSaving => 'Automatisches Speichern...';

  @override
  String get changesSaved => 'Änderungen gespeichert';

  @override
  String get unsavedChanges => 'Ungespeicherte Änderungen';

  @override
  String get discardChanges => 'Änderungen verwerfen';

  @override
  String get keepEditing => 'Weiter bearbeiten';

  @override
  String get virtualScrollEnabled =>
      'Virtuelles Scrollen für große Inhalte aktiviert';

  @override
  String lineCount(int count) {
    return '$count Zeilen';
  }

  @override
  String get emptyFoldersHint =>
      'Sieht so aus, als möchtest du einen Ordner erstellen';

  @override
  String get emptyNotesHint => 'Schreibe deine erste Notiz';

  @override
  String get tapPlusToCreate => 'Tippe auf + um zu beginnen';

  @override
  String charactersCount(int current, int max) {
    return '$current/$max Zeichen';
  }

  @override
  String get databaseSettings => 'Datenbank';

  @override
  String get databaseSettingsDesc => 'Datenbankspeicherort und -verwaltung';

  @override
  String get about => 'About';

  @override
  String get databaseLocation => 'Datenbankspeicherort';

  @override
  String get copyPath => 'Pfad kopieren';

  @override
  String get openInFinder => 'Ordner öffnen';

  @override
  String get databaseStats => 'Statistiken';

  @override
  String get size => 'Größe';

  @override
  String get lastModified => 'Zuletzt geändert';

  @override
  String get maintenance => 'Wartung';

  @override
  String get maintenanceDesc =>
      'SQLite VACUUM ausführen, um ungenutzten Speicherplatz von gelöschten Notizen und Ordnern zurückzugewinnen. Dies erstellt die Datenbankdatei neu, defragmentiert die Daten und kann die Dateigröße nach dem Löschen großer Inhaltsmengen erheblich reduzieren.';

  @override
  String get optimizeDatabase => 'Datenbank optimieren';

  @override
  String get dangerZone => 'Gefahrenzone';

  @override
  String get dangerZoneDesc =>
      'Diese Aktionen sind unwiderruflich. Alle Notizen und Ordner werden dauerhaft gelöscht.';

  @override
  String get deleteAllData => 'Alle Daten löschen';

  @override
  String get pathCopied => 'Pfad in Zwischenablage kopiert';

  @override
  String get notSupportedOnPlatform => 'Auf dieser Plattform nicht unterstützt';

  @override
  String get errorOpeningFolder => 'Fehler beim Öffnen des Ordners';

  @override
  String get optimizing => 'Datenbank wird optimiert...';

  @override
  String get optimizationComplete => 'Datenbank erfolgreich optimiert';

  @override
  String get saved => 'gespart';

  @override
  String get alreadyOptimized => 'Datenbank bereits optimiert';

  @override
  String get deleteConfirmation =>
      'Diese Aktion kann nicht rückgängig gemacht werden. Alle Notizen, Ordner und Daten werden dauerhaft gelöscht. Sind Sie absolut sicher?';

  @override
  String get deleteNotImplemented =>
      'Delete functionality not yet implemented for safety';

  @override
  String get deletingData => 'Alle Daten werden gelöscht...';

  @override
  String get dataDeleted => 'Daten gelöscht';

  @override
  String get restartRequired =>
      'Neustart kann für volle Wirkung erforderlich sein';

  @override
  String get exitApp => 'App beenden';

  @override
  String get errorDeletingData => 'Fehler beim Löschen der Daten';

  @override
  String get shareDatabase => 'Datenbank teilen';

  @override
  String get shareDatabaseDesc =>
      'Exportieren und teilen Sie Ihre Datenbankdatei per E-Mail, Messenger-Apps oder Cloud-Speicher für Backup-Zwecke.';

  @override
  String get preparingShare => 'Teilen wird vorbereitet...';

  @override
  String get shareError => 'Fehler beim Teilen der Datenbank';

  @override
  String get databaseNotFound => 'Datenbankdatei nicht gefunden';

  @override
  String get renameNote => 'Rename Note';

  @override
  String get enterNewName => 'Enter new name';

  @override
  String get reorderMode => 'Reorder Mode';

  @override
  String get dragToReorder => 'Drag items to reorder';

  @override
  String get sortByCustom => 'Custom Order';

  @override
  String get quickSort => 'Schnellsortierung';

  @override
  String get sortItems => 'Elemente sortieren';

  @override
  String get sortFolders => 'Ordner sortieren';

  @override
  String get sortNotes => 'Notizen sortieren';

  @override
  String get sortByName => 'Nach Name';

  @override
  String get moveUp => 'Move Up';

  @override
  String get moveDown => 'Move Down';

  @override
  String get controlsSettings => 'Steuerung';

  @override
  String get controlsSettingsDesc => 'Gesten, Haptik und Interaktionen';

  @override
  String get gesturesSection => 'Gesten';

  @override
  String get folderSwipeGesture => 'Wischen zum Öffnen des Menüs in Ordnern';

  @override
  String get folderSwipeGestureDesc =>
      'Vom linken Rand wischen, um das Navigationsmenü beim Durchsuchen von Ordnern zu öffnen';

  @override
  String get noteSwipeGesture => 'Wischen zum Öffnen des Menüs in Notizen';

  @override
  String get noteSwipeGestureDesc =>
      'Vom linken Rand wischen, um das Navigationsmenü beim Bearbeiten von Notizen zu öffnen';

  @override
  String get feedbackSection => 'Feedback';

  @override
  String get hapticFeedback => 'Haptisches Feedback';

  @override
  String get hapticFeedbackDesc =>
      'Vibration bei Interaktionen wie dem Umschalten von Schaltern';

  @override
  String get confirmDelete => 'Vor dem Löschen bestätigen';

  @override
  String get confirmDeleteDesc =>
      'Bestätigungsdialog vor dem Löschen von Notizen oder Ordnern anzeigen';

  @override
  String get autoSaveSection => 'Automatisches Speichern';

  @override
  String get autoSave => 'Notizen automatisch speichern';

  @override
  String get autoSaveDesc => 'Notizen beim Bearbeiten automatisch speichern';

  @override
  String get autoSaveInterval => 'Speicherintervall';

  @override
  String autoSaveIntervalDesc(int seconds) {
    return 'Alle $seconds Sekunden speichern';
  }

  @override
  String get displaySection => 'Anzeige';

  @override
  String get showNotePreview => 'Notizvorschau anzeigen';

  @override
  String get showNotePreviewDesc =>
      'Eine Vorschau des Notizinhalts in der Liste anzeigen';

  @override
  String get resetToDefaults => 'Auf Standard zurücksetzen';

  @override
  String get resetToDefaultsConfirm =>
      'Möchten Sie wirklich alle Einstellungen auf ihre Standardwerte zurücksetzen?';

  @override
  String get settingsReset => 'Einstellungen wurden auf Standard zurückgesetzt';

  @override
  String get shareNote => 'Notiz teilen';

  @override
  String get noteOptions => 'Notiz-Optionen';

  @override
  String get exportingNote => 'Notiz wird exportiert...';

  @override
  String get noteExportError => 'Fehler beim Exportieren der Notiz';

  @override
  String get chooseExportFormat => 'Exportformat wählen';

  @override
  String get exportAsMarkdown => 'Markdown (.md)';

  @override
  String get exportAsJson => 'JSON (.json)';

  @override
  String get exportAsText => 'Nur Text (.txt)';

  @override
  String get activeDatabaseSection => 'Aktive Datenbank';

  @override
  String get activeDatabaseDesc =>
      'Wählen Sie aus, welche Datenbank verwendet werden soll. Das Erstellen oder Wechseln der Datenbank startet die App neu.';

  @override
  String get selectDatabase => 'Datenbank auswählen';

  @override
  String currentDatabase(String name) {
    return 'Aktuell: $name';
  }

  @override
  String get createNewDatabase => 'Neue Datenbank erstellen';

  @override
  String get newDatabaseName => 'Datenbankname';

  @override
  String get enterDatabaseName => 'Datenbanknamen eingeben';

  @override
  String get invalidDatabaseName =>
      'Ungültiger Name. Verwenden Sie nur Buchstaben, Zahlen, Unterstriche und Bindestriche (max. 50 Zeichen).';

  @override
  String get databaseExists =>
      'Eine Datenbank mit diesem Namen existiert bereits.';

  @override
  String get creatingDatabase => 'Datenbank wird erstellt...';

  @override
  String get databaseCreated => 'Datenbank erfolgreich erstellt';

  @override
  String get renameDatabase => 'Datenbank umbenennen';

  @override
  String get renamingDatabase => 'Datenbank wird umbenannt...';

  @override
  String get databaseRenamed => 'Datenbank erfolgreich umbenannt';

  @override
  String get switchingDatabase => 'Datenbank wird gewechselt...';

  @override
  String get availableDatabases => 'Verfügbare Datenbanken';

  @override
  String get noDatabases => 'Keine Datenbanken gefunden';

  @override
  String get databaseOptions => 'Datenbankoptionen';

  @override
  String get switchTo => 'Zu dieser Datenbank wechseln';

  @override
  String deleteDatabaseConfirm(String name) {
    return 'Möchten Sie die Datenbank \"$name\" wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String get cannotDeleteActive =>
      'Die aktuell aktive Datenbank kann nicht gelöscht werden. Bitte wechseln Sie zuerst zu einer anderen Datenbank.';

  @override
  String get databaseDeleted => 'Datenbank gelöscht';

  @override
  String get findInNote => 'In Notiz suchen';

  @override
  String get replaceWith => 'Ersetzen durch';

  @override
  String get replaceOne => 'Ersetzen';

  @override
  String get replaceAll => 'Alle';

  @override
  String replacedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Treffer ersetzt',
      one: '1 Treffer ersetzt',
    );
    return '$_temp0';
  }

  @override
  String get matchCase => 'Groß-/Kleinschreibung';

  @override
  String get wholeWord => 'Ganzes Wort';

  @override
  String get useRegex => 'Regex verwenden';

  @override
  String get findAndReplace => 'Suchen & Ersetzen';

  @override
  String get options => 'Optionen';

  @override
  String get previous => 'Zurück';

  @override
  String get next => 'Weiter';

  @override
  String get close => 'Schließen';

  @override
  String get dateFormatSettings => 'Datumsformat';

  @override
  String get selectDateFormat => 'Wählen Sie, wie Daten angezeigt werden:';

  @override
  String get longPressToChangeFormat => 'Lange drücken zum Ändern des Formats';

  @override
  String get languageSettings => 'Sprache';

  @override
  String get languageSettingsDesc => 'App-Anzeigesprache ändern';

  @override
  String get selectLanguage => 'Sprache auswählen';

  @override
  String get english => 'Englisch';

  @override
  String get german => 'Deutsch';

  @override
  String get romanian => 'Rumänisch';

  @override
  String get systemDefault => 'Systemstandard';

  @override
  String get themeSettings => 'Erscheinungsbild';

  @override
  String get themeSettingsDesc => 'Dunkelmodus, Farben und Anzeige';

  @override
  String get selectTheme => 'Design auswählen';

  @override
  String get lightTheme => 'Hell';

  @override
  String get darkTheme => 'Dunkel';

  @override
  String get systemTheme => 'System';
}
