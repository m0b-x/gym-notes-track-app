import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ro.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('ro'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Gym Notes'**
  String get appTitle;

  /// Welcome message on onboarding screen
  ///
  /// In en, this message translates to:
  /// **'Welcome to Gym Notes'**
  String get welcomeToGymNotes;

  /// Description on onboarding screen
  ///
  /// In en, this message translates to:
  /// **'Track your workouts and notes in one place. Get started by creating a fresh workspace or restore from a previous backup.'**
  String get onboardingDescription;

  /// Button to start with empty workspace
  ///
  /// In en, this message translates to:
  /// **'Start Fresh'**
  String get startFresh;

  /// Button to restore from backup file
  ///
  /// In en, this message translates to:
  /// **'Restore from Backup'**
  String get restoreFromBackup;

  /// Title for import confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Confirm Import'**
  String get confirmImport;

  /// Label before listing backup contents
  ///
  /// In en, this message translates to:
  /// **'This backup contains:'**
  String get backupContains;

  /// Shows when backup was exported
  ///
  /// In en, this message translates to:
  /// **'Exported on: {date}'**
  String exportedOn(String date);

  /// Button to import data
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// Success message after import
  ///
  /// In en, this message translates to:
  /// **'Successfully imported {folders} folders and {notes} notes'**
  String importSuccess(int folders, int notes);

  /// Error message when import fails
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importFailed;

  /// Error message for invalid backup file
  ///
  /// In en, this message translates to:
  /// **'Invalid backup file'**
  String get invalidBackupFile;

  /// Button to export all data as backup
  ///
  /// In en, this message translates to:
  /// **'Export Backup'**
  String get exportBackup;

  /// Label for folders section
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get folders;

  /// Label for notes section
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Button text to create a new folder
  ///
  /// In en, this message translates to:
  /// **'Create Folder'**
  String get createFolder;

  /// Button text to create a new note
  ///
  /// In en, this message translates to:
  /// **'Create Note'**
  String get createNote;

  /// Label for folder name input
  ///
  /// In en, this message translates to:
  /// **'Folder Name'**
  String get folderName;

  /// Label for note name input
  ///
  /// In en, this message translates to:
  /// **'Note Name'**
  String get noteName;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Create button text
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Edit button text
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Delete button text
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Save button text
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Search placeholder text
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Error message with placeholder
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String error(String message);

  /// Created date label
  ///
  /// In en, this message translates to:
  /// **'Created: {date}'**
  String created(String date);

  /// Updated date label
  ///
  /// In en, this message translates to:
  /// **'Updated: {date}'**
  String updated(String date);

  /// Delete folder dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Folder'**
  String get deleteFolder;

  /// Delete folder confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteFolderConfirm(String name);

  /// Delete folder confirmation message when folder contains notes
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This will also delete {count} note(s).'**
  String deleteFolderWithNotesConfirm(String name, int count);

  /// Rename button text
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// Rename folder dialog title
  ///
  /// In en, this message translates to:
  /// **'Rename Folder'**
  String get renameFolder;

  /// Default title for untitled notes
  ///
  /// In en, this message translates to:
  /// **'Untitled Note'**
  String get untitledNote;

  /// Text shown for empty notes
  ///
  /// In en, this message translates to:
  /// **'Empty note'**
  String get emptyNote;

  /// Delete note dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Note'**
  String get deleteNote;

  /// Delete note confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?'**
  String deleteNoteConfirm(String title);

  /// Text for deleting unnamed note
  ///
  /// In en, this message translates to:
  /// **'this note'**
  String get deleteThisNote;

  /// Hint text for folder name input
  ///
  /// In en, this message translates to:
  /// **'Enter folder name'**
  String get enterFolderName;

  /// Title for new note
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get newNote;

  /// Tooltip for switching to edit mode
  ///
  /// In en, this message translates to:
  /// **'Switch to Edit mode'**
  String get switchToEditMode;

  /// Tooltip for previewing markdown
  ///
  /// In en, this message translates to:
  /// **'Preview markdown'**
  String get previewMarkdown;

  /// Preview button text
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// Tooltip when auto-save is enabled
  ///
  /// In en, this message translates to:
  /// **'Auto-save is ON (saves every 5s after changes)'**
  String get autoSaveOn;

  /// Tooltip to enable auto-save
  ///
  /// In en, this message translates to:
  /// **'Enable auto-save'**
  String get enableAutoSave;

  /// Auto-save off tooltip
  ///
  /// In en, this message translates to:
  /// **'Auto-save OFF'**
  String get autoSaveOff;

  /// Tooltip for save button
  ///
  /// In en, this message translates to:
  /// **'Save note'**
  String get saveNote;

  /// Placeholder text when no content
  ///
  /// In en, this message translates to:
  /// **'*No content yet*'**
  String get noContentYet;

  /// Hint text for note editor
  ///
  /// In en, this message translates to:
  /// **'Start writing your first note...'**
  String get startWriting;

  /// Error message when note is empty
  ///
  /// In en, this message translates to:
  /// **'Note cannot be empty'**
  String get noteCannotBeEmpty;

  /// Success message when note is saved
  ///
  /// In en, this message translates to:
  /// **'Note saved!'**
  String get noteSaved;

  /// Edit title dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Title'**
  String get editTitle;

  /// Hint text for note title input
  ///
  /// In en, this message translates to:
  /// **'Enter note title'**
  String get enterNoteTitle;

  /// Message when auto-save is enabled
  ///
  /// In en, this message translates to:
  /// **'Auto-save enabled'**
  String get autoSaveEnabled;

  /// Message when auto-save is disabled
  ///
  /// In en, this message translates to:
  /// **'Auto-save disabled'**
  String get autoSaveDisabled;

  /// Markdown shortcuts page title
  ///
  /// In en, this message translates to:
  /// **'Markdown Shortcuts'**
  String get markdownShortcuts;

  /// Markdown shortcuts settings description
  ///
  /// In en, this message translates to:
  /// **'Customize toolbar buttons and actions'**
  String get markdownShortcutsDesc;

  /// Reset to default button text
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get resetToDefault;

  /// Remove all custom shortcuts button text
  ///
  /// In en, this message translates to:
  /// **'Remove All Custom'**
  String get removeAllCustom;

  /// Message when no custom shortcuts exist
  ///
  /// In en, this message translates to:
  /// **'No custom shortcuts yet'**
  String get noCustomShortcutsYet;

  /// Hint to add shortcuts
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to add one'**
  String get tapToAddShortcut;

  /// Delete shortcut dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Shortcut'**
  String get deleteShortcut;

  /// Delete shortcut confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this shortcut?'**
  String get deleteShortcutConfirm;

  /// Reset dialog title
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get resetDialogTitle;

  /// Reset dialog message
  ///
  /// In en, this message translates to:
  /// **'This will restore all default shortcuts to their original order and settings. Custom shortcuts will be kept but moved to the end.'**
  String get resetDialogMessage;

  /// Reset button text
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// Remove custom dialog title
  ///
  /// In en, this message translates to:
  /// **'Remove All Custom'**
  String get removeCustomDialogTitle;

  /// Remove custom dialog message
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all custom shortcuts you created. Default shortcuts will remain.'**
  String get removeCustomDialogMessage;

  /// Remove button text
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Label for default shortcuts
  ///
  /// In en, this message translates to:
  /// **'DEFAULT'**
  String get defaultLabel;

  /// Description for date shortcut
  ///
  /// In en, this message translates to:
  /// **'Inserts current date'**
  String get insertsCurrentDate;

  /// Description for header shortcut
  ///
  /// In en, this message translates to:
  /// **'Opens header menu (H1-H6)'**
  String get opensHeaderMenu;

  /// Description showing before and after text
  ///
  /// In en, this message translates to:
  /// **'Before: \"{before}\" | After: \"{after}\"'**
  String beforeAfterText(String before, String after);

  /// Hide button tooltip
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// Show button tooltip
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// New shortcut dialog title
  ///
  /// In en, this message translates to:
  /// **'New Shortcut'**
  String get newShortcut;

  /// Edit shortcut dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Shortcut'**
  String get editShortcut;

  /// Icon label
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get icon;

  /// Hint to change icon
  ///
  /// In en, this message translates to:
  /// **'Tap to change icon'**
  String get tapToChangeIcon;

  /// Select icon dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Icon'**
  String get selectIcon;

  /// Placeholder for icon search input
  ///
  /// In en, this message translates to:
  /// **'Search icons...'**
  String get searchIcons;

  /// Message when no icons match search
  ///
  /// In en, this message translates to:
  /// **'No icons found'**
  String get noIconsFound;

  /// Label input field
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get label;

  /// Hint for label input
  ///
  /// In en, this message translates to:
  /// **'e.g., Highlight'**
  String get labelHint;

  /// Insert type label
  ///
  /// In en, this message translates to:
  /// **'Insert Type'**
  String get insertType;

  /// Wrap selected text option
  ///
  /// In en, this message translates to:
  /// **'Wrap Selected Text'**
  String get wrapSelectedText;

  /// Insert current date option
  ///
  /// In en, this message translates to:
  /// **'Insert Current Date'**
  String get insertCurrentDate;

  /// Before date label
  ///
  /// In en, this message translates to:
  /// **'Before Date (optional)'**
  String get beforeDate;

  /// Markdown start label
  ///
  /// In en, this message translates to:
  /// **'Markdown Start'**
  String get markdownStart;

  /// Hint for markdown start
  ///
  /// In en, this message translates to:
  /// **'e.g., =='**
  String get markdownStartHint;

  /// Hint for text before date
  ///
  /// In en, this message translates to:
  /// **'Optional text before date'**
  String get optionalTextBeforeDate;

  /// After date label
  ///
  /// In en, this message translates to:
  /// **'After Date (optional)'**
  String get afterDate;

  /// Markdown end label
  ///
  /// In en, this message translates to:
  /// **'Markdown End'**
  String get markdownEnd;

  /// Hint for text after date
  ///
  /// In en, this message translates to:
  /// **'Optional text after date'**
  String get optionalTextAfterDate;

  /// Error message when label is empty
  ///
  /// In en, this message translates to:
  /// **'Label cannot be empty'**
  String get labelCannotBeEmpty;

  /// Snackbar message when form has validation errors
  ///
  /// In en, this message translates to:
  /// **'Please fix the errors in the form'**
  String get formHasErrors;

  /// Bold shortcut label
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get bold;

  /// Italic shortcut label
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get italic;

  /// Headers shortcut label
  ///
  /// In en, this message translates to:
  /// **'Headers'**
  String get headers;

  /// Point list shortcut label
  ///
  /// In en, this message translates to:
  /// **'Point List'**
  String get pointList;

  /// Strikethrough shortcut label
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get strikethrough;

  /// Bullet list shortcut label
  ///
  /// In en, this message translates to:
  /// **'Bullet List'**
  String get bulletList;

  /// Numbered list shortcut label
  ///
  /// In en, this message translates to:
  /// **'Numbered List'**
  String get numberedList;

  /// Checkbox shortcut label
  ///
  /// In en, this message translates to:
  /// **'Checkbox'**
  String get checkbox;

  /// Quote shortcut label
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get quote;

  /// Inline code shortcut label
  ///
  /// In en, this message translates to:
  /// **'Inline Code'**
  String get inlineCode;

  /// Code block shortcut label
  ///
  /// In en, this message translates to:
  /// **'Code Block'**
  String get codeBlock;

  /// Link shortcut label
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// Current date shortcut label
  ///
  /// In en, this message translates to:
  /// **'Current Date'**
  String get currentDate;

  /// Header 1 menu item
  ///
  /// In en, this message translates to:
  /// **'Header 1'**
  String get header1;

  /// Header 2 menu item
  ///
  /// In en, this message translates to:
  /// **'Header 2'**
  String get header2;

  /// Header 3 menu item
  ///
  /// In en, this message translates to:
  /// **'Header 3'**
  String get header3;

  /// Header 4 menu item
  ///
  /// In en, this message translates to:
  /// **'Header 4'**
  String get header4;

  /// Header 5 menu item
  ///
  /// In en, this message translates to:
  /// **'Header 5'**
  String get header5;

  /// Header 6 menu item
  ///
  /// In en, this message translates to:
  /// **'Header 6'**
  String get header6;

  /// Undo button tooltip
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// Redo button tooltip
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// Paste button tooltip
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// Decrease font size button tooltip
  ///
  /// In en, this message translates to:
  /// **'Decrease Font Size'**
  String get decreaseFontSize;

  /// Increase font size button tooltip
  ///
  /// In en, this message translates to:
  /// **'Increase Font Size'**
  String get increaseFontSize;

  /// Settings label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Accessibility label for drop indicator during drag
  ///
  /// In en, this message translates to:
  /// **'Drop position'**
  String get dropPosition;

  /// Accessibility hint for reorderable buttons
  ///
  /// In en, this message translates to:
  /// **'Long press to reorder'**
  String get longPressToReorder;

  /// Accessibility label for shortcut button
  ///
  /// In en, this message translates to:
  /// **'{label} button'**
  String shortcutButton(String label);

  /// Warning message to remind users to add space after markdown syntax
  ///
  /// In en, this message translates to:
  /// **'Tip: Add a space after markdown syntax (e.g., \'# \' or \'- \') for proper formatting.'**
  String get markdownSpaceWarning;

  /// Tooltip for reorder shortcuts button
  ///
  /// In en, this message translates to:
  /// **'Reorder shortcuts'**
  String get reorderShortcuts;

  /// Button text to finish reordering
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneReordering;

  /// Message when search returns no results
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noSearchResults;

  /// Hint text for search input
  ///
  /// In en, this message translates to:
  /// **'Type to search notes'**
  String get searchHint;

  /// Text shown while loading more items
  ///
  /// In en, this message translates to:
  /// **'Loading more...'**
  String get loadingMore;

  /// Text shown when all notes are loaded
  ///
  /// In en, this message translates to:
  /// **'No more notes'**
  String get noMoreNotes;

  /// Label for sort options
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// Sort option for last updated
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get sortByUpdated;

  /// Sort option for date created
  ///
  /// In en, this message translates to:
  /// **'Date created'**
  String get sortByCreated;

  /// Sort option for title
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get sortByTitle;

  /// Ascending sort order
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get ascending;

  /// Descending sort order
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get descending;

  /// Message shown while loading note content
  ///
  /// In en, this message translates to:
  /// **'Loading content...'**
  String get loadingContent;

  /// Warning for large notes
  ///
  /// In en, this message translates to:
  /// **'This note is very large and may take a moment to load'**
  String get largeNoteWarning;

  /// Note statistics display
  ///
  /// In en, this message translates to:
  /// **'{count} distinct characters, {chunks} chunks'**
  String noteStats(int count, int chunks);

  /// Label for compressed notes
  ///
  /// In en, this message translates to:
  /// **'Compressed'**
  String get compressedNote;

  /// Tooltip for folder search
  ///
  /// In en, this message translates to:
  /// **'Search in this folder'**
  String get searchInFolder;

  /// Tooltip for global search
  ///
  /// In en, this message translates to:
  /// **'Search all notes'**
  String get searchAll;

  /// Label for recent searches section
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearches;

  /// Button to clear search history
  ///
  /// In en, this message translates to:
  /// **'Clear search history'**
  String get clearSearchHistory;

  /// Label for date filter
  ///
  /// In en, this message translates to:
  /// **'Filter by date'**
  String get filterByDate;

  /// Label for start date filter
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromDate;

  /// Label for end date filter
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get toDate;

  /// Button to apply filters
  ///
  /// In en, this message translates to:
  /// **'Apply filter'**
  String get applyFilter;

  /// Button to clear filters
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get clearFilter;

  /// Number of search matches
  ///
  /// In en, this message translates to:
  /// **'{count} matches found'**
  String matchesFound(int count);

  /// Message shown during auto-save
  ///
  /// In en, this message translates to:
  /// **'Auto-saving...'**
  String get autoSaving;

  /// Message after successful save
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get changesSaved;

  /// Warning about unsaved changes
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get unsavedChanges;

  /// Button to discard changes
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges;

  /// Button to continue editing
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// Info about virtual scrolling
  ///
  /// In en, this message translates to:
  /// **'Virtual scroll enabled for large content'**
  String get virtualScrollEnabled;

  /// Number of lines in note
  ///
  /// In en, this message translates to:
  /// **'{count} lines'**
  String lineCount(int count);

  /// Hint text shown when there are no folders
  ///
  /// In en, this message translates to:
  /// **'Looks like you might want to create a folder'**
  String get emptyFoldersHint;

  /// Hint text shown when there are no notes in a folder
  ///
  /// In en, this message translates to:
  /// **'Write your first note'**
  String get emptyNotesHint;

  /// Hint to tap the plus button
  ///
  /// In en, this message translates to:
  /// **'Tap + to get started'**
  String get tapPlusToCreate;

  /// Character count display
  ///
  /// In en, this message translates to:
  /// **'{current}/{max} characters'**
  String charactersCount(int current, int max);

  /// Database settings menu item
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get databaseSettings;

  /// Database settings description
  ///
  /// In en, this message translates to:
  /// **'Manage database location and storage'**
  String get databaseSettingsDesc;

  /// About menu item
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Database location card title
  ///
  /// In en, this message translates to:
  /// **'Database Location'**
  String get databaseLocation;

  /// Copy path button text
  ///
  /// In en, this message translates to:
  /// **'Copy Path'**
  String get copyPath;

  /// Open in Finder/Explorer button text
  ///
  /// In en, this message translates to:
  /// **'Open Folder'**
  String get openInFinder;

  /// Database statistics card title
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get databaseStats;

  /// Size label
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// Last modified label
  ///
  /// In en, this message translates to:
  /// **'Last Modified'**
  String get lastModified;

  /// Maintenance card title
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenance;

  /// Maintenance description
  ///
  /// In en, this message translates to:
  /// **'Run SQLite VACUUM to reclaim unused space from deleted notes and folders. This rebuilds the database file, defragments the data, and can significantly reduce file size after deleting large amounts of content. The operation may take a few seconds depending on database size.'**
  String get maintenanceDesc;

  /// Optimize database button text
  ///
  /// In en, this message translates to:
  /// **'Optimize Database'**
  String get optimizeDatabase;

  /// Danger zone card title
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZone;

  /// Danger zone description
  ///
  /// In en, this message translates to:
  /// **'These actions are irreversible. All your notes and folders will be permanently deleted.'**
  String get dangerZoneDesc;

  /// Delete all data button text
  ///
  /// In en, this message translates to:
  /// **'Delete All Data'**
  String get deleteAllData;

  /// Path copied confirmation message
  ///
  /// In en, this message translates to:
  /// **'Path copied to clipboard'**
  String get pathCopied;

  /// Platform not supported message
  ///
  /// In en, this message translates to:
  /// **'Not supported on this platform'**
  String get notSupportedOnPlatform;

  /// Error opening folder message
  ///
  /// In en, this message translates to:
  /// **'Error opening folder'**
  String get errorOpeningFolder;

  /// Optimizing message
  ///
  /// In en, this message translates to:
  /// **'Optimizing database...'**
  String get optimizing;

  /// Optimization complete message
  ///
  /// In en, this message translates to:
  /// **'Database optimized successfully'**
  String get optimizationComplete;

  /// Saved suffix for size reduction
  ///
  /// In en, this message translates to:
  /// **'saved'**
  String get saved;

  /// Message when no space was reclaimed
  ///
  /// In en, this message translates to:
  /// **'database already optimized'**
  String get alreadyOptimized;

  /// Delete confirmation message
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. All your notes, folders, and data will be permanently deleted. Are you absolutely sure?'**
  String get deleteConfirmation;

  /// Delete not implemented message
  ///
  /// In en, this message translates to:
  /// **'Delete functionality not yet implemented for safety'**
  String get deleteNotImplemented;

  /// Loading text while deleting data
  ///
  /// In en, this message translates to:
  /// **'Deleting all data...'**
  String get deletingData;

  /// Title for data deleted success dialog
  ///
  /// In en, this message translates to:
  /// **'Data Deleted'**
  String get dataDeleted;

  /// Hint that restart may be needed
  ///
  /// In en, this message translates to:
  /// **'Restart may be required for full effect'**
  String get restartRequired;

  /// Button to exit the app
  ///
  /// In en, this message translates to:
  /// **'Exit App'**
  String get exitApp;

  /// Error message prefix for deletion failure
  ///
  /// In en, this message translates to:
  /// **'Error deleting data'**
  String get errorDeletingData;

  /// Share database button text
  ///
  /// In en, this message translates to:
  /// **'Share Database'**
  String get shareDatabase;

  /// Share database description
  ///
  /// In en, this message translates to:
  /// **'Export and share your database file via email, messaging apps, or cloud storage for backup purposes.'**
  String get shareDatabaseDesc;

  /// Message shown while preparing share
  ///
  /// In en, this message translates to:
  /// **'Preparing to share...'**
  String get preparingShare;

  /// Share error message prefix
  ///
  /// In en, this message translates to:
  /// **'Error sharing database'**
  String get shareError;

  /// Error when database file does not exist
  ///
  /// In en, this message translates to:
  /// **'Database file not found'**
  String get databaseNotFound;

  /// Rename note dialog title
  ///
  /// In en, this message translates to:
  /// **'Rename Note'**
  String get renameNote;

  /// Hint text for rename input
  ///
  /// In en, this message translates to:
  /// **'Enter new name'**
  String get enterNewName;

  /// Reorder mode toggle tooltip
  ///
  /// In en, this message translates to:
  /// **'Reorder Mode'**
  String get reorderMode;

  /// Hint for drag and drop reordering
  ///
  /// In en, this message translates to:
  /// **'Drag items to reorder'**
  String get dragToReorder;

  /// Custom sort order option
  ///
  /// In en, this message translates to:
  /// **'Custom Order'**
  String get sortByCustom;

  /// Quick sort button label
  ///
  /// In en, this message translates to:
  /// **'Quick Sort'**
  String get quickSort;

  /// Sort items dialog title
  ///
  /// In en, this message translates to:
  /// **'Sort Items'**
  String get sortItems;

  /// Sort folders option
  ///
  /// In en, this message translates to:
  /// **'Sort Folders'**
  String get sortFolders;

  /// Sort notes option
  ///
  /// In en, this message translates to:
  /// **'Sort Notes'**
  String get sortNotes;

  /// Sort by name option
  ///
  /// In en, this message translates to:
  /// **'By Name'**
  String get sortByName;

  /// Move item up action
  ///
  /// In en, this message translates to:
  /// **'Move Up'**
  String get moveUp;

  /// Move item down action
  ///
  /// In en, this message translates to:
  /// **'Move Down'**
  String get moveDown;

  /// Controls settings menu item
  ///
  /// In en, this message translates to:
  /// **'Controls'**
  String get controlsSettings;

  /// Controls settings description
  ///
  /// In en, this message translates to:
  /// **'Gestures, haptics and interactions'**
  String get controlsSettingsDesc;

  /// Gestures section title
  ///
  /// In en, this message translates to:
  /// **'Gestures'**
  String get gesturesSection;

  /// Folder swipe gesture setting
  ///
  /// In en, this message translates to:
  /// **'Swipe to open menu in folders'**
  String get folderSwipeGesture;

  /// Folder swipe gesture description
  ///
  /// In en, this message translates to:
  /// **'Swipe from left edge to open the navigation menu when browsing folders'**
  String get folderSwipeGestureDesc;

  /// Note swipe gesture setting
  ///
  /// In en, this message translates to:
  /// **'Swipe to open menu in notes'**
  String get noteSwipeGesture;

  /// Note swipe gesture description
  ///
  /// In en, this message translates to:
  /// **'Swipe from left edge to open the navigation menu when editing notes'**
  String get noteSwipeGestureDesc;

  /// Feedback section title
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedbackSection;

  /// Haptic feedback setting
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get hapticFeedback;

  /// Haptic feedback description
  ///
  /// In en, this message translates to:
  /// **'Vibrate on interactions like toggling switches'**
  String get hapticFeedbackDesc;

  /// Confirm delete setting
  ///
  /// In en, this message translates to:
  /// **'Confirm before delete'**
  String get confirmDelete;

  /// Confirm delete description
  ///
  /// In en, this message translates to:
  /// **'Show confirmation dialog before deleting notes or folders'**
  String get confirmDeleteDesc;

  /// Auto-save section title
  ///
  /// In en, this message translates to:
  /// **'Auto-save'**
  String get autoSaveSection;

  /// Auto-save setting
  ///
  /// In en, this message translates to:
  /// **'Auto-save notes'**
  String get autoSave;

  /// Auto-save description
  ///
  /// In en, this message translates to:
  /// **'Automatically save notes while editing'**
  String get autoSaveDesc;

  /// Auto-save interval setting
  ///
  /// In en, this message translates to:
  /// **'Auto-save interval'**
  String get autoSaveInterval;

  /// Auto-save interval description
  ///
  /// In en, this message translates to:
  /// **'Save every {seconds} seconds'**
  String autoSaveIntervalDesc(int seconds);

  /// Display section title
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get displaySection;

  /// Show note preview setting
  ///
  /// In en, this message translates to:
  /// **'Show note preview'**
  String get showNotePreview;

  /// Show note preview description
  ///
  /// In en, this message translates to:
  /// **'Display a preview of note content in the list'**
  String get showNotePreviewDesc;

  /// Show stats bar setting
  ///
  /// In en, this message translates to:
  /// **'Show stats bar'**
  String get showStatsBar;

  /// Show stats bar description
  ///
  /// In en, this message translates to:
  /// **'Display character count and line count in note editor'**
  String get showStatsBarDesc;

  /// Reset to defaults button
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get resetToDefaults;

  /// Reset to defaults confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset all settings to their default values?'**
  String get resetToDefaultsConfirm;

  /// Settings reset confirmation message
  ///
  /// In en, this message translates to:
  /// **'Settings have been reset to defaults'**
  String get settingsReset;

  /// Share note option
  ///
  /// In en, this message translates to:
  /// **'Share Note'**
  String get shareNote;

  /// Note options bottom sheet title
  ///
  /// In en, this message translates to:
  /// **'Note Options'**
  String get noteOptions;

  /// Message shown while exporting note
  ///
  /// In en, this message translates to:
  /// **'Exporting note...'**
  String get exportingNote;

  /// Error message when note export fails
  ///
  /// In en, this message translates to:
  /// **'Error exporting note'**
  String get noteExportError;

  /// Title for export format selection dialog
  ///
  /// In en, this message translates to:
  /// **'Choose Export Format'**
  String get chooseExportFormat;

  /// Export as markdown option
  ///
  /// In en, this message translates to:
  /// **'Markdown (.md)'**
  String get exportAsMarkdown;

  /// Export as JSON option
  ///
  /// In en, this message translates to:
  /// **'JSON (.json)'**
  String get exportAsJson;

  /// Export as plain text option
  ///
  /// In en, this message translates to:
  /// **'Plain Text (.txt)'**
  String get exportAsText;

  /// Section title for active database selection
  ///
  /// In en, this message translates to:
  /// **'Active Database'**
  String get activeDatabaseSection;

  /// Description for active database section
  ///
  /// In en, this message translates to:
  /// **'Select which database to use. Creating or switching databases will restart the app.'**
  String get activeDatabaseDesc;

  /// Label for database selector
  ///
  /// In en, this message translates to:
  /// **'Select Database'**
  String get selectDatabase;

  /// Shows current active database
  ///
  /// In en, this message translates to:
  /// **'Current: {name}'**
  String currentDatabase(String name);

  /// Button to create new database
  ///
  /// In en, this message translates to:
  /// **'Create New Database'**
  String get createNewDatabase;

  /// Label for new database name input
  ///
  /// In en, this message translates to:
  /// **'Database Name'**
  String get newDatabaseName;

  /// Hint for database name input
  ///
  /// In en, this message translates to:
  /// **'Enter database name'**
  String get enterDatabaseName;

  /// Error for invalid database name
  ///
  /// In en, this message translates to:
  /// **'Invalid name. Use only letters, numbers, underscores, and hyphens (max 50 characters).'**
  String get invalidDatabaseName;

  /// Error when database already exists
  ///
  /// In en, this message translates to:
  /// **'A database with this name already exists.'**
  String get databaseExists;

  /// Message while creating database
  ///
  /// In en, this message translates to:
  /// **'Creating database...'**
  String get creatingDatabase;

  /// Success message after creating database
  ///
  /// In en, this message translates to:
  /// **'Database created successfully'**
  String get databaseCreated;

  /// Dialog title for renaming database
  ///
  /// In en, this message translates to:
  /// **'Rename Database'**
  String get renameDatabase;

  /// Message while renaming database
  ///
  /// In en, this message translates to:
  /// **'Renaming database...'**
  String get renamingDatabase;

  /// Success message after renaming database
  ///
  /// In en, this message translates to:
  /// **'Database renamed successfully'**
  String get databaseRenamed;

  /// Message while switching database
  ///
  /// In en, this message translates to:
  /// **'Switching database...'**
  String get switchingDatabase;

  /// Section title for database list
  ///
  /// In en, this message translates to:
  /// **'Available Databases'**
  String get availableDatabases;

  /// Message when no databases exist
  ///
  /// In en, this message translates to:
  /// **'No databases found'**
  String get noDatabases;

  /// Title for database options menu
  ///
  /// In en, this message translates to:
  /// **'Database Options'**
  String get databaseOptions;

  /// Option to switch to a database
  ///
  /// In en, this message translates to:
  /// **'Switch to this database'**
  String get switchTo;

  /// Confirmation message for database deletion
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the database \"{name}\"? This action cannot be undone.'**
  String deleteDatabaseConfirm(String name);

  /// Error when trying to delete active database
  ///
  /// In en, this message translates to:
  /// **'Cannot delete the currently active database. Please switch to another database first.'**
  String get cannotDeleteActive;

  /// Success message after deleting database
  ///
  /// In en, this message translates to:
  /// **'Database deleted'**
  String get databaseDeleted;

  /// Placeholder for note search field
  ///
  /// In en, this message translates to:
  /// **'Find in note'**
  String get findInNote;

  /// Placeholder for replace field
  ///
  /// In en, this message translates to:
  /// **'Replace with'**
  String get replaceWith;

  /// Button to replace current match
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replaceOne;

  /// Button to replace all matches
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get replaceAll;

  /// Message showing how many matches were replaced
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Replaced 1 match} other{Replaced {count} matches}}'**
  String replacedCount(int count);

  /// Option to enable case-sensitive search
  ///
  /// In en, this message translates to:
  /// **'Match case'**
  String get matchCase;

  /// Option to match whole words only
  ///
  /// In en, this message translates to:
  /// **'Whole word'**
  String get wholeWord;

  /// Option to enable regex search
  ///
  /// In en, this message translates to:
  /// **'Use regex'**
  String get useRegex;

  /// Option to show replace field
  ///
  /// In en, this message translates to:
  /// **'Find & Replace'**
  String get findAndReplace;

  /// Search options button tooltip
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get options;

  /// Previous match button tooltip
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// Next match button tooltip
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Close button tooltip
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Date format settings dialog title
  ///
  /// In en, this message translates to:
  /// **'Date Format'**
  String get dateFormatSettings;

  /// Date format selection hint
  ///
  /// In en, this message translates to:
  /// **'Choose how dates will be displayed:'**
  String get selectDateFormat;

  /// Hint for date button long press
  ///
  /// In en, this message translates to:
  /// **'Long press to change format'**
  String get longPressToChangeFormat;

  /// Language settings menu item
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSettings;

  /// Language settings description
  ///
  /// In en, this message translates to:
  /// **'Change app display language'**
  String get languageSettingsDesc;

  /// Language selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// German language option
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get german;

  /// Romanian language option
  ///
  /// In en, this message translates to:
  /// **'Romanian'**
  String get romanian;

  /// System default language option
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// Theme settings menu item
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get themeSettings;

  /// Theme settings description
  ///
  /// In en, this message translates to:
  /// **'Dark mode, colors and display'**
  String get themeSettingsDesc;

  /// Theme selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Theme'**
  String get selectTheme;

  /// Light theme option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// Dark theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// System theme option
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTheme;

  /// Search settings section title
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchSection;

  /// Setting for cursor behavior when navigating search matches
  ///
  /// In en, this message translates to:
  /// **'Search Navigation'**
  String get searchCursorBehavior;

  /// Description for search cursor behavior setting
  ///
  /// In en, this message translates to:
  /// **'Where to place the cursor when jumping to a search match'**
  String get searchCursorBehaviorDesc;

  /// Place cursor before the match
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get cursorAtStart;

  /// Place cursor after the match
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get cursorAtEnd;

  /// Select the entire match
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectMatch;

  /// Shown while search is in progress
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get searching;

  /// Editor settings section title
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get editorSection;

  /// Setting for showing line numbers in editor
  ///
  /// In en, this message translates to:
  /// **'Line Numbers'**
  String get showLineNumbers;

  /// Description for show line numbers setting
  ///
  /// In en, this message translates to:
  /// **'Display line numbers on the left side of the editor'**
  String get showLineNumbersDesc;

  /// Setting for word wrapping in editor
  ///
  /// In en, this message translates to:
  /// **'Word Wrap'**
  String get wordWrap;

  /// Description for word wrap setting
  ///
  /// In en, this message translates to:
  /// **'Wrap long lines to fit within the editor width'**
  String get wordWrapDesc;

  /// Setting for highlighting the current line in editor
  ///
  /// In en, this message translates to:
  /// **'Highlight Current Line'**
  String get showCursorLine;

  /// Description for show cursor line setting
  ///
  /// In en, this message translates to:
  /// **'Highlight the line where the cursor is positioned'**
  String get showCursorLineDesc;

  /// Setting for automatically breaking long lines on paste
  ///
  /// In en, this message translates to:
  /// **'Auto-Break Long Lines'**
  String get autoBreakLongLines;

  /// Description for auto break long lines setting
  ///
  /// In en, this message translates to:
  /// **'Automatically break long lines when pasting text. May slightly affect search positioning accuracy in preview mode.'**
  String get autoBreakLongLinesDesc;

  /// Setting to show preview mode when keyboard is hidden
  ///
  /// In en, this message translates to:
  /// **'Preview When Keyboard Hidden'**
  String get previewWhenKeyboardHidden;

  /// Description for preview when keyboard hidden setting
  ///
  /// In en, this message translates to:
  /// **'Show rendered markdown preview when the keyboard is hidden. The editor appears when you tap to type.'**
  String get previewWhenKeyboardHiddenDesc;

  /// Toast message when lines are formatted on paste
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 long line was formatted} other{{count} long lines were formatted}}'**
  String linesFormatted(int count);

  /// Preview settings section title
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewSection;

  /// Setting for showing scrollbar in preview mode
  ///
  /// In en, this message translates to:
  /// **'Preview Scrollbar'**
  String get showPreviewScrollbar;

  /// Description for show preview scrollbar setting
  ///
  /// In en, this message translates to:
  /// **'Show an interactive scrollbar in preview mode (experimental)'**
  String get showPreviewScrollbarDesc;

  /// Preview performance settings section title
  ///
  /// In en, this message translates to:
  /// **'Preview Performance'**
  String get previewPerformanceSection;

  /// Setting for number of lines per render chunk in preview
  ///
  /// In en, this message translates to:
  /// **'Lines Per Chunk'**
  String get previewLinesPerChunk;

  /// Description for lines per chunk setting
  ///
  /// In en, this message translates to:
  /// **'{count} lines per chunk (higher = better performance, lower = more precise search scroll)'**
  String previewLinesPerChunkDesc(int count);

  /// Section title for date offset settings
  ///
  /// In en, this message translates to:
  /// **'Date Offset'**
  String get dateOffset;

  /// Description for date offset feature
  ///
  /// In en, this message translates to:
  /// **'Shift the date forward or backward from today'**
  String get dateOffsetDescription;

  /// Label for days input
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get days;

  /// Label for months input
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get monthsLabel;

  /// Label for years input
  ///
  /// In en, this message translates to:
  /// **'Years'**
  String get yearsLabel;

  /// Section title for repeat settings
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeatSettings;

  /// Description for repeat feature
  ///
  /// In en, this message translates to:
  /// **'Insert this shortcut multiple times'**
  String get repeatDescription;

  /// Label for repeat count
  ///
  /// In en, this message translates to:
  /// **'Repeat count'**
  String get repeatCount;

  /// Label for separator selection
  ///
  /// In en, this message translates to:
  /// **'Separator'**
  String get separator;

  /// New line separator option
  ///
  /// In en, this message translates to:
  /// **'New line'**
  String get newLine;

  /// No separator option
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noSeparator;

  /// Space separator option
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get space;

  /// Non-breaking space separator option
  ///
  /// In en, this message translates to:
  /// **'Non-breaking'**
  String get nbspSpace;

  /// Blank line separator option (double newline)
  ///
  /// In en, this message translates to:
  /// **'Blank line'**
  String get blankLine;

  /// Comma separator option
  ///
  /// In en, this message translates to:
  /// **'Comma'**
  String get comma;

  /// Pipe separator option
  ///
  /// In en, this message translates to:
  /// **'Pipe'**
  String get pipe;

  /// Toggle to increment date for each repetition
  ///
  /// In en, this message translates to:
  /// **'Increment date on repeat'**
  String get incrementDateOnRepeat;

  /// Label for date increment values
  ///
  /// In en, this message translates to:
  /// **'Increment by for each repetition:'**
  String get incrementByEachRepeat;

  /// Toggle label for advanced shortcut options
  ///
  /// In en, this message translates to:
  /// **'Advanced Options'**
  String get advancedOptions;

  /// Description for advanced options toggle
  ///
  /// In en, this message translates to:
  /// **'Date offset, repeat, and more'**
  String get advancedOptionsDescription;

  /// Label for wrapper text around all repeated items
  ///
  /// In en, this message translates to:
  /// **'Wrapper text'**
  String get repeatWrapperText;

  /// Description for wrapper text fields
  ///
  /// In en, this message translates to:
  /// **'Text inserted before/after all repeated items'**
  String get repeatWrapperTextDesc;

  /// Label for text before all repeated items
  ///
  /// In en, this message translates to:
  /// **'Before all'**
  String get beforeAllRepeats;

  /// Hint for before all repeats field
  ///
  /// In en, this message translates to:
  /// **'e.g., ## Week 1\\n'**
  String get beforeAllRepeatsHint;

  /// Label for text after all repeated items
  ///
  /// In en, this message translates to:
  /// **'After all'**
  String get afterAllRepeats;

  /// Hint for after all repeats field
  ///
  /// In en, this message translates to:
  /// **'e.g., \\n---'**
  String get afterAllRepeatsHint;

  /// Title for developer options page
  ///
  /// In en, this message translates to:
  /// **'Developer Options'**
  String get developerOptions;

  /// Description for developer options in drawer
  ///
  /// In en, this message translates to:
  /// **'Debug tools and diagnostics'**
  String get developerOptionsDesc;

  /// Warning message on developer options page
  ///
  /// In en, this message translates to:
  /// **'These options are for debugging only. Enabling them may affect app performance.'**
  String get developerOptionsWarning;

  /// Toast message when dev options are reset
  ///
  /// In en, this message translates to:
  /// **'Developer options reset to defaults'**
  String get developerOptionsReset;

  /// Toast message when developer mode is unlocked by swiping gym icon
  ///
  /// In en, this message translates to:
  /// **'Developer mode unlocked!'**
  String get developerModeUnlocked;

  /// Button to hide developer options from menu
  ///
  /// In en, this message translates to:
  /// **'Lock Developer Mode'**
  String get lockDeveloperMode;

  /// Toast message when developer mode is locked
  ///
  /// In en, this message translates to:
  /// **'Developer mode locked'**
  String get developerModeLocked;

  /// Section title for visualization debug options
  ///
  /// In en, this message translates to:
  /// **'Visualization / Debug'**
  String get visualizationDebug;

  /// Option to color different markdown blocks
  ///
  /// In en, this message translates to:
  /// **'Color Markdown Blocks'**
  String get colorMarkdownBlocks;

  /// Description for color markdown blocks option
  ///
  /// In en, this message translates to:
  /// **'Show different colors for headers, code, lists, etc.'**
  String get colorMarkdownBlocksDesc;

  /// Option to show block boundaries
  ///
  /// In en, this message translates to:
  /// **'Show Block Boundaries'**
  String get showBlockBoundaries;

  /// Description for show block boundaries option
  ///
  /// In en, this message translates to:
  /// **'Draw borders around each parsed element'**
  String get showBlockBoundariesDesc;

  /// Option to show whitespace characters
  ///
  /// In en, this message translates to:
  /// **'Show Whitespace'**
  String get showWhitespace;

  /// Description for show whitespace option
  ///
  /// In en, this message translates to:
  /// **'Visualize spaces, tabs, and newlines'**
  String get showWhitespaceDesc;

  /// Option to show line numbers in preview
  ///
  /// In en, this message translates to:
  /// **'Preview Line Numbers'**
  String get showPreviewLineNumbers;

  /// Description for show preview line numbers option
  ///
  /// In en, this message translates to:
  /// **'Show source line numbers in preview mode'**
  String get showPreviewLineNumbersDesc;

  /// Section title for performance monitoring options
  ///
  /// In en, this message translates to:
  /// **'Performance Monitoring'**
  String get performanceMonitoring;

  /// Option to show render time
  ///
  /// In en, this message translates to:
  /// **'Show Render Time'**
  String get showRenderTime;

  /// Description for show render time option
  ///
  /// In en, this message translates to:
  /// **'Display how long preview takes to render'**
  String get showRenderTimeDesc;

  /// Option to show FPS counter
  ///
  /// In en, this message translates to:
  /// **'Show FPS Counter'**
  String get showFpsCounter;

  /// Description for show FPS counter option
  ///
  /// In en, this message translates to:
  /// **'Monitor scroll and animation performance'**
  String get showFpsCounterDesc;

  /// Option to show chunk indicators
  ///
  /// In en, this message translates to:
  /// **'Show Chunk Indicators'**
  String get showChunkIndicators;

  /// Description for show chunk indicators option
  ///
  /// In en, this message translates to:
  /// **'Highlight which chunks are loaded in preview'**
  String get showChunkIndicatorsDesc;

  /// Option to show repaint rainbow
  ///
  /// In en, this message translates to:
  /// **'Show Repaint Rainbow'**
  String get showRepaintRainbow;

  /// Description for show repaint rainbow option
  ///
  /// In en, this message translates to:
  /// **'Color widgets when they repaint (Flutter debug)'**
  String get showRepaintRainbowDesc;

  /// Section title for editor debug options
  ///
  /// In en, this message translates to:
  /// **'Editor Debug'**
  String get editorDebug;

  /// Option to show cursor position info
  ///
  /// In en, this message translates to:
  /// **'Show Cursor Info'**
  String get showCursorInfo;

  /// Description for show cursor info option
  ///
  /// In en, this message translates to:
  /// **'Display line, column, and character offset'**
  String get showCursorInfoDesc;

  /// Option to show selection details
  ///
  /// In en, this message translates to:
  /// **'Show Selection Details'**
  String get showSelectionDetails;

  /// Description for show selection details option
  ///
  /// In en, this message translates to:
  /// **'Display start, end positions and length'**
  String get showSelectionDetailsDesc;

  /// Option to log parser events
  ///
  /// In en, this message translates to:
  /// **'Log Parser Events'**
  String get logParserEvents;

  /// Description for log parser events option
  ///
  /// In en, this message translates to:
  /// **'Output parsing info to debug console'**
  String get logParserEventsDesc;

  /// Section title for storage data options
  ///
  /// In en, this message translates to:
  /// **'Storage / Data'**
  String get storageData;

  /// Option to show note size
  ///
  /// In en, this message translates to:
  /// **'Show Note Size'**
  String get showNoteSize;

  /// Description for show note size option
  ///
  /// In en, this message translates to:
  /// **'Display content size in bytes'**
  String get showNoteSizeDesc;

  /// Option to show database stats
  ///
  /// In en, this message translates to:
  /// **'Show Database Stats'**
  String get showDatabaseStats;

  /// Description for show database stats option
  ///
  /// In en, this message translates to:
  /// **'Query count and cache information'**
  String get showDatabaseStatsDesc;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'ro'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'ro':
      return AppLocalizationsRo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
