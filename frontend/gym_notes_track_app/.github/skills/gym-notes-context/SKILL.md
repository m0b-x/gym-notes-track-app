---
name: gym-notes-context
description: "Use when working in the Gym Notes Flutter app (gym_notes_track_app). Loads product purpose, architecture, persistence rules, l10n requirements, validation commands, and UX direction for this offline-first gym progress tracker built on Flutter, BLoC, Drift SQLite, and re_editor. USE FOR: implementing or changing folders, notes, markdown editor, markdown shortcuts, counters (global and per-note), backup/restore, multi-database management, settings, onboarding, search, or anything touching workout-tracking workflows. DO NOT USE FOR: unrelated Flutter projects or generic Dart questions."
---

# Gym Notes Context Skill

Load this whenever a task touches the `gym_notes_track_app` Flutter workspace. It sets product framing, architecture rules, and validation steps so changes stay consistent with the existing app.

## 1. Load The Canonical Context

Read [COPILOT_CONTEXT.md](../../../COPILOT_CONTEXT.md) before planning or editing. It is the source of truth for:

- Product purpose and user workflows (gym/workout tracking, notes, counters).
- Non-negotiable rules (localization, generated files, build_runner, no unsolicited tests/comments).
- Stack, architecture flow, main feature areas, persistence rules.
- Localization, UI/UX direction, error handling, validation commands.
- Defaults for adding new gym progress features.

Do not restate that file back to the user; just follow it.

## 2. Quick Decision Checklist

Before writing code, confirm:

1. Does the change require new persisted data?
   - If yes, decide between: note markdown content, a counter, a setting, or a new Drift table/migration.
   - New tables/columns require a Drift migration and a `dart run build_runner build --delete-conflicting-outputs` run. Never reset storage.
2. Does the change add or rename user-visible text?
   - If yes, update `lib/l10n/app_en.arb`, `app_de.arb`, and `app_ro.arb`, then run `flutter gen-l10n`.
3. Does the change touch BLoCs, services, repositories, or DAOs?
   - Keep the flow `Page → BLoC → Service → Repository → DAO → Drift`.
   - Match the local style for sealed/Equatable states, events, and `copyWith`.
   - Invalidate caches after creates, updates, deletes, moves, and reorder ops.
4. Does the change affect the editor, auto-save, or note position?
   - Preserve auto-save reliability (debounce, interval, retry, lifecycle flush).
   - Keep cursor and preview position persistence behavior intact.
5. Does the change affect counters?
   - Respect `scope` (`global` vs `perNote`), `isPinned`, ordering, and `noteId == ''` for global values in `counter_values`.
6. Does the change affect backup/restore?
   - Add new persisted fields to backup export/import without breaking older backups.
7. Does the change touch import/export of notes or folders?
   - Go through `ImportExportBloc` from the UI; never call `ImportExportService` or `SharePlus` directly from a page/widget.
   - Preserve `createdAt`/`updatedAt` and folder sort preferences across round-trips by routing through the `importX` methods (`FolderDao.importFolder`, `NoteDao.importNote`, plus the matching repository/service wrappers). Use `createX` only for genuine user-initiated creates.
   - Bumping the archive schema requires bumping `ImportExportService.archiveVersion` *and* updating `_assertSupportedManifest` to accept the previous version.
   - Any export entry point must use `shareExport` (auto-cleans the temp file) and rely on the existing startup `sweepStaleExports` call in `main.dart`.

## 3. Style Rules To Enforce

- No code comments unless explicitly requested.
- No new tests unless explicitly requested.
- No new markdown documentation files unless explicitly requested.
- Use `AppLocalizations.of(context)!.keyName` for every user-visible string.
- Use existing constants from `lib/constants/` (spacing, text styles, icon sizes, settings keys, JSON keys, app constants) instead of magic values.
- Prefer compact, touch-friendly Material 3 UI with stable layouts.

## 4. Validation Commands (PowerShell On Windows)

Run only what the change requires.

```powershell
dart analyze lib
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Helper scripts:

```powershell
.\build_release.bat arm64
.\install_to_device.bat arm64
.\generate_drift.bat
```

Typical mapping:

- UI-only Dart change: `dart analyze lib`.
- ARB / l10n change: `flutter gen-l10n`, then `dart analyze lib`.
- Drift table / DAO / migration change: `dart run build_runner build --delete-conflicting-outputs`, then `dart analyze lib`.

## 5. When To Ask Vs Act

- Act without asking when the request is concrete, scoped, and matches existing patterns.
- Ask only when a change would alter persisted data shape in a non-backward-compatible way, change backup format semantics, or introduce a new architectural pattern (new state-management lib, new persistence layer, new navigation strategy).

## 6. Anti-Patterns To Avoid

- Hand-editing `lib/database/database.g.dart` or generated `app_localizations_*.dart` files.
- Resetting or wiping the local database to "fix" schema drift instead of writing a migration.
- Adding raw `SharedPreferences` keys instead of going through `SettingsService` + `SettingsKeys`.
- Hardcoding user-facing strings in Dart instead of using ARB + `AppLocalizations`.
- Introducing heavy work on the editor's hot path (per-keystroke string copies, synchronous DB writes, expensive rebuilds).
- Adding decorative UI churn that causes layout shifts in the editor, toolbar, counters, or folder/note lists.
