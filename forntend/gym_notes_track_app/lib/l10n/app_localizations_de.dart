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
}
