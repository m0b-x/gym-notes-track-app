# Gym Notes - Copilot Context

## App Description
Gym Notes is a mobile note-taking app designed for gym/workout tracking. It features:
- **Folders**: Organize notes into folders with nested subfolders + manual reordering
- **Rich Markdown Notes**: Full markdown support with custom shortcuts toolbar (reorderable)
- **Auto-save**: Debounced saves to prevent data loss (5s debounce + 30s interval)
- **Offline-first**: SQLite with CRDT for future sync support
- **Search**: Full-text search across all notes with FTS5 + in-note search/replace
- **Multi-database**: Create/switch between multiple databases
- **Localization**: English, German, Romanian

## Current Work / TODO
- **Scroll position**: Auto-scroll follows cursor when typing at bottom

## Rules
- NO code comments
- NO markdown files added
- NO tests unless asked
- USE AppLocalizations for ALL user text
- USE latest Flutter/Dart standards
- USE modern designs only

## Stack
flutter_bloc, drift, sqlite3_flutter_libs, path_provider, flutter_markdown_plus, uuid, equatable, flutter_localizations (EN/DE/RO), get_it, share_plus, shared_preferences, stream_transform, re_editor, file_picker

## Architecture
```
BLoC → Service → Repository (cached + reactive) → DAO → Database (isolate)
```

## Structure
```
lib/
├── bloc/optimized_folder/    # FolderBloc, events, sealed states
├── bloc/optimized_note/      # NoteBloc, events, sealed states
├── bloc/app_settings/        # AppSettingsBloc (theme, locale)
├── core/
│   ├── di/injection.dart     # get_it DI setup
│   └── types/result.dart     # Sealed Result<T> type
├── constants/
│   ├── app_constants.dart    # Centralized constants
│   ├── search_constants.dart # Diacritics map
│   ├── settings_keys.dart    # Settings keys for UserSettingsDao
│   ├── app_colors.dart       # Color constants
│   ├── app_spacing.dart      # Spacing constants
│   ├── app_text_styles.dart  # Text style constants
│   ├── font_constants.dart   # Font constants
│   ├── json_keys.dart        # JSON serialization keys
│   └── markdown_constants.dart # Markdown styling constants
├── database/                 # Drift database, DAOs, CRDT
│   ├── database.dart         # AppDatabase singleton (background isolate)
│   ├── crdt/hlc.dart         # HybridLogicalClock, HlcTimestamp
│   ├── tables/               # Drift table definitions
│   ├── daos/                 # Data Access Objects
│   └── migrations/           # Schema versions, migrations, indexes
├── repositories/             # Cached + reactive data layer
│   ├── note_repository.dart  # NoteRepository with streams
│   └── folder_repository.dart
├── models/                   # Folder, Note, NoteMetadata, CustomMarkdownShortcut, NoteIndexData
├── services/                 # FolderStorage, NoteStorage, Search, AutoSave, Loading, Settings, DatabaseManager, LegacyNoteSearch, BackupService
├── pages/                    # OptimizedFolderContentPage, OptimizedNoteEditorPage, SearchPage, MarkdownSettingsPage, DatabaseSettingsPage, ControlsSettingsPage, OnboardingPage
├── widgets/                  # MarkdownToolbar, InfiniteScrollList, AppDrawer, UnifiedAppBars (FolderAppBar, NoteAppBar, SettingsAppBar, SearchAppBar), InteractiveMarkdown, NoteSearchBar, ScrollProgressIndicator, IconPickerDialog, ShortcutEditorDialog, etc.
├── l10n/                     # app_en.arb, app_de.arb, app_ro.arb
├── config/                   # default_markdown_shortcuts, available_icons
├── handlers/                 # date/default/header_shortcut_handler
├── utils/                    # compression, text_history, bloc_helpers, lru_cache, legacy_note_search_controller, re_editor_search_controller, markdown_settings_utils, scroll_position_sync, icon_utils, dialog_helpers, custom_snackbar, isolate_worker, text_position_utils, markdown_list_utils
├── factories/                # shortcut_handler_factory
└── main.dart
```

## Dependency Injection (get_it)
```dart
// Setup (in main.dart)
await configureDependencies();

// Access
final noteRepo = getIt<NoteRepository>();
final noteBloc = getIt<OptimizedNoteBloc>();

// Registration order: Database → Repositories → Services → BLoCs
```

## Sealed Result Type
```dart
// Type-safe error handling
sealed class Result<T> { }
final class Success<T> extends Result<T> { final T data; }
final class Failure<T> extends Result<T> { final AppError error; }

// Usage with pattern matching
final result = await someOperation();
switch (result) {
  case Success(:final data):
    print('Got: $data');
  case Failure(:final error):
    print('Error: ${error.message}');
}

// Convenience methods
result.dataOrNull;
result.fold(onSuccess: (d) => ..., onFailure: (e) => ...);
result.map((data) => transform(data));
```

## Sealed Error Types
```dart
sealed class AppError { final String message; }
final class DatabaseError extends AppError { }
final class NotFoundError extends AppError { final String entityType; }
final class ValidationError extends AppError { final Map<String, String>? fieldErrors; }
final class NetworkError extends AppError { final int? statusCode; }
final class CacheError extends AppError { }
final class UnknownError extends AppError { }
```

## Repositories (Cached + Reactive)
```dart
// NoteRepository
final noteRepo = getIt<NoteRepository>();
await noteRepo.getNoteById(id);                    // Cached
await noteRepo.getNotesByFolder(folderId);         // Cached
await noteRepo.createNote(...);                    // Emits NoteChange
noteRepo.noteChanges.listen((change) { ... });     // Reactive stream
noteRepo.noteChangesForFolder(folderId);           // Filtered stream
noteRepo.watchNotesByFolder(folderId);             // Drift watch query (auto-updates)
noteRepo.watchNoteById(id);                        // Watch single note

// FolderRepository  
final folderRepo = getIt<FolderRepository>();
await folderRepo.getFolderById(id);                // Cached
await folderRepo.createFolder(name: n);            // Emits FolderChange
folderRepo.folderChanges.listen((change) { ... }); // Reactive stream
folderRepo.watchFoldersByParent(parentId);         // Drift watch query (auto-updates)
folderRepo.watchFolderById(id);                    // Watch single folder

// Change events
enum NoteChangeType { created, updated, deleted }
class NoteChange { type, noteId, folderId?, note? }
enum FolderChangeType { created, updated, deleted }
class FolderChange { type, folderId, parentId?, folder? }
```

## Database (Drift + CRDT)

### Tables with CRDT Fields
All tables include: `hlcTimestamp`, `deviceId`, `version`, `isDeleted`, `deletedAt?`

| Table         | Fields                                                                                                              |
| ------------- | ------------------------------------------------------------------------------------------------------------------- |
| Folders       | id, name, parentId?, position, createdAt, updatedAt, noteSortOrder?, subfolderSortOrder? + CRDT fields              |
| Notes         | id, folderId, title, preview, contentLength, chunkCount, isCompressed, position, createdAt, updatedAt + CRDT fields |
| ContentChunks | id, noteId, chunkIndex, content, isCompressed + CRDT fields                                                         |
| SyncMetadata  | key, value, updatedAt (no CRDT)                                                                                     |
| UserSettings  | key (PK), value, updatedAt (for markdown shortcuts, etc.) (no CRDT)                                                 |

### Storage Architecture
| Data               | Storage               | Notes                      |
| ------------------ | --------------------- | -------------------------- |
| Folders            | SQLite                | CRDT sync-ready            |
| Notes              | SQLite                | CRDT sync-ready            |
| Content            | SQLite (chunked)      | Compressed, CRDT           |
| Markdown shortcuts | SQLite (UserSettings) | Structured user data       |
| Recent searches    | SharedPreferences     | Device-local UI state only |

### DAOs
```dart
// Get database instance
final db = await AppDatabase.getInstance();

// Folder operations
db.folderDao.createFolder(name: 'Workout', parentId: null);
db.folderDao.getFoldersPaginated(parentId: null, limit: 20, offset: 0, sortField: FolderSortField.name, ascending: true);
db.folderDao.softDeleteFolderWithDescendants(folderId);  // Uses transaction
db.folderDao.reorderFolders(parentId: null, orderedIds: ids);  // Uses transaction
db.folderDao.mergeFolder(remoteFolder);  // CRDT merge

// Note operations
db.noteDao.createNote(folderId: id, title: 'Day 1', preview: '...', contentLength: 500, chunkCount: 1);
db.noteDao.getNotesPaginated(folderId: id, limit: 20, offset: 0, sortField: NoteSortField.updatedAt, ascending: false);
db.noteDao.searchNotes(query, folderId: id);
db.noteDao.fullTextSearch(query);  // FTS5
db.noteDao.softDeleteNoteWithChunks(noteId);  // Uses transaction (note + chunks)
db.noteDao.reorderNotes(folderId: id, orderedIds: ids);  // Uses transaction
db.noteDao.mergeNote(remoteNote);  // CRDT merge

// Watch queries (reactive streams from Drift)
db.noteDao.watchNotesByFolder(folderId);   // Stream<List<Note>>
db.noteDao.watchNoteById(id);              // Stream<Note?>
db.folderDao.watchFoldersByParent(parentId);  // Stream<List<Folder>>
db.folderDao.watchFolderById(id);          // Stream<Folder?>

// Content chunk operations
db.contentChunkDao.saveContent(noteId: id, content: text);  // Auto-chunks & compresses
db.contentChunkDao.loadContent(noteId);
db.contentChunkDao.mergeChunk(remoteChunk);  // CRDT merge

// Sync metadata
db.syncDao.getLastSyncTimestamp();
db.syncDao.setLastSyncTimestamp(hlc);

// User settings (markdown shortcuts, etc.)
db.userSettingsDao.getValue('markdown_shortcuts');
db.userSettingsDao.setValue('markdown_shortcuts', jsonEncode(shortcuts));
```

### HLC (Hybrid Logical Clock)
```dart
// Generate HLC timestamp for new/updated records
final hlc = db.generateHlc();  // Returns "00018d5a2b3c:0001:device-uuid"

// Parse and compare HLC timestamps
final ts1 = HlcTimestamp.parse(hlcString);
final ts2 = HlcTimestamp.parse(otherHlcString);
if (ts2 > ts1) { /* ts2 is newer */ }

// Update clock when receiving remote changes
db.hlc.receive(remoteTimestamp);
```

## Constants (AppConstants)
```dart
// Pagination
AppConstants.defaultPageSize           // 20

// Cache
AppConstants.maxNoteCacheSize          // 200
AppConstants.maxContentCacheSize       // 50
AppConstants.maxFolderCacheSize        // 100
AppConstants.cacheExpiry               // 5 minutes

// Content
AppConstants.defaultChunkSize          // 10KB
AppConstants.compressionThreshold      // 5KB
AppConstants.previewMaxLength          // 200

// Timing
AppConstants.autoSaveInterval          // 30s
AppConstants.autoSaveDelay             // 5s
AppConstants.debounceDelay             // 500ms

// UI
AppConstants.edgeScrollThreshold       // 80.0
AppConstants.autoScrollSpeed           // 10.0

// Search
AppConstants.maxRecentSearches         // 10
AppConstants.maxSearchMatches          // 1000
SearchCursorBehavior                   // enum: start, end, selection
```

## Database Migrations (DatabaseSchema)
```dart
// Schema version constants
DatabaseSchema.currentVersion               // 5
DatabaseSchema.v1Initial                    // 1
DatabaseSchema.v2UserSettings               // 2
DatabaseSchema.v3ContentChunksIsDeleted     // 3
DatabaseSchema.v4ManualOrdering             // 4
DatabaseSchema.v5FolderSortPreferences      // 5

// Migration classes
DatabaseMigrations(db).runMigrations(m, from, to);
DatabaseIndexes(db).createAllIndexes();
```

## Sealed BLoC States

### OptimizedNoteState (sealed)
```dart
sealed class OptimizedNoteState { }
final class OptimizedNoteInitial extends OptimizedNoteState { }
final class OptimizedNoteLoading extends OptimizedNoteState { String? folderId; }
final class OptimizedNoteLoaded extends OptimizedNoteState { 
  PaginatedNotes paginatedNotes;
  Map<String, String> loadedContent;
  bool isLoadingMore;
  String? folderId;
}
final class OptimizedNoteContentLoaded extends OptimizedNoteState { 
  LazyNote note;
  PaginatedNotes? previousPaginatedNotes;
}
final class OptimizedNoteSearchResults extends OptimizedNoteState { 
  List<SearchResult> results;
  String query;
  bool isSearching;
}
final class OptimizedNoteError extends OptimizedNoteState { 
  String message;
  NoteErrorType errorType;  // notFound, loadFailed, saveFailed, deleteFailed, searchFailed, unknown
}
```

### OptimizedFolderState (sealed)
```dart
sealed class OptimizedFolderState { }
final class OptimizedFolderInitial extends OptimizedFolderState { }
final class OptimizedFolderLoading extends OptimizedFolderState { String? parentId; }
final class OptimizedFolderLoaded extends OptimizedFolderState { 
  PaginatedFolders paginatedFolders;
  bool isLoadingMore;
  String? parentId;
}
final class OptimizedFolderError extends OptimizedFolderState { 
  String message;
  FolderErrorType errorType;  // notFound, loadFailed, createFailed, updateFailed, deleteFailed, unknown
}
```

## BLoC Events

| OptimizedFolderBloc                                        | OptimizedNoteBloc                                        |
| ---------------------------------------------------------- | -------------------------------------------------------- |
| LoadFoldersPaginated(parentId?, page, pageSize, sortOrder) | LoadNotesPaginated(folderId?, page, pageSize, sortOrder) |
| LoadMoreFolders(parentId?)                                 | LoadMoreNotes(folderId?)                                 |
| CreateOptimizedFolder(name, parentId?)                     | CreateOptimizedNote(folderId, title, content)            |
| UpdateOptimizedFolder(folderId, name?)                     | UpdateOptimizedNote(noteId, title?, content?)            |
| DeleteOptimizedFolder(folderId, parentId?)                 | DeleteOptimizedNote(noteId)                              |
| RefreshFolders(parentId?)                                  | RefreshNotes(folderId?)                                  |
| ReorderFolders(parentId?, orderedIds)                      | ReorderNotes(folderId, orderedIds)                       |
|                                                            | LoadNoteContent(noteId)                                  |
|                                                            | SearchNotes(query, folderId?)                            |
|                                                            | QuickSearchNotes(query, folderId?)                       |
|                                                            | ClearSearch                                              |

## Sort Enums
- **NotesSortOrder**: updatedDesc, updatedAsc, createdDesc, createdAsc, titleAsc, titleDesc, positionAsc, positionDesc
- **FoldersSortOrder**: nameAsc, nameDesc, createdAsc, createdDesc, positionAsc, positionDesc
- **NoteSortField** (DAO): title, createdAt, updatedAt, position
- **FolderSortField** (DAO): name, createdAt, updatedAt, position

## Code Patterns

```dart
// Localization
AppLocalizations.of(context)!.keyName

// BLoC with sealed states (exhaustive switch)
switch (state) {
  case OptimizedNoteInitial():
    return LoadingWidget();
  case OptimizedNoteLoading(:final folderId):
    return LoadingWidget();
  case OptimizedNoteLoaded(:final paginatedNotes):
    return NotesList(notes: paginatedNotes.notes);
  case OptimizedNoteContentLoaded(:final note):
    return NoteEditor(note: note);
  case OptimizedNoteSearchResults(:final results):
    return SearchResults(results: results);
  case OptimizedNoteError(:final message, :final errorType):
    return ErrorWidget(message: message);
}

// BLoC dispatch
context.read<OptimizedNoteBloc>().add(CreateOptimizedNote(folderId: id, title: t, content: c));
context.read<OptimizedNoteBloc>().add(LoadNotesPaginated(folderId: id, sortOrder: NotesSortOrder.updatedDesc));

// Reactive updates
getIt<NoteRepository>().noteChanges.listen((change) {
  switch (change.type) {
    case NoteChangeType.created:
      // Refresh list
    case NoteChangeType.updated:
      // Update item
    case NoteChangeType.deleted:
      // Remove item
  }
});
```

## Key Classes
- **AppDatabase**: Drift database singleton with HLC clock (background isolate)
- **DatabaseSchema**: Schema version constants (currentVersion=5, v1-v5)
- **DatabaseManager**: Manages multiple databases (create, switch, delete, rename)
- **DatabaseMigrations**: Migration step runner for schema upgrades
- **DatabaseIndexes**: Index and FTS table creation
- **NoteRepository**: Cached note access with reactive streams
- **FolderRepository**: Cached folder access with reactive streams
- **Result<T>**: Sealed type for Success/Failure
- **AppError**: Sealed error hierarchy
- **HybridLogicalClock**: CRDT clock for causality ordering
- **HlcTimestamp**: Comparable timestamp (wallTime:counter:nodeId)
- **LazyNote**: metadata + content (from loadNoteWithContent)
- **PaginatedNotes**: notes list + pagination info (hasMore, currentPage, totalCount)
- **PaginatedFolders**: folders list + pagination info
- **SearchResult**: metadata + matches + relevanceScore
- **SearchMatch**: start/end indices + matchType (title/content)
- **CheckboxToggleInfo**: start/end indices + replacement text for checkbox toggling
- **LoadingService**: Global loading state for database operations
- **AutoSaveService**: 5s debounced saves + 30s interval
- **TextHistoryObserver**: undo/redo tracking
- **ReEditorSearchController**: In-note search/replace with regex support (wraps re_editor's CodeFindController)
- **NoteSearchController**: Legacy in-note search/replace (in legacy_note_search_controller.dart)
- **FolderSearchService**: Cross-note full-text search with indexing
- **SettingsService**: User preferences (swipe gestures, haptic feedback, auto-save, preview, theme, locale)
- **CustomMarkdownShortcut**: User-configurable markdown toolbar shortcuts
- **BackupService**: Full data export/import for backup and restore

## Onboarding & Backup
```dart
// First launch detection (in main.dart)
final settings = await SettingsService.getInstance();
final completed = await settings.isOnboardingCompleted();
// Shows OnboardingPage if not completed

// Export all data as backup
final backupService = await BackupService.getInstance();
await backupService.shareBackup();  // Share backup JSON file

// Validate backup before import
final validation = await backupService.validateBackup(jsonString);
if (validation.isValid) {
  print('Folders: ${validation.folderCount}, Notes: ${validation.noteCount}');
}

// Import backup
final result = await backupService.importFromJson(jsonString);
if (result.success) {
  print('Imported ${result.foldersImported} folders, ${result.notesImported} notes');
}

// Check if user has existing data
final hasData = await backupService.hasExistingData();
```

## Sync (Future)
```dart
// Get changes since last sync
final changedFolders = await db.folderDao.getFoldersSince(lastHlc);
final changedNotes = await db.noteDao.getNotesSince(lastHlc);
final changedChunks = await db.contentChunkDao.getChunksSince(lastHlc);

// Merge remote changes (last-write-wins via HLC)
await db.folderDao.mergeFolder(remoteFolder);
await db.noteDao.mergeNote(remoteNote);
await db.contentChunkDao.mergeChunk(remoteChunk);

// Update sync cursor
await db.syncDao.setLastSyncTimestamp(newHlc);
```

## Multi-Database Management
```dart
// Get database manager
final dbManager = await DatabaseManager.getInstance();

// List available databases
final databases = await dbManager.listDatabases();

// Create new database
await dbManager.createDatabase('workout-logs');

// Switch to different database
await dbManager.switchToDatabase('workout-logs');
context.read<OptimizedFolderBloc>().add(RefreshFolders());
context.read<OptimizedNoteBloc>().add(RefreshNotes());

// Rename database
await dbManager.renameDatabase('old-name', 'new-name');

// Delete database
await dbManager.deleteDatabase('old-db');

// Get active database name
final activeName = dbManager.getActiveDatabaseName();
```

## User Settings (SettingsService)
```dart
final settings = await SettingsService.getInstance();

// Gesture controls
settings.folderSwipeEnabled;  // Swipe to open drawer on folder page
settings.noteSwipeEnabled;    // Swipe to open drawer on note editor
await settings.setFolderSwipeEnabled(true);

// Behavior
settings.confirmDelete;       // Show confirmation before deleting
settings.autoSaveEnabled;     // Enable/disable auto-save
settings.autoSaveInterval;    // Auto-save interval in seconds
await settings.setConfirmDelete(true);

// UI preferences
settings.showNotePreview;     // Show note preview in lists
settings.hapticFeedback;      // Haptic feedback on interactions
await settings.setShowNotePreview(true);
```

## In-Note Search (ReEditorSearchController)
```dart
final searchController = ReEditorSearchController();

// Initialize with editing controller
searchController.initialize(editingController);

// Set find controller from CodeEditor's findBuilder
searchController.setFindController(findController);

// Perform search with options
searchController.updateQuery('text to find');
searchController.setCaseSensitive(true);
searchController.setUseRegex(true);
searchController.setWholeWord(true);

// Navigate matches
searchController.nextMatch();
searchController.previousMatch();
searchController.currentMatchIndex; // 1-based
searchController.matchCount;

// Replace functionality (returns sealed ReplaceResultState)
final result = searchController.replaceCurrent('replacement');
switch (result) {
  case ReplaceSuccessState(:final newContent, :final cursorPosition):
    // Apply newContent
  case ReplaceFailureState(:final reason):
    // Handle failure
}
searchController.replaceAll('replacement');

// State
if (searchController.isSearching) {
  // Show search UI
}
```

## Markdown Shortcuts
```dart
// Load shortcuts
final shortcuts = await MarkdownSettingsUtils.loadShortcuts();

// Shortcuts include:
// - Default: bold, italic, strikethrough, code, link, quote, list, header, date
// - Custom: user-created shortcuts with custom icons and text

// Shortcut properties
shortcut.id;              // Unique identifier
shortcut.label;           // Display text
shortcut.beforeText;      // Text before selection
shortcut.afterText;       // Text after selection
shortcut.insertType;      // 'default', 'header', 'date'
shortcut.isVisible;       // Show in toolbar
shortcut.isDefault;       // Can't be deleted

// Toolbar features:
// - Reorderable (drag to rearrange)
// - Visibility toggle per shortcut
// - Custom date formats (configurable)
// - Header levels (H1-H6)
```

## Widget Highlights
```dart
// MarkdownToolbar - customizable toolbar
MarkdownToolbar(
  shortcuts: shortcuts,
  isPreviewMode: false,
  canUndo: true,
  canRedo: false,
  previewFontSize: 16.0,
  onUndo: () => {},
  onRedo: () => {},
  onDecreaseFontSize: () => {},
  onIncreaseFontSize: () => {},
  onSettings: () => {},
  onShortcutPressed: (shortcut) => _handleShortcut(shortcut),
  onReorderComplete: (reordered) => _saveOrder(reordered),
  onShare: () => {},
  showSettings: true,
  showBackground: true,
  showReorder: true,
);

// InteractiveMarkdown - markdown preview with checkbox support
InteractiveMarkdown(
  data: markdownContent,
  selectable: true,
  onCheckboxToggle: (CheckboxToggleInfo info) => {},
  styleSheet: MarkdownStyleSheet(...),
  selectedLine: 5,
  onLineTap: (lineNumber) => {},
);

// FolderAppBar - for folder navigation pages
FolderAppBar(
  title: 'Folder Name',
  isRootPage: true,          // Shows menu icon, false shows back arrow
  actions: [...],
  onMenuPressed: () => {},   // Optional custom handler
  onBackPressed: () => {},   // Optional custom handler
);

// NoteAppBar - for note editor page
NoteAppBar(
  title: 'Note Title',
  hasChanges: true,          // Shows unsaved indicator dot
  actions: [...],
  onBackPressed: () => {},
  onTitleTap: () => {},      // For editing title
);

// SettingsAppBar - for settings pages (drawer gradient style)
SettingsAppBar(
  title: 'Settings',
  actions: [...],
  showMenuButton: true,      // Shows menu button to open drawer (default: true)
);

// SearchAppBar - for search page with text field
SearchAppBar(
  controller: searchController,
  focusNode: focusNode,
  hintText: 'Search...',
  onChanged: (query) => {},
  onSubmitted: (query) => {},
  onClear: () => {},
);

// InfiniteScrollList - paginated scrolling with loading
InfiniteScrollList<Item>(
  items: items,
  hasMore: true,
  isLoadingMore: false,
  onLoadMore: () => loadMore(),
  itemBuilder: (context, item, index) => ItemWidget(item),
  emptyWidget: EmptyWidget(),
  loadingWidget: LoadingWidget(),
  loadMoreThreshold: 200.0,
  padding: EdgeInsets.all(8),
  controller: scrollController,
  shrinkWrap: false,
);
```