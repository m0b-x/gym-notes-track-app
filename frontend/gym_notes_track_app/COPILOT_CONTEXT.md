# Gym Notes - Copilot Context

## Product Purpose
Gym Notes is an offline-first Flutter app for tracking gym progress through structured notes, folders, markdown, and counters. Treat it as a training log first and a generic notes app second.

When changing the app, optimize for fast workout-session use:
- Users should be able to capture sets, reps, weights, PRs, bodyweight, soreness, exercises, routines, and session notes with minimal friction.
- Editing must feel reliable during or after a workout: no lost text, no surprising navigation, no heavy UI while typing.
- Organization should support real gym habits: folders for programs or muscle groups, notes for sessions/templates, counters for global or per-note metrics.
- Offline data ownership matters. Preserve local SQLite data, backup/restore behavior, and future sync readiness.
- UI should be practical, touch-friendly, and quick to scan in a gym environment. Prefer clear controls, high contrast, stable layouts, and small but obvious status feedback.

## Core User Workflows
- Create folders/subfolders for programs, routines, exercises, weeks, or muscle groups.
- Create and edit markdown notes for workouts, templates, exercise logs, measurements, and progress history.
- Use custom markdown toolbar shortcuts for fast entry of headings, lists, checkboxes, tables, dates, and repeated workout structures.
- Track numeric progress with counters, including global counters and per-note counters with pinning and manual ordering.
- Search across notes and within the active note, including regex/whole-word options in the editor search overlay.
- Switch databases, export/import backups, and keep localized app text in English, German, and Romanian.

## Non-Negotiable Rules
- Use `AppLocalizations` for every user-visible string. Update `lib/l10n/app_en.arb`, `app_de.arb`, and `app_ro.arb` together, then run `flutter gen-l10n`.
- Do not hand-edit generated files such as `lib/database/database.g.dart` or generated localization Dart files.
- After changing Drift tables, DAOs, migrations, or database annotations, run `dart run build_runner build --delete-conflicting-outputs`.
- Keep generated schema/migration changes compatible with existing local user data. Add migrations instead of resetting storage.
- Do not add tests, new markdown files, broad refactors, or code comments unless explicitly requested.
- Preserve existing user data semantics: soft deletes, CRDT fields, positions, sort preferences, pinned counters, note assignments, and backup format compatibility.
- Keep changes focused and consistent with the local style. Avoid introducing new state-management, persistence, or navigation patterns without a strong reason.

## Current Stack
- Flutter app with Dart SDK `^3.10.4`, Material 3, and `flutter_lints`.
- State management: `flutter_bloc` with `Equatable` states/events.
- Persistence: Drift SQLite, `sqlite3_flutter_libs`, `path_provider`, `shared_preferences`.
- DI: `get_it` via `lib/core/di/injection.dart`.
- Editor/markdown: local `packages/re_editor`, `flutter_markdown_plus`, `markdown`.
- Search/debounce: `stream_transform`, FTS5, isolate-backed indexing utilities.
- Sharing/import: `share_plus`, `file_picker`.
- External links: `url_launcher` (markdown preview hyperlinks open via `LaunchMode.externalApplication`; only `http`, `https`, `mailto`, `tel` schemes are accepted).
- Localization: Flutter gen-l10n with locales `en`, `de`, `ro`.

## Architecture Shape
Follow the existing flow:

```text
Page/Widget -> BLoC -> Service -> Repository -> DAO -> Drift database
```

- BLoCs live under `lib/bloc/` and should stay thin: route events, manage loading/error states, and delegate business logic to services.
- Services in `lib/services/` own app workflows such as note storage, folder storage, search indexing, counters, settings, backup/restore, database switching, auto-save, and note positions.
- Repositories in `lib/repositories/` provide cached/reactive access over DAOs. Invalidate caches carefully after creates, updates, deletes, moves, and reorder operations.
- DAOs in `lib/database/daos/` own SQL/Drift details, transactions, soft deletes, pagination, FTS, and migrations support.
- Models in `lib/models/` generally use `Equatable`, `copyWith`, and JSON keys from `lib/constants/json_keys.dart`.
- Constants belong in `lib/constants/`. Prefer existing spacing, text style, icon size, settings key, and app constant files over magic values.

## Main Feature Areas
- `lib/pages/optimized_folder_content_page.dart`: main folder/note browser with nested folders, pagination, sorting, reordering, swipe actions, FAB creation, and navigation.
- `lib/pages/optimized_note_editor_page.dart`: main workout note editor with `re_editor`, markdown toolbar, preview/split modes, auto-save, note position persistence, search/replace, sharing, and debug overlays.
- `lib/widgets/markdown_toolbar.dart`: configurable shortcut and utility toolbar. Use `UtilityButtonDefinition` as the registry for utility buttons.
- `lib/pages/markdown_settings_page.dart`, `shortcut_editor_page.dart`, `note_bar_assignment_page.dart`: markdown shortcut profiles and per-note toolbar assignment.
- `lib/pages/counter_management_page.dart` and `counter_per_note_page.dart`: global/per-note counter workflows for workout metrics.
- `lib/services/counter_service.dart`: counter cache, debounced writes, pinning, ordering, import/export, and flush behavior.
- `lib/services/auto_save_service.dart`: note content save reliability. Be careful with debounce, interval saves, lifecycle flushes, and retry behavior.
- `lib/services/backup_service.dart`: JSON backup/restore. Keep versioned compatibility when adding persisted fields.
- `lib/services/import_export_service.dart`: per-note and per-folder share/import (single files or `.zip` archives). Owns archive `manifest.json` versioning, temp-file cleanup, and unique-name resolution. The matching `ImportExportBloc` (`lib/bloc/import_export/`) is the only allowed entry point for the UI.
- `lib/services/database_manager.dart`: multi-database management and active database selection.

## Markdown Preview Pipeline
The note-editor preview is fully BLoC-driven. Keep this layering intact:

```text
OptimizedNoteEditorPage
  -> MarkdownPreviewBloc (lib/bloc/markdown_preview/)
     -> MarkdownRenderService (lib/services/markdown_render_service.dart)
        -> LineBasedMarkdownBuilder (lib/utils/line_based_markdown_builder.dart)
  -> MarkdownPreviewBlocView (lib/widgets/markdown_preview_bloc_view.dart)
     -> SourceMappedMarkdownView (lib/widgets/source_mapped_markdown_view.dart)
```

Non-negotiable invariants:

- Bloc state is `Equatable` and contains only primitives + a `renderHandle: int` token. Never put `InlineSpan` trees, builders, or other heavy objects in state.
- Spans are pulled from `bloc.renderService.builder` on demand; the widget rebuilds the heavy list only when `renderHandle`, `linesPerChunk`, or `fontSize` change (`buildWhen`).
- The bloc owns its `MarkdownRenderService` and `PreviewScrollController` and disposes them in `close()`. The page wires callbacks via `bloc.bindCallbacks(onLinkTap:, onCheckboxTap:)`.
- **Content sync**: use `bloc.bindContentProvider(() => _contentController.text)` once in `initState` and call `bloc.markContentDirty()` on every keystroke (free `int++`). Dispatch `PreviewContentRefreshRequested` (not `PreviewContentChanged`) when you want a lazy refresh; the bloc short-circuits when the dirty version hasn't moved since the last consume. Only use `PreviewContentChanged` for eager pushes (toggle, checkbox, locale change, content load).
- **Live refresh**: `_scheduleLivePreviewRefresh()` (called from `_onTextChanged`) debounces `PreviewContentRefreshRequested` at 500 ms for non-large notes (`lineCount <= AppConstants.previewPreloadLineThreshold = 3000`). It is gated on `!_isLoading` and `state.hasTheme` so the first build is never blocked. The debounce timer is cancelled in `dispose()`.
- **Search content sync**: `_pushPreviewContent` calls `_searchController.updateContent(content)` when `_searchController.isSearching`; `_scheduleLivePreviewRefresh` does the same after dispatch. Never call `updateContent` inside `build()`. `ReEditorSearchController.updateContent` deduplicates on `identical/==` so redundant calls are free.
- Theme dispatch (`PreviewThemeChanged`) happens from `MarkdownPreviewBlocView` lifecycle hooks (`didChangeDependencies` + a `DevOptions` listener) — never from `build()`. Equality is keyed on `(brightness, debugEnabled)` so closure-only changes do not trigger rebuilds.
- Scroll progress bypasses the bloc event queue: the view calls `bloc.scrollController.updateProgress(progress)` directly to avoid per-frame state churn.
- **Preview view key**: the page holds `final GlobalKey<SourceMappedMarkdownViewState> _previewViewKey = GlobalKey<...>()` as a field. It is bound to the scroll controller in `initState` via `_previewController = _previewBloc.scrollController..bindView(_previewViewKey)` and passed explicitly to `MarkdownPreviewBlocView(viewKey: _previewViewKey)`. Access state via `_previewViewKey.currentState` (e.g. `currentLineIndex`) for preview→editor scroll mapping.
- **Preview→editor scroll**: on toggle back to editor, compare `_previewViewKey.currentState?.currentLineIndex` against `(savedBaseIndex ~/ linesPerChunk) * linesPerChunk` to detect real user scrolling. Only snap the editor and move the caret when the user actually moved the preview; otherwise fall back to `_restoreEditorPosition()` which honors the exact saved selection.
- **Toolbar helper**: use `_buildMarkdownBar({required bool enabled})` for both the loading-skeleton and loaded paths. Pass `enabled: false` when loading to preserve layout without wiring live callbacks.
- **Double-tap from preview**: `_handleDoubleTapLine` parks the cursor at end-of-line. `DoubleTapLineDetector` currently always passes `columnOffset = 0` (column resolution from styled spans needs `TextPainter` introspection — future work). Forward-compatible: when a future detector passes `columnOffset > 0`, the handler clamps it to the line length.
- Adaptive chunk sizing in `MarkdownRenderService._computeAdaptiveChunkSize` is capped at `_maxAdaptiveChunkSize = 100` to keep `scrollToLineIndex` precision usable on huge notes.
- The empty-preview placeholder text is locale-cached on the page (`_emptyPreviewPlaceholder`) and re-dispatched when the locale changes while the note is empty.
- Preview hyperlinks: the page passes `_handleLinkTap` to `MarkdownPreviewBlocView.onTapLink`. The handler validates the scheme against `_allowedLinkSchemes` (`http`, `https`, `mailto`, `tel`), launches via `url_launcher` in `LaunchMode.externalApplication`, and shows a localized `CustomSnackbar.showError` (`linkSchemeNotAllowed` / `linkOpenFailed`) on rejection or failure. Do not bypass scheme validation.

## Data And Persistence Rules
- The database uses Drift with a singleton active database and background `LazyDatabase` connection.
- Folder, note, and content chunk tables include CRDT-style metadata for future sync: `hlcTimestamp`, `deviceId`, `version`, `isDeleted`, and optional `deletedAt` where supported.
- Notes store metadata separately from content. Content is chunked and may be compressed; avoid unnecessary full-content copies in hot editor paths.
- Reorder operations should be transactional and preserve user-defined positions.
- Search uses both SQLite/FTS and an app-level index; keep indexes in sync when notes are created, updated, deleted, or moved.
- Counters use `noteId == ''` for global values in `counter_values`; per-note values use the real note id.
- Custom markdown shortcuts can bind up to two counters via `CustomMarkdownShortcut.counters` (`List<CounterBinding>`). Each binding has a `counterId` and a `CounterOp` (`increment` / `decrement`). The `{c1}` / `{c2}` tokens in `beforeText` / `afterText` / repeat wrapper text expand to the matching binding's post-mutation value at insertion time. Each token occurrence triggers exactly one mutation per repeat iteration. Token expansion runs through `ShortcutApplier` via the `CounterMutator` callback, which routes to `CounterBloc` (`IncrementCounter` / `DecrementCounter`) and respects the global vs per-note scope contract. The legacy `counterId` field is preserved for backwards compatibility — when `counters` is empty but `counterId` is set, `effectiveCounters` synthesises a single increment binding so applier logic stays uniform.
- Settings are stored through `UserSettingsDao`, `SettingsService`, and `SettingsKeys`. Do not scatter raw string keys.

## Import/Export Pipeline Rules
- Every layer has paired `createX` / `importX` methods on `FolderDao`/`NoteDao`, the matching repositories, and the storage services. `createX` always stamps `createdAt`/`updatedAt` to "now"; `importX` accepts caller-supplied timestamps so a round-tripped archive preserves originals. Never widen `createX` with optional timestamp params — add an `importX` overload instead.
- All UI access to import/export goes through `ImportExportBloc`. Pages dispatch events (`ExportNoteRequested`, `ExportFolderRequested`, `ExportItemsRequested`, `ImportFileRequested`, `ImportArchiveRequested`) and react to `ImportExportInProgress` / `ImportExportExportSuccess` / `ImportExportImportSuccess` / `ImportExportFailure`.
- Archive format: per-folder `_folder.json` (carries name, `createdAt`, sort orders), per-note JSON/MD/TXT bodies, top-level `manifest.json` with `version` (`ImportExportService.archiveVersion`). When bumping the manifest schema, also bump `archiveVersion` and accept the previous version in `_assertSupportedManifest`. Reject newer versions with `UnsupportedArchiveVersionException` before any DB writes.
- Temp files: every export lands under `getTemporaryDirectory()`. `shareExport` deletes the file after the share sheet returns; `sweepStaleExports` runs at app startup from `main.dart` and clears artefacts older than 24h. New export entry points must funnel through these helpers — do not invoke `SharePlus` directly from blocs/pages.

## Localization And Copy
- Primary source is `lib/l10n/app_en.arb`; keep German and Romanian files complete whenever keys change.
- Prefer concise, direct copy suitable for a utility app. The user may be in the middle of a workout, so labels should be short and easy to recognize.
- Avoid in-app explanatory text for obvious interactions. Use tooltips, icons, labels, and settings descriptions where appropriate.
- Keep domain terms consistent: folders, notes, counters, shortcuts, backup, import/export, auto-save, preview, search.

## UI And UX Direction
- This is a productivity/tracking app, not a marketing site. Favor compact, stable, repeat-use interfaces.
- Use Material 3 and existing constants for spacing, text, colors, icons, and dimensions.
- Keep controls touch-friendly: icon buttons, tooltips, menus, toggles, sliders, reorder handles, and clear destructive confirmations.
- Avoid layout shifts in editor, toolbar, counters, and folder/note lists. Stable dimensions matter more than decorative styling.
- For gym progress features, prefer quick capture patterns: reusable templates, pinned counters, recent/frequent actions, clear save status, and minimal taps.
- Respect light/dark/system themes and supported locales.

## Error Handling And State
- Prefer existing sealed/result-style patterns where available, but match the exact style in the target BLoC or service.
- Keep BLoC states immutable and `Equatable` where that is already the local pattern.
- Complete provided `Completer`s on success and error where events expose them.
- Use `debugPrint` for internal diagnostics where the file already does; user-facing errors must be localized.
- Avoid swallowing persistence failures in code paths where data loss could result. Surface save/import/export errors clearly.

## Validation Commands
Use PowerShell-compatible commands on Windows.

```powershell
dart analyze lib
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Release/device helper scripts exist:

```powershell
.\build_release.bat arm64
.\install_to_device.bat arm64
.\generate_drift.bat
```

Run only the commands relevant to the change. For UI-only Dart changes, `dart analyze lib` is usually the minimum validation. For l10n changes, run `flutter gen-l10n`. For Drift changes, run build_runner before analysis.

## Generated And Local Package Notes
- `packages/re_editor/` is a local editor fork, perf-tuned for this app. Key optimizations to preserve:
  - `CodeLines.asString` uses a 2-slot round-robin cache (LF+trimNewlines vs LF-only calls alternate without thrashing).
  - `_CodeLineSegmentQuckLineCount` sub-counts with a `_hashCache` field; `==` short-circuits on length/dirty/lineCount/charCount before deep comparison.
  - `findDisplayParagraphByLineIndex` and `_findDisplayRenderParagraph` in `_code_field.dart` use binary search on the sorted paragraph array.
  - `_CodeParagraphCache` is a bounded LRU (max 512 entries) that evicts head on overflow.
  - `_CodeHighlight` debounces highlight requests at 50 ms to avoid per-keystroke re-highlight.
  - `_kInitialCodeLines` uses `List.unmodifiable` on both levels for write-protection (no `const` because sub-objects aren't `const`).
  - When adding new mutation paths to `CodeLines`, call `cloneShallowDirty()` (not the public constructor) to preserve the `_segmentEnds` / `_asStringCache` reset contract.
- Treat `packages/re_editor/` as part of the workspace for bug/perf fixes, but avoid API-breaking changes.
- Generated localization Dart files are outputs from ARB files.
- `lib/database/database.g.dart` is generated by Drift.
- Android/iOS/macOS/Linux/Windows/web folders are platform shells; prefer app-level fixes in `lib/` unless the issue is platform-specific.

## Good Defaults For New Gym Progress Features
- If a feature captures workout data, decide whether it belongs in note markdown, a counter, settings, or database schema before adding new storage.
- Prefer note-level features when the data is naturally part of a workout session, and counter features when the value needs repeated numeric updates or cross-note aggregation.
- Preserve backup/export support for any persisted user data.
- Make sorting, pinning, and reordering explicit when users are likely to curate workout information manually.
- Keep input flows fast: sensible defaults, remembered choices, localized validation, and no unnecessary dialogs.
