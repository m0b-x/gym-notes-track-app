# Gym Notes - Copilot Context

## App Description
Gym Notes is a mobile note-taking app designed for gym/workout tracking. It features:
- **Folders**: Organize notes into folders with nested subfolders
- **Rich Markdown Notes**: Full markdown support with custom shortcuts toolbar
- **Virtual Scrolling**: Efficient editing of very large notes (10k+ lines)
- **Auto-save**: Debounced saves to prevent data loss
- **Offline-first**: SQLite with CRDT for future sync support
- **Search**: Full-text search across all notes with FTS5

## Current Work / TODO
- **VirtualScrollingEditor tap handling**: Need to improve cursor positioning when tapping outside text (left edge → start of line, right edge → end of line)
- **Scroll position**: Auto-scroll follows cursor when typing at bottom
- **Markdown shortcuts**: Work in both regular and virtual scrolling modes

## Rules
- NO code comments
- NO markdown files added
- NO tests unless asked
- USE AppLocalizations for ALL user text
- USE latest Flutter/Dart standards

## Stack
flutter_bloc, drift, sqlite3_flutter_libs, path_provider, flutter_markdown_plus, uuid, equatable, flutter_localizations (EN/DE), get_it

## Architecture
```
BLoC → Service → Repository (cached + reactive) → DAO → Database (isolate)
```

## Structure
```
lib/
├── bloc/optimized_folder/    # FolderBloc, events, sealed states
├── bloc/optimized_note/      # NoteBloc, events, sealed states
├── core/
│   ├── di/injection.dart     # get_it DI setup
│   └── types/result.dart     # Sealed Result<T> type
├── constants/
│   ├── app_constants.dart    # Centralized constants
│   └── search_constants.dart # Diacritics map
├── database/                 # Drift database, DAOs, CRDT
│   ├── database.dart         # AppDatabase singleton (background isolate)
│   ├── crdt/hlc.dart         # HybridLogicalClock, HlcTimestamp
│   ├── tables/               # Drift table definitions
│   └── daos/                 # Data Access Objects
├── repositories/             # Cached + reactive data layer
│   ├── note_repository.dart  # NoteRepository with streams
│   └── folder_repository.dart
├── models/                   # Folder, Note, NoteMetadata, CustomMarkdownShortcut
├── services/                 # FolderStorage, NoteStorage, Search, AutoSave, Migration
├── pages/                    # FolderContentPage, NoteEditorPage, SearchPage, MarkdownSettingsPage
├── widgets/                  # MarkdownToolbar, InfiniteScrollList, VirtualScrollingEditor
├── l10n/                     # app_en.arb, app_de.arb
├── config/                   # default_markdown_shortcuts, available_icons
├── handlers/                 # date/default/header_shortcut_handler
├── utils/                    # compression, text_history, bloc_helpers
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

// FolderRepository  
final folderRepo = getIt<FolderRepository>();
await folderRepo.getFolderById(id);                // Cached
await folderRepo.createFolder(name: n);            // Emits FolderChange
folderRepo.folderChanges.listen((change) { ... }); // Reactive stream

// Change events
enum NoteChangeType { created, updated, deleted }
class NoteChange { type, noteId, folderId?, note? }
enum FolderChangeType { created, updated, deleted }
class FolderChange { type, folderId, parentId?, folder? }
```

## Database (Drift + CRDT)

### Tables with CRDT Fields
All tables include: `hlcTimestamp`, `deviceId`, `version`, `isDeleted`, `deletedAt?`

| Table         | Fields                                                                                                    |
| ------------- | --------------------------------------------------------------------------------------------------------- |
| Folders       | id, name, parentId?, createdAt, updatedAt + CRDT fields                                                   |
| Notes         | id, folderId, title, preview, contentLength, chunkCount, isCompressed, createdAt, updatedAt + CRDT fields |
| ContentChunks | id, noteId, chunkIndex, content, isCompressed + CRDT fields                                               |
| SyncMetadata  | key, value, updatedAt                                                                                     |
| UserSettings  | key (PK), value, updatedAt (for markdown shortcuts, etc.)                                                 |

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
db.folderDao.softDeleteFolderWithDescendants(folderId);
db.folderDao.mergeFolder(remoteFolder);  // CRDT merge

// Note operations
db.noteDao.createNote(folderId: id, title: 'Day 1', preview: '...', contentLength: 500, chunkCount: 1);
db.noteDao.getNotesPaginated(folderId: id, limit: 20, offset: 0, sortField: NoteSortField.updatedAt, ascending: false);
db.noteDao.searchNotes(query, folderId: id);
db.noteDao.fullTextSearch(query);  // FTS5
db.noteDao.softDeleteNote(noteId);
db.noteDao.mergeNote(remoteNote);  // CRDT merge

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
AppConstants.virtualScrollingThreshold // 5000

// Timing
AppConstants.autoSaveInterval          // 30s
AppConstants.autoSaveDelay             // 5s
AppConstants.debounceDelay             // 500ms
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
|                                                            | LoadNoteContent(noteId)                                  |
|                                                            | SearchNotes(query, folderId?)                            |
|                                                            | QuickSearchNotes(query, folderId?)                       |
|                                                            | ClearSearch                                              |

## Sort Enums
- **NotesSortOrder**: updatedDesc, updatedAsc, createdDesc, createdAsc, titleAsc, titleDesc
- **FoldersSortOrder**: nameAsc, nameDesc, createdAsc, createdDesc
- **NoteSortField** (DAO): title, createdAt, updatedAt
- **FolderSortField** (DAO): name, createdAt, updatedAt

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
- **MigrationService**: One-time SharedPrefs → SQLite migration
- **AutoSaveService**: 5s debounced saves
- **TextHistoryObserver**: undo/redo tracking

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
