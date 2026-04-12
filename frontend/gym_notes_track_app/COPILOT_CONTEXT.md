# Gym Notes - Copilot Context

## App Description
Gym Notes is a mobile note-taking app designed for gym/workout tracking. It features:
- **Folders**: Organize notes into folders with nested subfolders + manual reordering + per-folder sort preferences
- **Rich Markdown Notes**: Full markdown support with custom shortcuts toolbar (reorderable, multiple profiles, per-note bar assignments)
- **Auto-save**: Fingerprint-based change detection (hash + length) with debounced saves (5s) + periodic interval (30s) + retry with exponential backoff
- **Offline-first**: SQLite with CRDT (Hybrid Logical Clock) for future sync support
- **Search**: Full-text search across all notes with FTS5 + in-note search/replace with regex support + inverted index with isolate-based building
- **Multi-database**: Create/switch/rename/delete multiple databases (DatabaseManager via SharedPreferences for active DB name)
- **Localization**: English, German, Romanian (ARB files → flutter gen-l10n)
- **Backup/Restore**: Full JSON export/import with v2 format (includes bar profiles + per-note assignments + counter data with pin/position extras)
- **Developer Options**: Hidden debug menu (swipe gym icon to unlock) with markdown block coloring, FPS counter, cursor info, database stats, repaint rainbow, etc.
- **Note Position Persistence**: Saves and restores editor cursor position + preview scroll offset per note
- **Markdown Preview**: Line-based chunked rendering with LRU caching, search highlighting, checkbox toggling, and source-line mapping for editor↔preview sync
- **Custom Scroll Progress Indicator**: Touch-friendly scrollbar with smoothing, stabilization, edge snapping, and adaptive animations
- **Counters**: Global and per-note counters with pinning, reordering, in-memory caching, and 300ms debounced DB writes

## Current Work / TODO
- **Scroll position**: Auto-scroll follows cursor when typing at bottom

## Rules
- NO code comments
- NO markdown files added
- NO tests unless asked
- USE AppLocalizations for ALL user text
- USE latest Flutter/Dart standards
- USE modern designs only

## Build & Validation Commands
```bash
# Code generation (after changing Drift tables/DAOs)
flutter pub run build_runner build

# Localization (after changing ARB files)
flutter gen-l10n

# Static analysis (expect 0 errors, ~12 pre-existing info warnings)
dart analyze lib

# Run app
flutter run
```

## Stack
flutter_bloc ^9.1.1, drift ^2.30.0, sqlite3_flutter_libs ^0.5.32, path_provider ^2.1.5, flutter_markdown_plus ^1.0.6, uuid ^4.5.2, equatable ^2.0.7, flutter_localizations (EN/DE/RO), get_it ^8.0.3, share_plus ^12.0.1, shared_preferences ^2.5.4, stream_transform ^2.1.0, re_editor (local: packages/re_editor), file_picker ^9.2.0, markdown ^7.3.0, scrollable_positioned_list ^0.3.8, intl (any)
SDK: ^3.10.4
Dev: drift_dev ^2.30.0, build_runner ^2.4.15

## Architecture
```
BLoC → Service → Repository (cached + reactive) → DAO → Database (isolate)
```
- **BLoC events/states**: Use `sealed` classes with `final` subclasses
- **Models**: Use `Equatable` with `copyWith`, JSON via `JsonKeys` constants
- **DI**: `get_it` — singletons for DB/repositories/services, factories for BLoCs
- **Reactivity**: `StreamController<ChangeEvent>` in repositories for cross-layer notifications
- **Caching**: LRU caches in repositories (200 notes, 50 content, 100 folders, 5min expiry); in-memory cache with debounced flush in CounterService (300ms)

## Structure
```
lib/
├── main.dart                          # Entry: WidgetsFlutterBinding → configureDependencies → MultiBlocProvider(AppSettings+Folder+Note+MarkdownBar+Counter) → MaterialApp with onboarding check
├── bloc/
│   ├── app_settings/
│   │   └── app_settings_bloc.dart     # Manages locale + themeMode, persists via UserSettingsDao, events: LoadAppSettings/ChangeLocale/ChangeThemeMode
│   ├── optimized_folder/
│   │   ├── optimized_folder_bloc.dart # Handles Load/Create/Update/Delete/Reorder + pagination via FolderStorageService
│   │   ├── optimized_folder_event.dart
│   │   └── optimized_folder_state.dart # Sealed: Initial | Loading | Loaded(PaginatedFolders) | Error(FolderErrorType)
│   ├── optimized_note/
│   │   ├── optimized_note_bloc.dart   # Handles Load/Create/Update/Delete/Search/Reorder + debounced quick search (200ms) via stream_transform
│   │   ├── optimized_note_event.dart
│   │   └── optimized_note_state.dart  # Sealed: Initial | Loading | Loaded(PaginatedNotes) | ContentLoaded(LazyNote) | SearchResults | Created | Error(NoteErrorType)
│   ├── markdown_bar/
│   │   ├── markdown_bar_bloc.dart     # Manages toolbar profiles + per-note bar assignments via MarkdownBarService
│   │   ├── markdown_bar_event.dart    # Load/AddProfile/RenameProfile/DuplicateProfile/DeleteProfile/SetActive/UpdateShortcuts/SetNoteBarAssignment/ResolveBarForNote/SwitchEditingProfile
│   │   └── markdown_bar_state.dart    # Sealed: Initial | Loading | Loaded(profiles, activeProfileId, currentShortcuts) | Error
│   ├── counter/
│   │   ├── counter_bloc.dart          # Manages global & per-note counters via CounterService. Dual value maps: counterValues (page-level) + pickedNoteValues (per-card local picks)
│   │   ├── counter_event.dart         # LoadCounters/AddCounter/UpdateCounter/DeleteCounter/ResetCounter/IncrementCounter/DecrementCounter/SetCounterValue/RefreshCounters/ReorderCounters/LoadCounterForNote/PinCounter
│   │   └── counter_state.dart         # Sealed: Initial | Loading | Loaded(counters, counterValues, loadedNoteId, pickedNoteValues) | Error
│   ├── counter_per_note/
│   │   ├── counter_per_note_bloc.dart # Shows all notes with values for a specific counter. Dependencies: CounterService + NoteRepository (created inline via BlocProvider, not from DI)
│   │   ├── counter_per_note_event.dart # Sealed: Opened/AddNote/RemoveNote/Increment/Decrement/SetValue/Reset/ResetAll/TogglePin/Reorder
│   │   └── counter_per_note_state.dart # NoteValueEntry(note, value, isPinned) helper class. Sealed: Initial | Loading | Loaded(counter, entries) | Error(message)
│   └── note_picker/
│       ├── note_picker_bloc.dart      # Paginated note picker (6 items/page, with search) for note selection dialogs
│       ├── note_picker_event.dart     # Sealed: NotePickerOpened/NotePickerPageChanged/NotePickerQueryChanged
│       └── note_picker_state.dart     # Sealed: Initial | Loading | Loaded(paginatedNotes, query) | Error
├── core/
│   ├── di/injection.dart              # get_it setup: Database(singleton) → Repositories(singleton: NoteRepository, FolderRepository) → Services(singleton: FolderStorage, NoteStorage, FolderSearch, MarkdownBar, Counter) → BLoCs(factory: OptimizedFolder, OptimizedNote, MarkdownBar, Counter)
│   └── types/result.dart              # Sealed Result<T> = Success<T>(data) | Failure<T>(AppError); AppError = Database|NotFound|Validation|Network|Cache|Permission|Unknown
├── constants/
│   ├── app_constants.dart             # Timing (autoSave 30s, debounce 5s/500ms), UI (edgeScroll 80px, autoScroll 10px, toolbar sizing), pagination (20), cache (200/50/100 entries, 5min expiry), content (10KB chunks, 5KB compression threshold), search (10 recent, 1000 max matches), editor (scrollbarPadding 16, previewPreloadLineThreshold 3000, maxBarProfileNameLength 30)
│   ├── app_colors.dart                # Theme-aware utility: folderIcon/noteIcon/fabForeground/fabBackground + static deleteAction/dragHandle
│   ├── app_icon_sizes.dart            # tiny(16)/small(20)/medium(24)/large(40)/extraLarge(48)
│   ├── app_spacing.dart               # xxs(2)..xxl(32), pre-built EdgeInsets (cardPadding, listItemPadding, dialogPadding, buttonPadding, toolbarPadding, snackbarMargin w/ toolbarOffset=70)
│   ├── app_text_styles.dart           # dialogTitle, subtitle(ctx), caption(ctx), label, error, title, body, small
│   ├── font_constants.dart            # defaultFontSize=16, min=10, max=30, step=2, editorFontFamily=null(platform), h1=32..h6=14, UI text sizes
│   ├── json_keys.dart                 # All JSON key constants for serialization (note fields, shortcut fields, date offset, repeat config, counter fields: counterId/counterStartValue/counterStep/counterScope/counterIsPinned)
│   ├── markdown_constants.dart        # contentChangeDeltaThreshold=500, lineHeight=1.5, cacheExtent=500, heading scales h1=2.0..h6=0.875, line scales (normal/empty/hr/code), checkbox/indent/code/border/opacity constants
│   ├── scroll_indicator_constants.dart # visibleWidth=6, touchArea=44, thumb sizing/animation/smoothing/stabilization/edge-snapping/opacity/shadow constants
│   ├── search_constants.dart          # Full diacritics→ASCII map (À→A, ă→a, ß→ss, etc.) for search normalization
│   └── settings_keys.dart             # All UserSettings keys + defaults: onboarding, fonts, locale, theme, date, markdown, controls (swipe/delete/autoSave/preview/stats/haptic), editor (lineNums/wordWrap/cursorLine/autoBreak/previewOnKeyboard/scrollCursor), preview (scrollbar), toolbar (ratio=0.7/split=true/utilityConfig), performance (linesPerChunk=10), notePositionPrefix
├── database/
│   ├── database.dart                  # AppDatabase extends DriftDatabase, singleton per DB name, HLC clock, LazyDatabase in background, LoadingQueryInterceptor, schema version 8
│   ├── database.g.dart                # Generated Drift code
│   ├── loading_interceptor.dart       # QueryInterceptor wrapping all DB ops with LoadingService start/stop for visual feedback
│   ├── crdt/hlc.dart                  # HybridLogicalClock(nodeId) with now()/receive()/update(); HlcTimestamp(wallTime:logicalCounter:nodeId) - hex encoded, Comparable, parse/toString
│   ├── tables/
│   │   ├── folders_table.dart         # id, name(1-255), parentId?, position, createdAt, updatedAt, noteSortOrder?, subfolderSortOrder? + CRDT(hlcTimestamp, deviceId, version, isDeleted, deletedAt?)
│   │   ├── notes_table.dart           # id, folderId, title(0-500), preview, contentLength, chunkCount, isCompressed, position, createdAt, updatedAt + CRDT
│   │   ├── content_chunks_table.dart  # id, noteId, chunkIndex, content, isCompressed + CRDT (no deletedAt)
│   │   ├── counters_table.dart        # id, name, startValue(default 1), step(default 1), scope('global'|'perNote'), position, isPinned(default false), createdAt (no CRDT)
│   │   ├── counter_values_table.dart  # counterId+noteId(composite PK), value, position(default 0), isPinned(default false). noteId='' for global counters
│   │   ├── sync_metadata_table.dart   # key(PK), value, updatedAt (no CRDT)
│   │   └── user_settings_table.dart   # key(PK), value, updatedAt (DataClassName: UserSetting, no CRDT)
│   ├── daos/
│   │   ├── content_chunk_dao.dart     # loadContent(reassemble+decompress), saveContent(diff-based: compare old chunks by hash, batch insert/update/delete changed only), softDelete/hardDelete, mergeChunk(CRDT), getContentStats
│   │   ├── folder_dao.dart            # CRUD + paginated + soft/hard delete + cascade (softDeleteFolderWithDescendants), reorder (transaction), sort preferences, watch queries, merge(CRDT), getNoteCountWithDescendants
│   │   ├── note_dao.dart              # CRUD + paginated + FTS5 index management (_addToFtsIndex/_updateFtsIndex/_removeFromFtsIndex), searchNotes(LIKE), fullTextSearch(FTS5 MATCH), softDelete w/ chunks (transaction), reorder, watch queries, merge(CRDT), deleteNotesInFolder, getNotesByIds
│   │   ├── counter_dao.dart           # getAllCounters(ordered by isPinned DESC, position ASC), insertCounter, updateCounter, deleteCounter + cascade values, upsertValue, getValue, getValuesForNote, getAllValues, getValuesForCounterOrdered, setCounterPinned, setNoteValuePinned, updatePositions (transaction), updateNoteValuePositions, deleteValue
│   │   ├── sync_dao.dart              # getLastSyncTimestamp/setLastSyncTimestamp
│   │   └── user_settings_dao.dart     # getValue/setValue/deleteValue/getAllSettings + watch queries
│   └── migrations/
│       ├── database_schema.dart       # currentVersion=8, v1Initial..v8CounterPinAndOrder
│       ├── database_migrations.dart   # v1→v2: user_settings, v2→v3: content_chunks.isDeleted, v3→v4: folders+notes.position, v4→v5: folders sort prefs, v5→v6: counters+counter_values tables (raw SQL), v6→v7: counters.createdAt fix, v7→v8: counter_values.isPinned+position + counters.isPinned (ALTER TABLE)
│       ├── database_indexes.dart      # FTS5 table creation (notes_fts) + B-tree indexes on folderId/parentId/updatedAt/position/isDeleted combinations
│       └── migrations.dart            # Barrel export
├── repositories/
│   ├── repositories.dart              # Barrel export
│   ├── note_repository.dart           # LRU cached (maxNote=200, maxContent=50), reactive (StreamController<NoteChange>), wraps NoteDao+ContentChunkDao, provides: paginated, search, FTS5, watch, reorder, create/update/delete with content, getNotesByIds, noteToMetadata
│   └── folder_repository.dart         # LRU cached (maxFolder=100), reactive (StreamController<FolderChange>), wraps FolderDao, provides: paginated, hierarchy, watch, reorder, sort prefs, cascade delete with note count
├── models/
│   ├── counter.dart                   # Equatable: id, name, startValue, step, scope(global|perNote), isPinned, createdAt + JSON (via JsonKeys) + copyWith
│   ├── custom_markdown_shortcut.dart  # Equatable: id, label, iconCodePoint, iconFontFamily, beforeText, afterText, isDefault, isVisible, insertType('wrap'|'header'|'date'), dateFormat?, dateOffset?(days/months/years), repeatConfig?(count/incrementDate/separator/before/afterRepeatText)
│   ├── folder.dart                    # Equatable: id, name, parentId?, createdAt, noteSortOrder?, subfolderSortOrder? + JSON + copyWith
│   ├── note.dart                      # Equatable: id, folderId, title, content, createdAt, updatedAt + JSON + copyWith
│   ├── note_metadata.dart             # NoteMetadata (without content, has preview/contentLength/chunkCount/isCompressed), LazyNote (metadata + optional content), PaginatedNotes (notes + currentPage/totalPages/totalCount/hasMore)
│   ├── isolate_data.dart              # NoteIndexData(id, title, content) for isolate search indexing
│   ├── markdown_bar_profile.dart      # Equatable: id, name, isDefault, shortcuts[], updatedAt; defaultProfileId='default'; encodeList/decodeList for batch JSON
│   ├── utility_button_config.dart     # UtilityButtonId (static const IDs + defaultOrder: undo/redo/paste/decreaseFont/increaseFont/share/switchBar/scrollToTop/scrollToBottom/reorder/settings + locked={settings}), UtilityButtonConfig (id+isVisible, Equatable, encode/decode with merge logic for new buttons)
│   ├── utility_button_definition.dart # Registry: UtilityButtonDefinition(id, icon, labelResolver(AppLocalizations), isLocked); static all[] + _byId map + getById(). Single source of truth for toolbar icon/label/lock. Adding a button: 1) add ID to UtilityButtonId 2) add entry here
│   └── dev_options.dart               # ChangeNotifier singleton: developerModeUnlocked, colorMarkdownBlocks, showBlockBoundaries, showWhitespace, showPreviewLineNumbers, showRenderTime, showFpsCounter, showChunkIndicators, showRepaintRainbow, showCursorInfo, showSelectionDetails, logParserEvents, showNoteSize, showDatabaseStats + loadFromMap/toMap for persistence
├── services/
│   ├── auto_save_service.dart         # Lazy content providers (avoid string copy per keystroke), fingerprint comparison (hash+length), debounce+interval timers, SaveStatus enum, retry with exponential backoff (2s/4s/8s, max 3), forceSave/flushAll for lifecycle
│   ├── backup_service.dart            # Export v2 format (folders+notes+content+shortcuts+settings+barProfiles+activeBar+noteBarAssignments+counterData), import with restore, validate before import, share via share_plus
│   ├── counter_service.dart           # Singleton (CounterService.getInstance()). In-memory cache (_counters list, _globalValues map, _noteValuesCache map). 300ms debounced flush. Methods: add/update/delete counter, get/set/increment/decrement global+note values, toggleCounterPin, toggleNoteValuePin, reorderCounters, reorderNoteValues, getOrderedNoteValuesForCounter, exportData/importData (with noteValueExtras for pin/position). flush() forces pending writes.
│   ├── database_manager.dart          # Multi-DB management via SharedPreferences('active_database'), list/create/rename/delete .db files + WAL/SHM cleanup, name validation (alphanum/underscore/hyphen, max 50)
│   ├── dev_options_service.dart       # Persists DevOptions to/from UserSettings as JSON
│   ├── folder_search_service.dart     # SearchIndex (inverted index with binary search prefix matching), FolderSearchService (build index via compute() isolate for >50 notes, search/quickSearch with diacritics normalization + relevance scoring, recent searches in SharedPreferences)
│   ├── folder_storage_service.dart    # FoldersSortOrder enum, PaginatedFolders, wraps FolderRepository with model conversion (DB Folder → model.Folder)
│   ├── loading_service.dart           # Singleton with ValueNotifier<bool>, nested operation counter (startLoading/stopLoading), withLoading<T>() wrapper
│   ├── markdown_bar_service.dart      # ChangeNotifier singleton: manages multiple MarkdownBarProfiles, per-note assignments (note_bar_<noteId>), CRUD + active profile + resolve per note, legacy migration from single 'markdown_shortcuts' key
│   ├── note_position_service.dart     # Persists NotePositionData (isPreviewMode, previewScrollOffset, editorLineIndex, editorColumnOffset) per note in UserSettings, cleanup orphaned positions
│   ├── note_storage_service.dart      # NotesSortOrder enum, wraps NoteRepository with model conversion (DB Note → NoteMetadata), handles compression detection + preview generation + chunk count calculation
│   └── settings_service.dart          # Singleton wrapping UserSettingsDao with typed getters/setters for all app settings (controls, editor, preview, toolbar, fonts, onboarding), getUtilityConfig/setUtilityConfig for UtilityButtonConfig persistence
├── pages/
│   ├── optimized_folder_content_page.dart # Main folder page: two-section (subfolders + notes) with InfiniteScrollList, drag-to-reorder, FAB with speed dial (new note/new folder), sort selection, Dismissible swipe actions, folder breadcrumb navigation
│   ├── optimized_note_editor_page.dart    # Main editor: re_editor CodeEditor + MarkdownToolbar, split mode (edit|preview|both), keyboard-aware preview toggle, auto-save integration, position persistence, NoteSearchBar overlay, scroll-to-top/bottom, font size management, share, debug overlays
│   ├── search_page.dart                   # Full-text search with recent searches, debounced input, FolderSearchService integration, highlighted results
│   ├── counter_management_page.dart       # Counter CRUD: create/edit/delete counters, set start value & step, toggle global/per-note scope, pin/unpin (highlighted border), reorderable list, note picker for per-note values, navigate to counter_per_note_page
│   ├── counter_per_note_page.dart         # Per-counter note list: ReorderableListView.builder with drag handles, FAB opens showNotePickerDialog, increment/decrement/set/reset per note, pin/unpin/remove in popup menu, pin indicator on cards
│   ├── markdown_settings_page.dart        # Toolbar customization: reorderable shortcut list + utility button list, visibility toggles, add/edit/delete custom shortcuts, date format config, bar profile management (MarkdownBarService), toolbar ratio slider, split toggle
│   ├── controls_settings_page.dart        # Settings: gestures, feedback, auto-save, display, editor options, preview options, preview performance (linesPerChunk), reset to defaults
│   ├── database_settings_page.dart        # Multi-DB management: list databases, create/rename/delete, switch active, backup export/import (file_picker for import)
│   ├── developer_options_page.dart        # Hidden dev settings: all DevOptions toggles, lock button, reset button
│   ├── note_bar_assignment_page.dart      # Per-note bar profile assignment: shows all notes grouped by folder, select which bar profile each note uses
│   ├── shortcut_editor_page.dart          # Full editor page for creating/editing shortcuts: icon picker, before/after text, insertType, date format, date offset, repeat config with increments
│   └── onboarding_page.dart               # First-launch setup with PageView: welcome, import backup option, completion
├── widgets/
│   ├── markdown_toolbar.dart              # Split toolbar: left=shortcuts (draggable, scrollable), right=utility buttons (configurable order/visibility). Reorder mode with drag handles. Callbacks: onShortcutPressed, onScrollToTop/Bottom, onUndo/Redo, onShare, onSettings, onReorderComplete, onSwitchBar, onPaste, etc. Uses UtilityButtonDefinition registry for icons/tooltips.
│   ├── unified_app_bars.dart              # FolderAppBar (menu/back + title + actions), NoteAppBar (back + title + save indicator dot + SpinningIcon animation), SettingsAppBar (menu + title), SearchAppBar (text field + clear)
│   ├── app_drawer.dart                    # Navigation drawer: language selector, theme toggle (light/dark/system), developer options entry (if unlocked), settings links (controls, markdown, database)
│   ├── app_loading_bar.dart               # AppLoadingBar (listens to LoadingService.isLoading), LoadingScaffold (Scaffold + AppLoadingBar on top)
│   ├── app_dialogs.dart                   # Common dialogs: create folder/note, rename, delete confirmation, error
│   ├── bar_switcher_sheet.dart            # Bottom sheet for switching markdown bar profile: searchable list of profiles
│   ├── counter_form_dialog.dart           # Dialog for creating/editing counters (name, start value, step, scope)
│   ├── counter_picker_dialog.dart         # Paginated picker for selecting notes with counter values
│   ├── note_picker_dialog.dart            # Paginated picker for selecting notes (used by counter_per_note_page)
│   ├── debug_overlays.dart                # Conditional debug widgets: BlockColorOverlay, WhitespaceOverlay, LineNumberOverlay, RenderTimeOverlay, NoteSize/CursorInfo/ChunkIndicator overlays, FpsCounter
│   ├── double_tap_line_detector.dart      # GestureDetector that translates double-tap Y position into a logical line index using weighted markdown line heights
│   ├── editor_chunk_overlay.dart          # CustomPainter drawing colored chunk backgrounds in the code editor for debug visualization
│   ├── full_markdown_view.dart            # Full markdown rendering with checkbox support for dialogs
│   ├── icon_picker_dialog.dart            # Searchable icon picker with keyword-based search index (~170 icons from AvailableIcons)
│   ├── infinite_scroll_list.dart          # Generic paginated list (InfiniteScrollList<T>, InfiniteScrollSliver<T>, PaginationInfo) with loadMore threshold
│   ├── interactive_preview_scrollbar.dart # Draggable scrollbar for preview mode with tap-to-scroll
│   ├── modern_editor_wrapper.dart         # Wraps re_editor CodeEditor with custom toolbar integration, scroll indicator, and debug chunk overlay
│   ├── note_search_bar.dart               # In-note search/replace overlay: match count, prev/next navigation, case sensitivity, regex, whole-word toggles, replace/replaceAll
│   ├── overlay_snackbar.dart              # Lightweight overlay-based snackbar
│   ├── scroll_progress_indicator.dart     # Custom scrollbar with position smoothing, edge snapping, touch-drag, and adaptive animations
│   ├── scroll_zone_mixin.dart             # Mixin for momentum-based scrolling with velocity tracking and animation
│   ├── shortcut_editor_dialog.dart        # Full editor for creating/editing shortcuts: icon picker, before/after text, insertType, date format, date offset, repeat config with increments
│   ├── simple_markdown_preview.dart       # Lightweight cached markdown preview widget
│   └── source_mapped_markdown_view.dart   # Line-based chunked markdown view: splits content by lines, renders chunks lazily, search highlighting, checkbox toggle callbacks, scroll sync with editor via line mapping
├── handlers/
│   ├── counter_shortcut_handler.dart      # Handles counter value insertion into editor text
│   ├── date_shortcut_handler.dart         # Handles 'date' insertType: cached date format from UserSettings, date offset, repeat with date increments
│   ├── default_shortcut_handler.dart      # Handles 'wrap' insertType: wraps selection with before/after text, optional repeat
│   └── header_shortcut_handler.dart       # Handles 'header' insertType: shows popup menu for H1-H6 selection
├── factories/
│   └── shortcut_handler_factory.dart      # Maps insertType → handler: 'header'→HeaderShortcutHandler, 'date'→DateShortcutHandler, default→DefaultShortcutHandler
├── interfaces/
│   └── markdown_shortcut_handler.dart     # Abstract: execute({context, shortcut, controller, focusNode, onTextChanged})
├── utils/
│   ├── bloc_helpers.dart                  # Context-aware BLoC state filtering to prevent cross-page state pollution
│   ├── compression_utils.dart             # zlib compress/decompress + base64 encoding for content chunks
│   ├── custom_snackbar.dart               # showSuccess/showError/showInfo floating snackbars with toolbar offset awareness
│   ├── dialog_helpers.dart                # confirmDialog, textInputDialog, alertDialog, loadingIndicator
│   ├── editor_width_calculator.dart       # Calculates available text width accounting for line numbers, scrollbar padding; smart line breaking with markdown syntax awareness
│   ├── icon_utils.dart                    # getIconDataFromCodePoint: maps icon codePoints to constant IconData refs for tree-shaking safety
│   ├── isolate_worker.dart                # IsolateWorker + IsolatePool for offloading CPU-heavy operations
│   ├── line_based_markdown_builder.dart   # Line-by-line markdown→Widget rendering with LRU cache, lazy code block detection, search highlighting, configurable chunk sizes
│   ├── lru_cache.dart                     # Generic LruCache<K,V> using LinkedHashMap with maxSize eviction
│   ├── markdown_line_height_calculator.dart # Maps markdown line content to height scale factors (H1-H6, empty, HR, code block)
│   ├── markdown_list_utils.dart           # isEmptyListItem detection, list prefix generation
│   ├── markdown_settings_utils.dart       # UI helpers for displaying shortcut info (subtitles) in settings pages
│   ├── markdown_span_builder.dart         # Large-scale markdown→TextSpan converter with lazy block building, search highlighting, checkbox support, source range tracking
│   ├── re_editor_search_controller.dart   # Wraps re_editor's CodeFindController: search/replace with case sensitivity, regex, whole-word; ReplaceResultState sealed (Success|Failure)
│   ├── scroll_position_sync.dart          # Synchronizes scroll position between editor and preview during mode switches
│   ├── text_history_observer.dart         # Atomic undo/redo grouping for multi-step editor operations
│   └── text_position_utils.dart           # getLineFromOffset, getColumnFromOffset, getPosition(line+column) from text+offset
├── l10n/
│   ├── app_en.arb                         # English strings (primary)
│   ├── app_de.arb                         # German strings
│   ├── app_ro.arb                         # Romanian strings
│   ├── app_localizations.dart             # Generated base class
│   ├── app_localizations_en.dart          # Generated English
│   ├── app_localizations_de.dart          # Generated German
│   └── app_localizations_ro.dart          # Generated Romanian
├── controllers/
│   └── preview_scroll_controller.dart     # Manages preview scroll position in split-view, syncs editor↔preview line mapping
├── config/
│   ├── default_markdown_shortcuts.dart    # DefaultMarkdownShortcuts.shortcuts: 17 defaults (bold, italic, header, point list, strikethrough, bullet list, numbered list, checkbox, quote, inline code, code block, link, checked checkbox, table, horizontal rule, image, date)
│   └── available_icons.dart               # AvailableIcons.all: ~170 Material icons organized by category for shortcut icon picker
└── packages/
    └── re_editor/                         # Local fork of re_editor package (high-performance code editor with line virtualization)
```

## Dependency Injection (get_it)
```dart
// Setup order in configureDependencies():
// 1. Database (singleton) → AppDatabase.getInstance()
// 2. Repositories (singleton) → NoteRepository(db), FolderRepository(db)
// 3. Services (singleton, initialized) → FolderStorageService, NoteStorageService, FolderSearchService, MarkdownBarService, CounterService
// 4. BLoCs (factory) → OptimizedFolderBloc, OptimizedNoteBloc, MarkdownBarBloc, CounterBloc
// Note: CounterPerNoteBloc is NOT registered in DI — created inline via BlocProvider in CounterPerNotePage
// NOT in DI (singleton pattern): SettingsService, BackupService, DatabaseManager, MarkdownBarService, NotePositionService, DevOptionsService, AutoSaveService, LoadingService
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
- **AppDatabase**: Drift database singleton with HLC clock (LazyDatabase in background, LoadingQueryInterceptor, schema v5, generateHlc/generateId/rebuildFtsIndex/vacuum)
- **DatabaseSchema**: Schema version constants (currentVersion=5, v1-v5)
- **DatabaseManager**: Multiple .db file management via SharedPreferences (create, switch, delete, rename, list, path resolution, name validation)
- **DatabaseMigrations**: Step-by-step schema migration runner
- **DatabaseIndexes**: B-tree indexes + FTS5 table creation
- **NoteRepository**: LRU cached (200 notes, 50 content) + reactive StreamController<NoteChange> (created/updated/deleted)
- **FolderRepository**: LRU cached (100 folders) + reactive StreamController<FolderChange>
- **Result<T>**: Sealed type (Success/Failure) with fold/map/dataOrNull extensions
- **AppError**: Sealed error hierarchy (Database/NotFound/Validation/Network/Cache/Permission/Unknown)
- **HybridLogicalClock**: CRDT clock (now/receive/update) for causality ordering
- **HlcTimestamp**: Comparable timestamp (wallTime:counter:nodeId as hex)
- **LazyNote**: NoteMetadata + optional content (withContent(), isContentLoaded)
- **PaginatedNotes/PaginatedFolders**: Paginated list + currentPage/totalPages/totalCount/hasMore
- **SearchResult**: NoteMetadata + SearchMatch[] + relevanceScore
- **SearchMatch**: text context + startIndex/endIndex + type(title/content)
- **SearchIndex**: Inverted index with binary search prefix matching, built in isolate for >50 notes
- **CheckboxToggleInfo**: start/end indices + replacement text for checkbox toggling in preview
- **LoadingService**: Singleton ValueNotifier<bool> with nested operation counter
- **AutoSaveService**: Fingerprint-based (hash+length), lazy content providers (no string copy per keystroke), debounce+interval timers, SaveStatus enum (saved/unsaved/saving/error), retry w/ exponential backoff
- **TextHistoryObserver**: Atomic undo/redo grouping for multi-step operations
- **ReEditorSearchController**: Wraps CodeFindController with case/regex/wholeWord + replace (sealed ReplaceResultState)
- **FolderSearchService**: Full-text search with SearchIndex, diacritics normalization, relevance scoring, recent searches
- **SettingsService**: Typed getter/setter wrapper over UserSettingsDao for all app settings
- **CustomMarkdownShortcut**: Equatable model with insertType ('wrap'|'header'|'date'), dateFormat, dateOffset, repeatConfig
- **MarkdownBarProfile**: Named profile with shortcuts list, used by MarkdownBarService for multi-bar support
- **MarkdownBarService**: ChangeNotifier singleton managing profiles + per-note assignments + legacy migration
- **BackupService**: Export/import v2 JSON format (folders, notes w/ content, shortcuts, settings, bar profiles, note assignments)
- **NotePositionService**: Per-note cursor/scroll position persistence in UserSettings
- **UtilityButtonId**: Static const button IDs + defaultOrder + locked set
- **UtilityButtonConfig**: Serializable per-button visibility + ordering + merge logic for new buttons
- **UtilityButtonDefinition**: Registry pattern (all[] + getById) for button icon/label/lock metadata
- **DevOptions**: ChangeNotifier singleton with 13+ debug toggles, persisted via DevOptionsService
- **EditorWidthCalculator**: Calculates text width accounting for line numbers + scrollbar padding + markdown syntax-aware line breaking
- **LineBasedMarkdownBuilder**: Line-by-line markdown→Widget with LRU cache, lazy code block detection, configurable chunk sizes
- **MarkdownSpanBuilder**: Markdown→TextSpan converter with lazy block building, search highlighting, checkbox support, source range tracking
- **ScrollProgressIndicator**: Custom scrollbar with position smoothing, stabilization, edge snapping, touch-drag

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
settings.folderSwipeEnabled;  // Swipe to open drawer on folder page (default: true)
settings.noteSwipeEnabled;    // Swipe to open drawer on note editor (default: true)

// Behavior
settings.confirmDelete;       // Show confirmation before deleting (default: true)
settings.autoSaveEnabled;     // Enable/disable auto-save (default: true)
settings.autoSaveInterval;    // Auto-save interval in seconds (default: 30)
settings.hapticFeedback;      // Haptic feedback on interactions (default: true)

// UI / Display
settings.showNotePreview;     // Show note preview in lists (default: true)
settings.showNoteDate;        // Show date in note lists (default: true)

// Editor
settings.editorFontSize;      // Editor font size (default: 14.0)
settings.showMarkdownToolbar;  // Show toolbar in editor (default: true)
settings.toolbarShortcutRatio; // Ratio of toolbar width for shortcuts (default: 0.65)
settings.showToolbarDivider;   // Show divider between shortcuts/utility (default: true)
settings.enableSplitToolbar;   // Split toolbar left/right sections (default: true)

// Preview
settings.previewFontSize;     // Preview font size (default: 16.0)
settings.linesPerChunk;       // Lines per render chunk (default: 100)

// Onboarding
settings.isOnboardingCompleted();
await settings.setOnboardingCompleted(true);

// Utility buttons (serialized as JSON)
final configs = await settings.getUtilityConfig();
await settings.setUtilityConfig(configs);

// All keys defined in SettingsKeys class (lib/constants/settings_keys.dart)
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
// Shortcut system has three layers:
// 1. CustomMarkdownShortcut (model) - data + serialization
// 2. MarkdownShortcutHandler (interface) - execute() method
// 3. ShortcutHandlerFactory - maps insertType to handler

// InsertTypes:
// 'wrap' (default) → DefaultShortcutHandler: wraps selection with before/after text
// 'header' → HeaderShortcutHandler: shows H1-H6 popup menu
// 'date' → DateShortcutHandler: inserts formatted date, supports offset + repeat with increments

// Bar profiles (multi-bar system via MarkdownBarService):
final svc = await MarkdownBarService.getInstance();
svc.profiles;                                        // All profiles
svc.activeProfile;                                   // Currently active
await svc.addProfile('My Bar');                      // Create with defaults
await svc.duplicateProfile(sourceId, 'Copy');        // Clone
await svc.setActiveProfile(profileId);               // Switch globally
await svc.setNoteBarId(noteId, profileId);           // Per-note override
final resolved = await svc.resolveProfileForNote(noteId); // Override → global

// Shortcut properties
shortcut.id;              // Unique identifier
shortcut.label;           // Display text
shortcut.iconCodePoint;   // Material icon code point
shortcut.iconFontFamily;  // 'MaterialIcons'
shortcut.beforeText;      // Text before selection
shortcut.afterText;       // Text after selection
shortcut.insertType;      // 'wrap', 'header', 'date'
shortcut.isVisible;       // Show in toolbar
shortcut.isDefault;       // Can't be deleted
shortcut.dateFormat;      // e.g. 'MMMM d, yyyy' (for date type)
shortcut.dateOffset;      // DateOffset(days, months, years) offset from today
shortcut.repeatConfig;    // RepeatConfig(count, incrementDate, separator, before/afterRepeatText)

// Default shortcuts (17): bold, italic, header, point list, strikethrough, bullet list, numbered list, checkbox, quote, inline code, code block, link, checked checkbox, table, horizontal rule, image, date
```

## Utility Buttons (Toolbar Right Side)
```dart
// Three-tier system:
// 1. UtilityButtonId - static const IDs + defaultOrder + locked set
// 2. UtilityButtonConfig - per-user visibility/ordering (persisted in UserSettings as JSON)
// 3. UtilityButtonDefinition - registry with icon, labelResolver, isLocked

// Adding a new utility button:
// 1. Add const ID to UtilityButtonId + add to defaultOrder list
// 2. Add UtilityButtonDefinition entry in all[] list
// 3. Add switch case in _buildUtilityButtonWidget (markdown_toolbar.dart) for callback
// 4. Add callback to MarkdownToolbar widget + wire in editor page
// 5. Add l10n string to all ARB files + run flutter gen-l10n

// Current buttons (in default order):
// undo, redo, paste, decreaseFont, increaseFont, share, switchBar, scrollToTop, scrollToBottom, reorder, settings
// Locked (can't be hidden): settings

// Settings persistence:
final settings = await SettingsService.getInstance();
final configs = await settings.getUtilityConfig();  // List<UtilityButtonConfig>
await settings.setUtilityConfig(configs);            // Encoded as JSON in UserSettings
```

## Widget Highlights
```dart
// MarkdownToolbar - customizable toolbar with shortcuts (left) + utility buttons (right)
MarkdownToolbar(
  shortcuts: shortcuts,                              // Left side: CustomMarkdownShortcut list
  isPreviewMode: false,
  canUndo: true,
  canRedo: false,
  previewFontSize: 16.0,
  onUndo: () => {},
  onRedo: () => {},
  onPaste: () => {},
  onDecreaseFontSize: () => {},
  onIncreaseFontSize: () => {},
  onSettings: () => {},
  onShortcutPressed: (shortcut) => _handleShortcut(shortcut),
  onReorderComplete: (reordered) => _saveOrder(reordered),
  onShare: () => {},
  onSwitchBar: () => {},                             // Toggle to next bar profile
  onScrollToTop: () => {},                           // Scroll editor/preview to top
  onScrollToBottom: () => {},                        // Scroll editor/preview to bottom
  showBackground: true,
  utilityConfigs: utilityConfigs,                     // Right side: UtilityButtonConfig list
);
// Utility buttons use UtilityButtonDefinition.getById() for icon/tooltip
// In preview mode, utility Row is wrapped in SingleChildScrollView(horizontal)

// InteractiveMarkdown - markdown preview with checkbox support
InteractiveMarkdown(
  data: markdownContent,
  selectable: true,
  onCheckboxToggle: (CheckboxToggleInfo info) => {},
  styleSheet: MarkdownStyleSheet(...),
  selectedLine: 5,                                   // Highlights line in preview
  onLineTap: (lineNumber) => {},                     // Tap line → jump to editor
);

// FolderAppBar - for folder navigation pages
FolderAppBar(
  title: 'Folder Name',
  isRootPage: true,          // Shows menu icon, false shows back arrow
  actions: [...],
  onMenuPressed: () => {},
  onBackPressed: () => {},
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

// ScrollProgressIndicator - custom scrollbar overlay
// Uses ValueNotifier<double> position/thumbHeight, smoothing via EMA,
// stabilization threshold, edge snapping, touch-drag support
// Positioned in Stack alongside editor/preview content

// ConfirmationDialogs - reusable themed dialogs
// ShowDeleteConfirmation, ShowConfirmation with consistent styling
```