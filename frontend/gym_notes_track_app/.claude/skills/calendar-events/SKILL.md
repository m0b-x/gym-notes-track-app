---
name: calendar-events
description: Rules and file map for the calendar/events subsystem in Gym Notes - custom events, data-driven categories, recurrence rules, public holidays, event editor sheet, day bars/summary, event-note links. USE FOR - any change touching lib/pages/calendar_page.dart, calendar_settings_page.dart, calendar_categories_page.dart, lib/bloc/calendar/, CalendarEventService, CategoryService, PublicHolidayService, RecurrenceRule, event_editor_sheet.dart, or the calendar_events / calendar_categories / public_holidays tables. Load together with gym-notes-context.
---

# Calendar & Events

Read [docs/calendar-events-feature.md](../../../docs/calendar-events-feature.md) — the deep, implementation-aware reference for this subsystem (domain model, recurrence semantics, persistence, editor layout). This skill lists the hard rules and the change-set recipes; the doc has the details.

Schema lineage: v10 calendar tables → v11 `end_date` + time-of-day → v12 `description` → v13 holiday profiles → v14 `note_id` event↔note link → v15 data-driven `calendar_categories`. The recurrence **interval** rides inside `rule_payload` JSON with no migration — keep it that way (write only when `> 1`, decode with clamped fallback to `1`; never add an `interval` column).

## Hard rules

- `TableCalendar.eventLoader` stays a pure O(1) lookup through `CalendarBloc.eventsForDay` (memoized per-day cache, cap 512). Never dispatch events, call services, or expand recurrences inside the loader. If you add a bloc handler that mutates events or the category filter, call `_invalidateDayCache()`; never invalidate from day/focus/format handlers.
- The `CalendarRecurrence` enum and `event.recurrence` field are gone — always use `event.rule` (sealed `RecurrenceRule`).
- `event.allDay` is derived (`time == null`); check `event.time != null` to render time rows — the persisted `all_day` column is a write-only mirror.
- Categories are **data-driven (v15), not an enum**: `CalendarEvent.categoryId` is a `String`. Resolve icon via `CalendarCategories.iconFor(event)` (per-event override wins, else category icon) and tint via `CalendarCategories.resolve(event.categoryId).color`. Unknown ids fall back to `other` — never throw. Built-ins keep stable ids equal to the old enum names (`'gym'`, …) and cannot be deleted; `CategoryService.deleteCategory` reassigns events to `other` in a transaction.
- The calendar filter is a hidden-id set (`CalendarPageLoaded.hiddenCategoryIds`, empty = show all) via `ChangeHiddenCategories` — new categories are visible by default.
- Never mutate `public_holidays` outside `PublicHolidayService` — the static `PublicHolidays._cache` is only rebuilt by `_load()`; direct DAO writes desync the sync facade.
- Date normalization anywhere in calendar code: `DateTime.utc(y, m, d)` to match `CalendarEvent.occursOn`. All occurrence math is O(1) modular arithmetic on date-only UTC — no per-day allocation, no DST-sensitive math.
- Resolve a linked note (`event.noteId`) via `NoteRepository.getNotesByIds([id])`, **not** `getNoteById` — the former filters soft deletes so you show `eventLinkedNoteMissing` instead of a ghost note.
- Navigation: `AppNavigator.toCalendar` stays a normal `push` (previous page remains on the stack). Calendar options live on `CalendarSettingsPage` (gear in the calendar app bar), never on `ControlsSettingsPage`.
- No generic `AppLocalizations.byKey` — pick localized strings via sealed `switch` on the enum/rule type.

## Event editor sheet (`lib/widgets/event_editor_sheet.dart`)

- `FractionallySizedBox(heightFactor: 0.92)`; **inline header row** `close | centered title | FilledButton(Save)` — never a bottom action bar with dividers. Delete (when editing) lives at the bottom of the scrollable body.
- Category selection is a `_PickerTile` → `CategoryPickerSheet` (returns the category **id**), never a chip Wrap. Recurrence frequency stays as `ChoiceChip`s.
- Preserve: `_initRecurrenceFrom` sealed rehydration; `_buildRule()` wraps weekday sets in `Set.unmodifiable`; `_canSave` = title non-empty AND (not weekly OR weekdays non-empty); `_pickDate` re-anchors weekdays only when the previous selection was the implicit default; `!mounted` early-returns after awaits; on edit use `copyWith(... clearIconKey: _iconKey == null)`.
- Interval stepper (`_IntervalStepper`) appears only for daily/weekly/monthly/yearly, clamped 1–99. Picking the birthday built-in on a still-one-time event pre-fills yearly recurrence (never overrides a user-configured rule).

## Recurrence semantics (keep consistent)

One-time = start only. Daily/weekly/monthly/yearly carry `interval` (weekly uses a fixed Monday-aligned week grid, `_weekEpoch = 2000-01-03`); short months and non-leap Feb 29 are silently skipped. Workdays = Mon–Fri AND not a public holiday (semantic — do not relax). Weekends = Sat–Sun. Holidays-only = `PublicHolidays.isHoliday(day)`. Every rule guards `day.isBefore(start)` first; `endDate` is enforced at the model layer in `occursOn`.

## Change-set recipes

- **New persisted event field**: Drift table + migration (idempotent, `PRAGMA table_info` guard) → DAO → `CalendarEventService` mapping → model `copyWith` (+ `clearX` flag if nullable) → editor UI → backup export/import → `dart run build_runner build --delete-conflicting-outputs` → ARB keys ×3 + `flutter gen-l10n`.
- **New holiday profile**: `HolidayProfile` enum value → `profileNameOf` switch → `holidayProfile<Name>` ARB trio → `_<name>Seeds(year)` builder dispatched from `_buildSeeds`; new holidays also need a `PublicHoliday` enum value + `nameOf` branch + `publicHoliday<Name>` ARB trio. The settings dropdown auto-enumerates. No schema change.
- **New calendar setting**: `CalendarSettingsPage` (mirror `_buildSectionCard` / `_buildSliderTile` helpers) + `SettingsService` getter/setter + `SettingsKeys` key + reset-to-defaults. Count sliders show bare numbers; only time-based sliders get an `s` suffix.

Backup: `BackupService` round-trips `calendar_categories`, `calendar_events`, `public_holidays` (backup version 4; categories import **before** events). Old backups must keep importing.
