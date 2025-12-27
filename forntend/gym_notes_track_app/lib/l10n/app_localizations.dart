import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

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
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Gym Notes'**
  String get appTitle;

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
  /// **'Start writing...'**
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

  /// Settings button tooltip
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
      <String>['de', 'en'].contains(locale.languageCode);

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
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
