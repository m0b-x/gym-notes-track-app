# Calendar & Events — Feature Reference

A deep, implementation-aware description of the calendar/events subsystem in
`gym_notes_track_app` as of schema **v11**. This document focuses on the
**events** feature plus the **public-holiday** subsystem it depends on.
Everything below is grounded in the actual code paths in
[lib/](../lib/) — file references are linked.

---

## 1. Product purpose

The calendar lives inside an offline-first gym-progress tracker. It is **not**
a general-purpose calendar (no meetings, no invites, no sync). Its purpose is
to let a lifter:

- **Plan training** — schedule recurring sessions (3×/week, every workday,
  weekends only, etc.) so the calendar surfaces "what should I do today?".
- **Annotate the year** — mark holidays, competitions, deload windows,
  measurements, rest days.
- **Stay context-rich on a single device** — every event is local SQLite,
  with no account, no cloud, and survives device wipe via the JSON backup.

Design principle: the calendar must be useful **the second the user installs
the app**, with zero setup. That is why public holidays are pre-seeded and
why one-time events are the default.

---

## 2. Domain model

### 2.1 [`CalendarEvent`](../lib/models/calendar_event.dart)

The single value object representing an event. It is `Equatable` and
immutable; mutation is done through `copyWith`.

| Field           | Type                       | Notes                                                                                              |
| --------------- | -------------------------- | -------------------------------------------------------------------------------------------------- |
| `id`            | `String`                   | UUID v4, generated client-side. Stable across edits.                                               |
| `title`         | `String`                   | User-entered, ≤ 120 chars (UI-enforced). Trimmed on save.                                          |
| `category`      | `CalendarEventCategory`    | Closed enum (gym, cardio, rest, holiday, competition, measurement, other). Drives default colors. |
| `startDate`     | `DateTime` (date-only UTC) | Anchors recurrence math. For one-time events this *is* the event date.                             |
| `allDay`        | `bool`                     | Reserved at `true` until time-of-day events ship (see §10).                                        |
| `rule`          | `RecurrenceRule`           | Sealed hierarchy — see §4.                                                                         |
| `endDate`       | `DateTime?` (date-only UTC) | Optional inclusive upper bound for recurring rules. `null` = "no end".                            |
| `iconKey`       | `String?`                  | Key into `CalendarIcons.palette`. `null` = use category default.                                  |

`CalendarEvent.occursOn(day)` is the central query. It:

1. Normalizes both `startDate` and `day` to date-only UTC.
2. Short-circuits to `false` if `endDate != null && target.isAfter(endDateUtc)`
   (the **Until** bound, applied at the model layer because it is orthogonal to
   the rule shape).
3. Otherwise delegates to `rule.occursOn(target, start)`.

### 2.2 [`CalendarEventCategory`](../lib/models/calendar_event.dart)

Closed enum. Each value maps to:

- A localized label (`l10n.eventCategoryGym`, etc.).
- A default color (see [`CalendarColors`](../lib/constants/calendar_colors.dart)).
- A default icon (see [`CalendarIcons`](../lib/constants/calendar_icons.dart)).

The category is a hard-coded vocabulary — adding one is a 4-touch change
(enum + l10n × 3 ARBs + colors + icons). Intentional: keeps the calendar
visually coherent.

---

## 3. Recurrence engine — [`RecurrenceRule`](../lib/models/recurrence_rule.dart)

A sealed-class hierarchy. Each subtype implements a pure
`bool occursOn(DateTime target, DateTime start)` where both arguments are
date-only UTC.

| Rule                          | Semantics                                                              |
| ----------------------------- | ---------------------------------------------------------------------- |
| `OneTimeRecurrence`           | Occurs iff `target == start`.                                          |
| `DailyRecurrence`             | Occurs iff `target >= start`.                                          |
| `WeeklyRecurrence(weekdays)`  | Occurs iff `target >= start && weekdays.contains(target.weekday)`.    |
| `MonthlyRecurrence`           | Occurs iff `target.day == start.day` (clamped — Feb 30 → no occurrence). |
| `YearlyRecurrence`            | Occurs iff `target.month == start.month && target.day == start.day` (Feb 29 in non-leap years → skip). |
| `WorkdaysRecurrence`          | Occurs iff `target >= start`, weekday is Mon–Fri, and **not** a public holiday. |
| `WeekendsRecurrence`          | Occurs iff `target >= start` and weekday is Sat/Sun.                    |
| `PublicHolidaysOnlyRecurrence`| Occurs iff `target >= start` and `PublicHolidays.isHoliday(target)`.    |

### 3.1 Persistence shape

Rules serialize as `(ruleKind: String, rulePayload: String?)`. Only `Weekly`
uses payload (`{"weekdays":[1,3,5]}`). All other rules persist with a `null`
payload. New rule kinds add a string constant to `CalendarEventService`'s
`_kXxx` set and a case to `_decodeRule` / `_ruleKind`.

The split-column representation (kind + JSON payload) is deliberately more
forgiving than a single JSON blob: corrupt payloads still let the rule kind
through, and adding a new kind is a no-migration change.

### 3.2 Until / `endDate` bound

Added in schema v11. Lives **on `CalendarEvent`, not `RecurrenceRule`**, because
it is orthogonal to every rule shape and would otherwise need to be wired into
each subtype's `occursOn`. The wrapper at `CalendarEvent.occursOn` keeps the
rule subclasses pure and easy to test.

UI rules:

- Editor only shows the "Ends on" picker when `_mode == recurring`.
- `firstDate` of the picker is clamped to the event's start date.
- If the user pushes the start past the existing end date, the end date is
  silently dropped (rather than producing an event with zero occurrences).
- `_onSave` writes `effectiveEnd = recurring ? _endDate : null`, so a
  one-time event can never carry a stale end date.

---

## 4. Public-holiday subsystem

The calendar engine consults
[`PublicHolidays.isHoliday(day)`](../lib/constants/public_holidays.dart) for
two recurrence rules (`WorkdaysRecurrence`, `PublicHolidaysOnlyRecurrence`)
and also for visual rendering on calendar tiles.

### 4.1 Seed window

[`PublicHolidayService`](../lib/services/public_holiday_service.dart) computes
a **6-year window** centered on the current year and ensures every built-in
holiday for those years is present in the `public_holidays` table via
`insertIfMissing` (idempotent). This includes movable feasts via the
**Meeus/Jones/Butcher** Easter algorithm, then deriving Good Friday, Easter
Monday, Ascension, Pentecost, Whit Monday from Easter Sunday.

The cache built on each load is published to a static
`PublicHolidays._cache`, allowing the rest of the app to query holiday status
synchronously (no `await`s in calendar tile builders).

### 4.2 Custom holidays

Users may add their own holidays. They live in the same `public_holidays`
table with `name_key = 'custom'` (the `kCustomPublicHolidayKey` sentinel)
and a non-null `custom_label`. They are otherwise indistinguishable from
built-ins for the purposes of recurrence and rendering.

### 4.3 Out-of-window fallback

`PublicHolidays.holidayOn` first consults the cache. If the queried year is
**outside** the seeded window, it falls back to a static fixed-date map
(New Year, Epiphany, Labour Day, Assumption, All Saints, Christmas Eve/Day,
Boxing Day, NYE). This means `isHoliday(2099-12-25)` still returns true even
though no row exists for that year. **Movable feasts have no fallback** —
querying Good Friday in 2099 returns `false`. Acceptable: the seeded window
covers anything a real user will look at; the fallback is for tests and
edge-of-rendering corner cases.

### 4.4 Deleting a built-in for a single year

Users can suppress a built-in (e.g., they don't observe Labour Day). Inside
the seeded window the cache is the source of truth — a missing entry stays
missing. Outside the window the fixed-date fallback re-introduces it.

> **Caveat:** the seeder runs every app start with `insertIfMissing`. A
> deletion suppresses for the current run, but on restart the seeder
> re-adds it. To make deletions sticky you'd need a tombstone column; not
> present today.

---

## 5. Persistence layer

### 5.1 Schema (v11)

#### [`CalendarEvents`](../lib/database/tables/calendar_events_table.dart)

| Column              | Type     | Null | Notes                                                                |
| ------------------- | -------- | ---- | -------------------------------------------------------------------- |
| `id`                | TEXT     | PK   | UUID v4.                                                             |
| `title`             | TEXT     | NN   | ≤ 120 chars enforced in UI.                                          |
| `category`          | TEXT     | NN   | Stores enum `name`, decoded with fallback to `other`.                |
| `start_date`        | INTEGER  | NN   | Epoch ms. Date-only UTC by convention.                               |
| `all_day`           | INTEGER  | NN   | Boolean. Default 1.                                                  |
| `icon_key`          | TEXT     | YES  | Optional icon override.                                              |
| `rule_kind`         | TEXT     | NN   | `oneTime` / `daily` / `weekly` / `monthly` / `yearly` / `workdays` / `weekends` / `holidaysOnly`. |
| `rule_payload`      | TEXT     | YES  | JSON; only weekly populates it.                                      |
| `end_date`          | INTEGER  | YES  | **v11**. Inclusive Until bound (epoch ms).                           |
| `start_minute`      | INTEGER  | YES  | **v11**, reserved. Future time-of-day support.                       |
| `duration_minutes`  | INTEGER  | YES  | **v11**, reserved. Future time-of-day support.                       |
| `created_at`        | INTEGER  | NN   | Epoch ms (UTC).                                                      |
| `updated_at`        | INTEGER  | NN   | Epoch ms (UTC).                                                      |

#### [`PublicHolidaysTable`](../lib/database/tables/public_holidays_table.dart)

| Column         | Type     | Null | Notes                                                  |
| -------------- | -------- | ---- | ------------------------------------------------------ |
| `date`         | INTEGER  | PK   | Epoch ms at UTC midnight. One row per holiday-day.     |
| `name_key`     | TEXT     | NN   | Built-in enum name or `custom`.                        |
| `custom_label` | TEXT     | YES  | Required iff `name_key == 'custom'`.                   |

### 5.2 Migrations

[`DatabaseMigrations`](../lib/database/migrations/database_migrations.dart)
follows the project rule that migration SQL is **frozen at the migration's
moment in time** — never relies on the live Drift declaration. This avoids
regressions when columns are added later.

Calendar-relevant steps:

- **v9 → v10**: Creates `calendar_events` and `public_holidays` with raw
  `CREATE TABLE` and adds the calendar indexes.
- **v10 → v11**: Adds the three nullable columns
  (`end_date`, `start_minute`, `duration_minutes`) via `ALTER TABLE … ADD
  COLUMN`. Idempotent: introspects `PRAGMA table_info(calendar_events)` and
  skips any column already present.

Fresh installs use `m.createAll()` from the live Drift declaration, which
already includes the v11 columns — no migration runs.

### 5.3 [`CalendarEventDao`](../lib/database/daos/calendar_event_dao.dart)

Thin Drift DAO: `getAll`, `upsert`, `deleteById`, `deleteAll`. No
recurrence-aware queries — recurrence math is always done in Dart against
the in-memory cache.

### 5.4 [`CalendarEventService`](../lib/services/calendar_event_service.dart)

Singleton (registered with `DatabaseLifecycle` so it resets when the user
switches DBs). Responsibilities:

- **Load on init** — pulls all rows once into `List<CalendarEvent> _cache`.
- **Synchronous reads** — `events` getter returns the unmodifiable cache so
  `CalendarBloc.eventsForDay` runs O(N) per day with no async hops.
- **Mutations** — `upsert` and `deleteById` go through the DAO and then
  patch the in-memory cache so the calendar UI sees the change instantly.
- **Date-only normalization** — `startDate` and `endDate` are forced through
  `_dateOnlyUtc` on every write so equality / ordering is timezone-stable.
- **Backup parity** — `exportData()` and `importData()` mirror the row shape
  for inclusion in the app-global backup (see §7).
- **Rule serialization** — kind/payload codec, isolated in this service so
  the rest of the app stays in domain types.

### 5.5 [`PublicHolidayService`](../lib/services/public_holiday_service.dart)

Companion singleton:

- **Seeds** the 6-year window on first launch and on every subsequent launch
  via `insertIfMissing`.
- **Publishes** a `Map<DateTime, PublicHolidayInfo>` to
  `PublicHolidays._cache` plus the inclusive `(minYear, maxYear)` window.
- **Mutates** via `addCustom` (writes `name_key=custom` rows) and
  `removeOn(date)` (suppresses any holiday on that day).
- **Backup parity** — `exportData()` / `importData()` round-trip every row
  shape verbatim (see §7).

---

## 6. UI surfaces

### 6.1 Calendar page

Backed by `table_calendar 3.2.0`. Tile rendering consults
`PublicHolidays.holidayOn` for holiday badges and
`CalendarBloc.eventsForDay(day)` to draw event chips.
`CalendarBloc.eventsForDay` is synchronous — it iterates the cached event
list and calls `event.occursOn(day)`.

### 6.2 Day list

Tapping a date opens a list of that day's events. Each tile is colored by
category, optionally overridden with a custom icon. Tapping an event opens
the editor in **edit** mode.

### 6.3 [`EventEditorSheet`](../lib/widgets/event_editor_sheet.dart)

A bottom-sheet form (`heightFactor: 0.92`). Sections, top-to-bottom:

1. **Title** — single-line `TextField`, autofocus on add, `maxLength: 120`.
2. **Type** — category picker (`CategoryPickerSheet`).
3. **Icon** — icon picker with reset-to-default action.
4. **Date** — `showDatePicker` ±20 years.
5. **Repeat mode** — segmented control `oneTime` / `recurring`.
6. **(if recurring) Frequency** — choice chips for the eight rule kinds.
7. **(if weekly) Weekdays** — Mon–Sun filter chips, validation hint when empty.
8. **(if recurring) Ends on** — optional Until date picker. Defaults to
   "Never ends"; tapping picks a date; the trailing × button clears it.
9. **(if editing) Delete** — destructive button with a confirmation dialog.

Header: inline cancel + save in the same row as the title — no detached
bottom action bar.

`_canSave` requires a non-empty title and, for weekly, at least one weekday.

### 6.4 Validation rules currently enforced by the editor

- Title trim non-empty.
- Weekly weekday set non-empty.
- Until date ≥ start date (clamped via `firstDate`).
- Start date moving forward past Until silently clears Until.

---

## 7. Backup & restore

The app-global backup is owned by
[`BackupService`](../lib/services/backup_service.dart). It serializes every
persisted store into a single JSON document with a `version` number.

**Backup version 3** (introduced when calendar parity was added) includes:

```jsonc
{
  "version": 3,
  "calendarEvents": [
    {
      "id": "…", "title": "…", "category": "gym",
      "startDateMs": 1717113600000,
      "allDay": true, "iconKey": null,
      "ruleKind": "weekly", "rulePayload": "{\"weekdays\":[1,3,5]}",
      "endDateMs": null,
      "startMinute": null, "durationMinutes": null,
      "createdAtMs": 1717100000000, "updatedAtMs": 1717100000000
    }
  ],
  "publicHolidays": [
    { "dateMs": 1735689600000, "nameKey": "newYear", "customLabel": null },
    { "dateMs": 1735776000000, "nameKey": "custom",  "customLabel": "Birthday" }
  ]
}
```

### 7.1 Round-trip discipline

- **Calendar events** mirror the row shape exactly. Reserved
  `startMinute` / `durationMinutes` are written even though application
  code doesn't set them — so a future version that introduces time-of-day
  events can still import an old backup without losing data.
- **Public holidays** mirror the row shape exactly. Custom rows survive
  verbatim. Built-ins are also dumped, but the seeder will re-fill any
  missing built-in for the seeded window on next start.

### 7.2 Backward compatibility on import

`BackupService.importFromJson()` reads new keys with `data['…'] as List?`,
so v1/v2 backups (no `calendarEvents` / `publicHolidays`) load cleanly and
leave existing calendar/holiday data in place. A v3 backup loaded by an
older binary simply ignores the unknown keys.

### 7.3 Behavior the user should know

- Restoring a v3 backup **deletes all** existing calendar events and
  holidays first, then inserts the backup contents — same destructive
  pattern used by other restore paths.
- After restore, the public-holiday seeder runs again on next start and
  re-adds any built-in row missing from the seeded window. **A built-in
  the user had deleted will come back after restore.** This is a known
  limitation; fixing it requires a tombstone column.

---

## 8. Concurrency & threading

- All database operations go through Drift, which serializes I/O on a
  background isolate.
- The in-memory caches (`CalendarEventService._cache`,
  `PublicHolidays._cache`) are mutated only on the UI isolate after a write
  resolves, so there is no read/write race.
- `CalendarBloc.eventsForDay` is synchronous and called from build methods,
  which is safe because the cache is `List.unmodifiable(...)`.

---

## 9. Localization

All user-visible strings live in the three ARB files
([app_en.arb](../lib/l10n/app_en.arb),
[app_de.arb](../lib/l10n/app_de.arb),
[app_ro.arb](../lib/l10n/app_ro.arb)).

Calendar-relevant key families:

- `eventCategory*` — category labels.
- `recurrence*` — rule kind labels and the formatted weekday list.
- `publicHoliday*` — named built-in holidays.
- `eventTitle`, `eventType`, `eventDate`, `repeatMode`, `repeatOnce`,
  `repeatRecurring`, `frequency`, `weekdays`, `weeklyDaysHint`, `startsOn`,
  `pickCategory`, `pickIcon`, `iconLabel`, `iconCustom`, `iconDefault`,
  `resetToDefault`.
- **v11 additions** — `eventUntilLabel`, `eventUntilNone`, `eventUntilHint`.

After editing ARBs, re-run `flutter gen-l10n` to refresh
`AppLocalizations`.

---

## 10. Reserved / forward-compat surfaces

### 10.1 `start_minute` / `duration_minutes`

Reserved in schema v11 to allow time-of-day events without another
migration. Today:

- Drift table declares them.
- DAO writes `Value.absent()` so they default to `NULL`.
- Backup round-trips them (so a future binary that emits non-null values
  doesn't lose them in a v3 backup).
- No application code, no UI surface, no model fields.

When time-of-day is implemented:

1. Add `startMinute` / `durationMinutes` to `CalendarEvent`.
2. Wire them through `_eventToCompanion` and `_rowToEvent`.
3. Add a time picker section to the editor sheet (only when
   `allDay == false`).
4. Surface them in tile rendering and in the day list.
5. No new migration needed — the columns already exist.

### 10.2 `allDay`

Currently always `true`. It exists as a column from v10 because
time-of-day support was anticipated.

---

## 11. Known limitations

| Limitation                                                         | Impact   | Mitigation                                                                             |
| ------------------------------------------------------------------ | -------- | -------------------------------------------------------------------------------------- |
| Time-of-day events not implemented                                 | Medium   | Reserved columns; ship when product asks.                                             |
| No interval > 1 (e.g., "every 2 weeks")                            | Medium   | `RecurrenceRule` subtypes would need an `interval` field plus modular arithmetic.     |
| No skip-this-occurrence (exceptions)                                | Medium   | Would need an `event_exceptions(event_id, date)` table; checked in `occursOn`.        |
| No "mark done" / completion log                                    | Medium   | Would need a `completions(event_id, date)` table; surfaces as a check on the day card. |
| No event ↔ note link                                               | High for this app | Would need a nullable `note_id` column on `calendar_events`.                          |
| Built-in holiday deletions do not survive backup restore           | Low      | Would need a `suppressed` tombstone column.                                            |
| No country/region selector for built-in holidays                   | Low      | Today's seed is implicitly Western-Christian.                                         |
| Movable feasts have no out-of-window fallback                      | Low      | Acceptable; users only see seeded window.                                              |
| No reminders / notifications                                       | Medium   | Requires platform plugin work; intentionally deferred.                                |
| Recurrence math has no automated test coverage                     | Medium   | Add tests before introducing intervals or exceptions.                                  |

---

## 12. File map (quick reference)

| Concern                  | Path                                                                              |
| ------------------------ | --------------------------------------------------------------------------------- |
| Domain model             | [lib/models/calendar_event.dart](../lib/models/calendar_event.dart)               |
| Recurrence rules         | [lib/models/recurrence_rule.dart](../lib/models/recurrence_rule.dart)             |
| Holiday enum + facade    | [lib/constants/public_holidays.dart](../lib/constants/public_holidays.dart)       |
| Drift table (events)     | [lib/database/tables/calendar_events_table.dart](../lib/database/tables/calendar_events_table.dart) |
| Drift table (holidays)   | [lib/database/tables/public_holidays_table.dart](../lib/database/tables/public_holidays_table.dart) |
| DAO (events)             | [lib/database/daos/calendar_event_dao.dart](../lib/database/daos/calendar_event_dao.dart) |
| DAO (holidays)           | [lib/database/daos/public_holiday_dao.dart](../lib/database/daos/public_holiday_dao.dart) |
| Schema constants         | [lib/database/migrations/database_schema.dart](../lib/database/migrations/database_schema.dart) |
| Migrations               | [lib/database/migrations/database_migrations.dart](../lib/database/migrations/database_migrations.dart) |
| Calendar indexes         | [lib/database/migrations/database_indexes.dart](../lib/database/migrations/database_indexes.dart) |
| Service (events)         | [lib/services/calendar_event_service.dart](../lib/services/calendar_event_service.dart) |
| Service (holidays)       | [lib/services/public_holiday_service.dart](../lib/services/public_holiday_service.dart) |
| Backup integration       | [lib/services/backup_service.dart](../lib/services/backup_service.dart)           |
| Editor UI                | [lib/widgets/event_editor_sheet.dart](../lib/widgets/event_editor_sheet.dart)     |
| Category icons & colors  | [lib/constants/calendar_icons.dart](../lib/constants/calendar_icons.dart), [lib/constants/calendar_colors.dart](../lib/constants/calendar_colors.dart) |
| L10n                     | [lib/l10n/app_en.arb](../lib/l10n/app_en.arb), [lib/l10n/app_de.arb](../lib/l10n/app_de.arb), [lib/l10n/app_ro.arb](../lib/l10n/app_ro.arb) |
