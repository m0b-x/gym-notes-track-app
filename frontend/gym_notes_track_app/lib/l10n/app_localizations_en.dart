// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Gym Notes';

  @override
  String get folders => 'Folders';

  @override
  String get notes => 'Notes';

  @override
  String get createFolder => 'Create Folder';

  @override
  String get createNote => 'Create Note';

  @override
  String get folderName => 'Folder Name';

  @override
  String get noteName => 'Note Name';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get search => 'Search';

  @override
  String error(String message) {
    return 'Error: $message';
  }

  @override
  String created(String date) {
    return 'Created: $date';
  }

  @override
  String updated(String date) {
    return 'Updated: $date';
  }

  @override
  String get deleteFolder => 'Delete Folder';

  @override
  String deleteFolderConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get rename => 'Rename';

  @override
  String get renameFolder => 'Rename Folder';

  @override
  String get untitledNote => 'Untitled Note';

  @override
  String get emptyNote => 'Empty note';

  @override
  String get deleteNote => 'Delete Note';

  @override
  String deleteNoteConfirm(String title) {
    return 'Are you sure you want to delete \"$title\"?';
  }

  @override
  String get deleteThisNote => 'this note';

  @override
  String get enterFolderName => 'Enter folder name';

  @override
  String get newNote => 'New Note';

  @override
  String get switchToEditMode => 'Switch to Edit mode';

  @override
  String get previewMarkdown => 'Preview markdown';

  @override
  String get preview => 'Preview';

  @override
  String get autoSaveOn => 'Auto-save is ON (saves every 5s after changes)';

  @override
  String get enableAutoSave => 'Enable auto-save';

  @override
  String get autoSaveOff => 'Auto-save OFF';

  @override
  String get saveNote => 'Save note';

  @override
  String get noContentYet => '*No content yet*';

  @override
  String get startWriting => 'Start writing your first note...';

  @override
  String get noteCannotBeEmpty => 'Note cannot be empty';

  @override
  String get noteSaved => 'Note saved!';

  @override
  String get editTitle => 'Edit Title';

  @override
  String get enterNoteTitle => 'Enter note title';

  @override
  String get autoSaveEnabled => 'Auto-save enabled';

  @override
  String get autoSaveDisabled => 'Auto-save disabled';

  @override
  String get markdownShortcuts => 'Markdown Shortcuts';

  @override
  String get resetToDefault => 'Reset to Default';

  @override
  String get removeAllCustom => 'Remove All Custom';

  @override
  String get noCustomShortcutsYet => 'No custom shortcuts yet';

  @override
  String get tapToAddShortcut => 'Tap the + button to add one';

  @override
  String get deleteShortcut => 'Delete Shortcut';

  @override
  String get deleteShortcutConfirm =>
      'Are you sure you want to delete this shortcut?';

  @override
  String get resetDialogTitle => 'Reset to Default';

  @override
  String get resetDialogMessage =>
      'This will restore all default shortcuts to their original order and settings. Custom shortcuts will be kept but moved to the end.';

  @override
  String get reset => 'Reset';

  @override
  String get removeCustomDialogTitle => 'Remove All Custom';

  @override
  String get removeCustomDialogMessage =>
      'This will permanently delete all custom shortcuts you created. Default shortcuts will remain.';

  @override
  String get remove => 'Remove';

  @override
  String get defaultLabel => 'DEFAULT';

  @override
  String get insertsCurrentDate => 'Inserts current date';

  @override
  String get opensHeaderMenu => 'Opens header menu (H1-H6)';

  @override
  String beforeAfterText(String before, String after) {
    return 'Before: \"$before\" | After: \"$after\"';
  }

  @override
  String get hide => 'Hide';

  @override
  String get show => 'Show';

  @override
  String get newShortcut => 'New Shortcut';

  @override
  String get editShortcut => 'Edit Shortcut';

  @override
  String get icon => 'Icon';

  @override
  String get tapToChangeIcon => 'Tap to change icon';

  @override
  String get selectIcon => 'Select Icon';

  @override
  String get label => 'Label';

  @override
  String get labelHint => 'e.g., Highlight';

  @override
  String get insertType => 'Insert Type';

  @override
  String get wrapSelectedText => 'Wrap Selected Text';

  @override
  String get insertCurrentDate => 'Insert Current Date';

  @override
  String get beforeDate => 'Before Date (optional)';

  @override
  String get markdownStart => 'Markdown Start';

  @override
  String get markdownStartHint => 'e.g., ==';

  @override
  String get optionalTextBeforeDate => 'Optional text before date';

  @override
  String get afterDate => 'After Date (optional)';

  @override
  String get markdownEnd => 'Markdown End';

  @override
  String get optionalTextAfterDate => 'Optional text after date';

  @override
  String get labelCannotBeEmpty => 'Label cannot be empty';

  @override
  String get bold => 'Bold';

  @override
  String get italic => 'Italic';

  @override
  String get headers => 'Headers';

  @override
  String get pointList => 'Point List';

  @override
  String get strikethrough => 'Strikethrough';

  @override
  String get bulletList => 'Bullet List';

  @override
  String get numberedList => 'Numbered List';

  @override
  String get checkbox => 'Checkbox';

  @override
  String get quote => 'Quote';

  @override
  String get inlineCode => 'Inline Code';

  @override
  String get codeBlock => 'Code Block';

  @override
  String get link => 'Link';

  @override
  String get currentDate => 'Current Date';

  @override
  String get header1 => 'Header 1';

  @override
  String get header2 => 'Header 2';

  @override
  String get header3 => 'Header 3';

  @override
  String get header4 => 'Header 4';

  @override
  String get header5 => 'Header 5';

  @override
  String get header6 => 'Header 6';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get decreaseFontSize => 'Decrease Font Size';

  @override
  String get increaseFontSize => 'Increase Font Size';

  @override
  String get settings => 'Settings';

  @override
  String get dropPosition => 'Drop position';

  @override
  String get longPressToReorder => 'Long press to reorder';

  @override
  String shortcutButton(String label) {
    return '$label button';
  }

  @override
  String get markdownSpaceWarning =>
      'Tip: Add a space after markdown syntax (e.g., \'# \' or \'- \') for proper formatting.';

  @override
  String get reorderShortcuts => 'Reorder shortcuts';

  @override
  String get doneReordering => 'Done';

  @override
  String get noSearchResults => 'No results found';

  @override
  String get searchHint => 'Type to search notes';

  @override
  String get loadingMore => 'Loading more...';

  @override
  String get noMoreNotes => 'No more notes';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortByUpdated => 'Last updated';

  @override
  String get sortByCreated => 'Date created';

  @override
  String get sortByTitle => 'Title';

  @override
  String get ascending => 'Ascending';

  @override
  String get descending => 'Descending';

  @override
  String get loadingContent => 'Loading content...';

  @override
  String get largeNoteWarning =>
      'This note is very large and may take a moment to load';

  @override
  String noteStats(int count, int chunks) {
    return '$count distinct characters, $chunks chunks';
  }

  @override
  String get compressedNote => 'Compressed';

  @override
  String get searchInFolder => 'Search in this folder';

  @override
  String get searchAll => 'Search all notes';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String get clearSearchHistory => 'Clear search history';

  @override
  String get filterByDate => 'Filter by date';

  @override
  String get fromDate => 'From';

  @override
  String get toDate => 'To';

  @override
  String get applyFilter => 'Apply filter';

  @override
  String get clearFilter => 'Clear filter';

  @override
  String matchesFound(int count) {
    return '$count matches found';
  }

  @override
  String get autoSaving => 'Auto-saving...';

  @override
  String get changesSaved => 'Changes saved';

  @override
  String get unsavedChanges => 'Unsaved changes';

  @override
  String get discardChanges => 'Discard changes';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get virtualScrollEnabled => 'Virtual scroll enabled for large content';

  @override
  String lineCount(int count) {
    return '$count lines';
  }

  @override
  String get emptyFoldersHint => 'Looks like you might want to create a folder';

  @override
  String get emptyNotesHint => 'Write your first note';

  @override
  String get tapPlusToCreate => 'Tap + to get started';

  @override
  String charactersCount(int current, int max) {
    return '$current/$max characters';
  }

  @override
  String get databaseSettings => 'Database';

  @override
  String get databaseSettingsDesc => 'Manage database location and storage';

  @override
  String get about => 'About';

  @override
  String get databaseLocation => 'Database Location';

  @override
  String get copyPath => 'Copy Path';

  @override
  String get openInFinder => 'Open Folder';

  @override
  String get databaseStats => 'Statistics';

  @override
  String get size => 'Size';

  @override
  String get lastModified => 'Last Modified';

  @override
  String get maintenance => 'Maintenance';

  @override
  String get maintenanceDesc =>
      'Run SQLite VACUUM to reclaim unused space from deleted notes and folders. This rebuilds the database file, defragments the data, and can significantly reduce file size after deleting large amounts of content. The operation may take a few seconds depending on database size.';

  @override
  String get optimizeDatabase => 'Optimize Database';

  @override
  String get dangerZone => 'Danger Zone';

  @override
  String get dangerZoneDesc =>
      'These actions are irreversible. All your notes and folders will be permanently deleted.';

  @override
  String get deleteAllData => 'Delete All Data';

  @override
  String get pathCopied => 'Path copied to clipboard';

  @override
  String get notSupportedOnPlatform => 'Not supported on this platform';

  @override
  String get errorOpeningFolder => 'Error opening folder';

  @override
  String get optimizing => 'Optimizing database...';

  @override
  String get optimizationComplete => 'Database optimized successfully';

  @override
  String get saved => 'saved';

  @override
  String get alreadyOptimized => 'database already optimized';

  @override
  String get deleteConfirmation =>
      'This action cannot be undone. All your notes, folders, and data will be permanently deleted. Are you absolutely sure?';

  @override
  String get deleteNotImplemented =>
      'Delete functionality not yet implemented for safety';

  @override
  String get deletingData => 'Deleting all data...';

  @override
  String get dataDeleted => 'Data Deleted';

  @override
  String get restartRequired =>
      'All data has been deleted. Please restart the app to continue.';

  @override
  String get exitApp => 'Exit App';

  @override
  String get errorDeletingData => 'Error deleting data';

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
  String get moveUp => 'Move Up';

  @override
  String get moveDown => 'Move Down';
}
