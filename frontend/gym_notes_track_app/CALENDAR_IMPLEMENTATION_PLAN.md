# Calendar Feature – Implementation Plan (AI Spec)

> Audience: an AI coding agent working in `gym_notes_track_app`.
> Read [COPILOT_CONTEXT.md](COPILOT_CONTEXT.md) and the `gym-notes-context` skill before starting. Follow every non-negotiable rule there (l10n, Drift migrations, build_runner, no unsolicited tests/comments, soft deletes, CRDT fields, backup compatibility).

---

## 1. Goal

Add an offline-first **Calendar** feature to Gym Notes that lets the user track gym-related and personal **Events** (workouts, deload weeks, public holidays, competitions, rest days, etc.) directly inside the app.

Requirements (from user):

1. New entry in the global vertical app drawer (`lib/widgets/app_drawer.dart`) labeled **Calendar**.
2. Navigating to the calendar must **remember the previous page** so the user can navigate back to exactly where they came from.
3. The calendar must support both **one-time** and **recurring** events ("Events").
4. Events must persist in **SQLite (Drift)** following the existing CRDT-style schema.
5. Use the [`table_calendar`](https://pub.dev/packages/table_calendar) package (latest `^3.2.0`).
6. Integrate cleanly with the existing architecture (BLoC → Service → Repository → DAO → Drift) and with backup/restore.

Non-goals (do **not** implement unless asked later):

- Push notifications / reminders (mention only as future work).
- Cloud sync (schema must remain sync-ready, but no sync code).
- Linking events to notes/folders/counters (mention as future work).
- Multi-day drag-to-create or rich event editor with attachments.

---

## 2. UX Specification

### 2.1 Drawer entry

In `AppDrawer._buildMenuItem` list (after **Counter management**, before the developer/divider block):

- `icon: Icons.calendar_month_rounded`
- `title: AppLocalizations.of(context)!.calendar`
- `subtitle: AppLocalizations.of(context)!.calendarDesc` (suggest: "Plan gym sessions and events")
- `onTap`: close drawer, then `AppNavigator.toCalendar(context)` (see §6.2).

### 2.2 Calendar page layout

File: `lib/pages/calendar_page.dart`

```
AppBar
 ├─ leading: back button (system) → pops to previous page
 ├─ title:   localized "Calendar"
 └─ actions: [today button (icon: today_rounded), format toggle (month/2-week/week)]

Body (Column)
 ├─ TableCalendar<CalendarEvent>
 │    firstDay:  DateTime.utc(2000, 1, 1)
 │    lastDay:   DateTime.utc(2100, 12, 31)
 │    focusedDay: _focusedDay
 │    selectedDayPredicate: isSameDay(_selectedDay, d)
 │    onDaySelected: dispatch SelectCalendarDay
 │    onPageChanged: just update _focusedDay (no setState in callback)
 │    onFormatChanged: persist via SettingsService key `calendar_format`
 │    eventLoader: (day) => bloc.eventsForDay(day)  // pure, O(1) lookup
 │    startingDayOfWeek: from locale (Monday for de/ro, locale default for en)
 │    locale: AppLocalizations.of(context)!.localeName
 │    calendarStyle: themed to Material 3 colorScheme
 │    calendarBuilders: markerBuilder to color-code event categories
 │
 ├─ Divider
 │
 └─ Expanded(
       child: ListView of CalendarEvent cards for _selectedDay
              (empty state widget with "+" hint when none)
    )

FloatingActionButton
 ├─ icon: add_rounded
 ├─ tooltip: localized "Add event"
 └─ onPressed: open EventEditorSheet for _selectedDay (default date)
```

Empty state: centered icon + localized message (`calendarNoEventsForDay`).

### 2.3 Event card

Compact ListTile-style card:

- Leading: small color dot from `CalendarEvent.category` palette.
- Title: `event.title`.
- Subtitle (single line, ellipsis):
  - All-day event: localized `allDay`.
  - Timed event: `HH:mm` (locale-aware via `intl`).
  - Recurring: append "·" + recurrence summary (e.g. "Weekly · Mon, Wed").
- Trailing: PopupMenuButton with: **Edit**, **Duplicate**, **Delete** (Delete is destructive, requires `showConfirmDeleteDialog` from `app_dialogs.dart`).
- Tap: open editor sheet pre-filled.
- Long-press: same as Delete (consistent with rest of app).

### 2.4 Event editor (bottom sheet)

File: `lib/widgets/event_editor_sheet.dart` (modal bottom sheet, scrollable).

Fields:

1. **Title** – required, max 120 chars, autofocus on create.
2. **Category** – chip selector with predefined types: `gym`, `cardio`, `rest`, `holiday`, `competition`, `measurement`, `other`. Stored as enum (`CalendarEventCategory`).
3. **All-day toggle** – when off, show start/end time pickers.
4. **Date** – `showDatePicker` (single date for non-recurring; for recurring this is the `startDate`).
5. **Time range** (only if not all-day) – two `showTimePicker`s for start/end.
6. **Recurrence section** – dropdown: `None`, `Daily`, `Weekly`, `Monthly`, `Yearly`, `Custom (weekdays)`.
   - When `Weekly` or `Custom (weekdays)`: show weekday chip selector (Mon–Sun, multi-select).
   - When recurrence ≠ `None`: optional "Ends" sub-section: `Never`, `On date` (date picker), `After N occurrences` (number field 1–999).
7. **Notes** (optional) – multi-line `TextField`, max 2000 chars (NOT markdown – plain text in v1; reuse markdown editor is future work).

Footer row: `Cancel` (text button) + `Save` (filled button, disabled until title is non-empty).

Validation messages must be localized.

### 2.5 Format & first-day persistence

- `calendar_format` (`month` / `twoWeeks` / `week`) saved via `SettingsService` after `onFormatChanged`.
- `calendar_starting_day_of_week` ("monday" / "sunday" / "locale") in settings page (Calendar settings entry – optional v1.1).

---

## 3. Recurrence Model

Keep recurrence representation **simple and self-contained**. Do **not** add `rrule` package; manual expansion is enough for the supported rules and avoids dependency churn.

```dart
enum CalendarRecurrenceFrequency { none, daily, weekly, monthly, yearly }

class CalendarRecurrenceRule {
  final CalendarRecurrenceFrequency frequency;
  final int interval;            // every N (days/weeks/months/years). Default 1.
  final List<int> byWeekday;     // 1=Mon..7=Sun. Only used when frequency==weekly.
  final DateTime? until;         // inclusive end date (UTC, date-only).
  final int? count;              // OR ends after N occurrences (mutually exclusive with until).
}
```

Persist as a single TEXT column `recurrence_json` (nullable). When null → one-time event.

### 3.1 Expansion algorithm

Implemented in `CalendarRecurrenceExpander` (pure Dart, no Flutter deps, lives in `lib/services/calendar_recurrence_expander.dart`):

```text
List<DateTime> occurrencesInRange(CalendarEvent event, DateTime rangeStart, DateTime rangeEnd)
```

Rules:

- All dates are treated as **date-only UTC** (use `DateTime.utc(y, m, d)`).
- If `event.recurrence == null` → return `[event.startDate]` if within range.
- `frequency.daily`: step `interval` days from `startDate`.
- `frequency.weekly`:
  - If `byWeekday` is empty → step `interval` weeks on the original weekday.
  - Else → for each `byWeekday` produce dates within current week, then jump `interval` weeks.
- `frequency.monthly`: same day-of-month each `interval` months. If day doesn't exist (e.g. 31 Feb) → skip.
- `frequency.yearly`: same month/day each `interval` years. Feb 29 → skip non-leap years.
- Stop when `until` is exceeded or `count` occurrences emitted.
- Always clip output to `[rangeStart, rangeEnd]`.

Edge cases the agent **must** handle:

- `interval < 1` → throw `ArgumentError` (validate in the editor before save).
- `count == 0` → throw `ArgumentError`.
- `until` before `startDate` → empty list (validate in editor: show error).
- Iteration cap: hard-stop at 5000 generated dates to prevent runaway loops on bad data; log via `debugPrint`.

### 3.2 In-memory event index for `eventLoader`

`eventLoader` is called **on every visible day** during calendar render. It MUST be O(1) lookup.

Implementation in `CalendarBloc`:

- Maintain `Map<DateTime, List<CalendarEvent>> _eventsByDay` keyed by date-only UTC.
- Rebuild whenever events change OR when `_focusedDay` page changes outside a precomputed window.
- Precompute a rolling window of **±90 days** around `_focusedDay`. On `onPageChanged` outside the window, expand by another ±90 days asynchronously and emit a new state.
- Use `LinkedHashMap` with `isSameDay` equality / `getHashCode` from `table_calendar` utils so lookups by `DateTime` with arbitrary time component still match.

```dart
final _eventsByDay = LinkedHashMap<DateTime, List<CalendarEvent>>(
  equals: isSameDay,
  hashCode: (d) => d.day * 1000000 + d.month * 10000 + d.year,
);
```

---

## 4. Data Model (Drift)

### 4.1 New table

File: `lib/database/tables/calendar_events_table.dart`

```dart
import 'package:drift/drift.dart';

@DataClassName('CalendarEventRow')
class CalendarEvents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get notes => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('other'))();

  // Date / time (UTC). For all-day events startTime/endTime are null.
  DateTimeColumn get startDate => dateTime()();
  IntColumn get startMinuteOfDay => integer().nullable()();   // 0..1439
  IntColumn get endMinuteOfDay => integer().nullable()();     // 0..1439, > start
  BoolColumn get allDay => boolean().withDefault(const Constant(true))();

  // Recurrence (null = one-time)
  TextColumn get recurrenceJson => text().nullable()();

  // Display
  IntColumn get colorArgb => integer().nullable()();          // optional custom color override

  // CRDT / sync metadata (mirrors folders/notes)
  TextColumn get hlcTimestamp => text()();
  TextColumn get deviceId => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### 4.2 Schema version bump

In `lib/database/migrations/database_schema.dart`:

```dart
abstract class DatabaseSchema {
  static const int currentVersion = 10; // bumped from 9
  // ...existing v1..v9...
  static const int v10CalendarEvents = 10;
}
```

In `lib/database/migrations/database_migrations.dart`:

```dart
Migration(
  fromVersion: DatabaseSchema.v9NameUniquenessIndexes,
  toVersion: DatabaseSchema.v10CalendarEvents,
  migrate: _migrateV9ToV10,
),
// ...
Future<void> _migrateV9ToV10(Migrator m, GeneratedDatabase db) async {
  await m.createTable(_db.calendarEvents);
  await _db.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_cal_events_start ON calendar_events(start_date) WHERE is_deleted = 0',
  );
  await _db.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_cal_events_recurring ON calendar_events(recurrence_json) WHERE recurrence_json IS NOT NULL AND is_deleted = 0',
  );
}
```

Add the new table + DAO references to the `@DriftDatabase(...)` annotation in `lib/database/database.dart`.

After table changes, run:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

### 4.3 DAO

File: `lib/database/daos/calendar_event_dao.dart`

```dart
@DriftAccessor(tables: [CalendarEvents])
class CalendarEventDao extends DatabaseAccessor<AppDatabase> with _$CalendarEventDaoMixin {
  CalendarEventDao(super.db);

  Future<List<CalendarEventRow>> getAll({bool includeDeleted = false}) { ... }

  // Returns rows that *may* have an occurrence in [start, end]:
  //   - one-time: startDate within [start, end]
  //   - recurring: startDate <= end AND (recurrence has no until OR until >= start)
  Future<List<CalendarEventRow>> getRowsInRange(DateTime start, DateTime end);

  Future<CalendarEventRow?> getById(String id);
  Future<void> insert(CalendarEventsCompanion entry);
  Future<void> update(CalendarEventsCompanion entry);
  Future<void> softDelete(String id, {required String hlcTimestamp});
  Future<void> hardDelete(String id);                  // used only by import-replace flow
}
```

Important: **soft-delete by default** (set `isDeleted = true`, `deletedAt = now`, bump `version`, refresh `hlcTimestamp` via `db.hlc.tick()`).

---

## 5. Model + Repository + Service

### 5.1 Model

File: `lib/models/calendar_event.dart`

```dart
class CalendarEvent extends Equatable {
  final String id;
  final String title;
  final String? notes;
  final CalendarEventCategory category;
  final DateTime startDate;          // UTC date-only
  final int? startMinuteOfDay;       // null => all-day
  final int? endMinuteOfDay;
  final bool allDay;
  final CalendarRecurrenceRule? recurrence;
  final int? colorArgb;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isRecurring => recurrence != null && recurrence!.frequency != CalendarRecurrenceFrequency.none;

  CalendarEvent copyWith({ ... });
  Map<String, dynamic> toJson();         // backup format
  factory CalendarEvent.fromJson(Map<String, dynamic> json);
  factory CalendarEvent.fromRow(CalendarEventRow row);
  CalendarEventsCompanion toCompanion();

  @override
  List<Object?> get props => [id, title, notes, category, startDate,
      startMinuteOfDay, endMinuteOfDay, allDay, recurrence, colorArgb,
      createdAt, updatedAt];
}

enum CalendarEventCategory { gym, cardio, rest, holiday, competition, measurement, other }
```

JSON keys: extend `lib/constants/json_keys.dart` with the new keys (`startDate`, `startMinuteOfDay`, `endMinuteOfDay`, `allDay`, `category`, `recurrence`, `colorArgb`, `notes`). Do **not** sprinkle string literals around.

### 5.2 Repository

File: `lib/repositories/calendar_event_repository.dart`

Wraps the DAO with:

- An in-memory cache of all non-deleted events (volume is small – typically < 1000 rows; full-load is fine).
- `Stream<List<CalendarEvent>>` exposing the cached list (use a `BehaviorSubject`-like pattern via `ValueNotifier` or existing pattern in `folder_repository`).
- Cache invalidation after every mutation (`create/update/delete`).
- All mutations stamp `updatedAt = DateTime.now()`, bump `version`, refresh `hlcTimestamp` (mirror what `FolderDao` does today).

### 5.3 Service

File: `lib/services/calendar_event_service.dart`

Single entry point used by the BLoC. Responsibilities:

- `Future<List<CalendarEvent>> loadAll()`.
- `Future<CalendarEvent> create(CalendarEvent draft)` – assigns `id = const Uuid().v4()`, sets `createdAt/updatedAt`.
- `Future<CalendarEvent> update(CalendarEvent event)`.
- `Future<void> delete(String id)` (soft).
- `Map<DateTime, List<CalendarEvent>> expandForRange(DateTime rangeStart, DateTime rangeEnd, List<CalendarEvent> source)` – delegates to `CalendarRecurrenceExpander`.

Register the service in `lib/core/di/injection.dart` (alongside `CounterService`).

---

## 6. BLoC

File: `lib/bloc/calendar/calendar_bloc.dart`, with `calendar_event.dart` (Bloc events) and `calendar_state.dart`.

### 6.1 Events

```dart
sealed class CalendarEvent extends Equatable { ... }   // pick another name to avoid clash with model:
                                                       // use CalendarBlocEvent
```

Recommended renames to avoid a clash with the `CalendarEvent` model:

- Bloc events file: `CalendarPageEvent` sealed class.
- Bloc state file: `CalendarPageState` sealed class.
- Model stays `CalendarEvent`.

Events:

- `LoadCalendarEvents`
- `SelectCalendarDay(DateTime day)`
- `ChangeFocusedMonth(DateTime focusedDay)`
- `CreateCalendarEvent(CalendarEvent draft, Completer<void>? completer)`
- `UpdateCalendarEvent(CalendarEvent event, Completer<void>? completer)`
- `DeleteCalendarEvent(String id, Completer<void>? completer)`
- `RefreshCalendarEvents`

### 6.2 State

```dart
class CalendarPageLoaded extends CalendarPageState {
  final List<CalendarEvent> allEvents;                  // raw, non-expanded
  final DateTime focusedDay;
  final DateTime selectedDay;
  final Map<DateTime, List<CalendarEvent>> expandedByDay; // pre-expanded ±90 days
  final DateTime expandedRangeStart;
  final DateTime expandedRangeEnd;
  final CalendarFormat format;
  // selectedEvents getter = expandedByDay[selectedDay] ?? const []
}
```

Also: `CalendarPageInitial`, `CalendarPageLoading`, `CalendarPageError(message)`.

Use `Equatable` and `copyWith`. Match the local style of `OptimizedFolderBloc`.

### 6.3 `eventLoader` integration

Expose a `List<CalendarEvent> eventsForDay(DateTime day)` method on the bloc that reads from the loaded state:

```dart
List<CalendarEvent> eventsForDay(DateTime day) {
  final st = state;
  if (st is! CalendarPageLoaded) return const [];
  return st.expandedByDay[DateTime.utc(day.year, day.month, day.day)] ?? const [];
}
```

`TableCalendar.eventLoader` calls this directly. No setState/dispatch happens inside `eventLoader`.

---

## 7. Navigation & "Back to previous page"

`TableCalendar` is pushed from the drawer. Since `Navigator.push` already preserves the previous route, the system back button + `AppBar`'s automatic back button already return to the previous page (folder, note editor, settings, etc.).

To make this explicit and safe:

### 7.1 New `AppNavigator` helper

In `lib/services/app_navigator.dart`:

```dart
static Future<void> toCalendar(BuildContext context) {
  return push(context, const CalendarPage());
}
```

Import `CalendarPage` at the top alongside the existing page imports.

### 7.2 Robustness rule

- **Do not** use `pushReplacement` or `popUntilFirst` when navigating to the calendar from the drawer; that would erase history.
- The drawer's `onTap` already pops the drawer with `AppNavigator.pop(context)` before pushing. Keep that order.
- `CalendarPage` must use a normal `Scaffold` with default `AppBar` (so the leading back button is auto-generated). Do **not** override `leading`.
- The page should respect Android system back gesture. `PopScope` is **not** required unless we add an unsaved-changes guard inside the editor sheet (recommended for the sheet only, not the page).

### 7.3 Unsaved-changes guard in editor sheet

Inside `EventEditorSheet`, wrap the body in a `PopScope(canPop: !_isDirty, onPopInvokedWithResult: ...)` and show `showConfirmDiscardChangesDialog` from `app_dialogs.dart` if dirty.

---

## 8. Localization

Add the following keys to **all three** ARB files (`app_en.arb`, `app_de.arb`, `app_ro.arb`) and then run `flutter gen-l10n`.

| Key | English | German | Romanian |
| --- | --- | --- | --- |
| `calendar` | Calendar | Kalender | Calendar |
| `calendarDesc` | Plan gym sessions and events | Trainings und Ereignisse planen | Planifică antrenamente și evenimente |
| `calendarNoEventsForDay` | No events for this day | Keine Ereignisse an diesem Tag | Niciun eveniment pentru această zi |
| `addEvent` | Add event | Ereignis hinzufügen | Adaugă eveniment |
| `editEvent` | Edit event | Ereignis bearbeiten | Editează evenimentul |
| `deleteEvent` | Delete event | Ereignis löschen | Șterge evenimentul |
| `duplicateEvent` | Duplicate | Duplizieren | Duplică |
| `eventTitle` | Title | Titel | Titlu |
| `eventCategory` | Category | Kategorie | Categorie |
| `eventNotes` | Notes | Notizen | Note |
| `eventAllDay` | All day | Ganztägig | Toată ziua |
| `eventStart` | Start | Beginn | Început |
| `eventEnd` | End | Ende | Sfârșit |
| `eventDate` | Date | Datum | Dată |
| `eventRecurrence` | Repeat | Wiederholen | Repetare |
| `eventRecurrenceNone` | Does not repeat | Wiederholt sich nicht | Nu se repetă |
| `eventRecurrenceDaily` | Daily | Täglich | Zilnic |
| `eventRecurrenceWeekly` | Weekly | Wöchentlich | Săptămânal |
| `eventRecurrenceMonthly` | Monthly | Monatlich | Lunar |
| `eventRecurrenceYearly` | Yearly | Jährlich | Anual |
| `eventEndsLabel` | Ends | Endet | Se termină |
| `eventEndsNever` | Never | Nie | Niciodată |
| `eventEndsOnDate` | On date | An Datum | La data |
| `eventEndsAfter` | After {count} occurrences | Nach {count} Vorkommen | După {count} apariții |
| `categoryGym` | Gym | Training | Antrenament |
| `categoryCardio` | Cardio | Cardio | Cardio |
| `categoryRest` | Rest | Ruhe | Odihnă |
| `categoryHoliday` | Holiday | Feiertag | Sărbătoare |
| `categoryCompetition` | Competition | Wettkampf | Competiție |
| `categoryMeasurement` | Measurement | Messung | Măsurătoare |
| `categoryOther` | Other | Sonstige | Altele |
| `validationTitleRequired` | Title is required | Titel ist erforderlich | Titlul este obligatoriu |
| `validationEndBeforeStart` | End time must be after start | Endzeit muss nach Beginn liegen | Sfârșitul trebuie după început |
| `validationUntilBeforeStart` | End date must be after start date | Enddatum muss nach Startdatum liegen | Data de sfârșit trebuie după cea de început |
| `eventDeletedSnackbar` | Event deleted | Ereignis gelöscht | Eveniment șters |
| `eventSavedSnackbar` | Event saved | Ereignis gespeichert | Eveniment salvat |

The `eventEndsAfter` key uses ICU `{count}` placeholder. Define its `@` metadata accordingly:

```jsonc
"@eventEndsAfter": {
  "placeholders": { "count": { "type": "int" } }
}
```

The `weekdayShort` strings (Mon/Tue/...) must come from `DateFormat.E()` via `intl`, **not** from ARB.

---

## 9. Backup / Restore Integration

`BackupService` (lib/services/backup_service.dart):

1. Bump backup `version` from `2` → `3` in `exportAllData()`.
2. Add `"calendarEvents": <List<Map<String, dynamic>>>` to the export map, serialized via `CalendarEvent.toJson`.
3. Add an import branch in `importBackup` (find it in the same file): if `version >= 3` and `calendarEvents` exists, iterate and call `CalendarEventService.importEvent(...)` (mirror the pattern of `importNote`/`importFolder` – uses caller-supplied timestamps, does **not** overwrite `createdAt/updatedAt`).
4. Backward compatibility: if importing a v2 backup, skip the section silently.

`ImportExportService` (per-note/folder archives): no changes – calendar events are not part of folder/note archives in v1.

---

## 10. Settings

Add a `CalendarSettings` section to `lib/pages/controls_settings_page.dart` (or create a separate `lib/pages/calendar_settings_page.dart` only if the section is non-trivial – v1 keeps it inside controls settings):

- "Starting day of week" – radio: `Locale default`, `Monday`, `Sunday`. Persist as `calendar_starting_day_of_week`.
- "Default calendar format" – radio: `Month`, `Two weeks`, `Week`. Persist as `calendar_format`.

Keys go through `SettingsKeys` (`lib/constants/settings_keys.dart`) – add the two new constants there.

---

## 11. Theming & Visual Polish

`TableCalendar` styling must derive from `Theme.of(context).colorScheme` (Material 3). Suggested mapping:

| Element | Source |
| --- | --- |
| `defaultTextStyle` | `theme.textTheme.bodyMedium` |
| `weekendTextStyle.color` | `colorScheme.error.withValues(alpha: 0.85)` |
| `outsideTextStyle.color` | `colorScheme.onSurface.withValues(alpha: 0.35)` |
| `todayDecoration` | circle `colorScheme.secondaryContainer` |
| `todayTextStyle.color` | `colorScheme.onSecondaryContainer` |
| `selectedDecoration` | circle `colorScheme.primary` |
| `selectedTextStyle.color` | `colorScheme.onPrimary` |
| `markerDecoration` | circle `colorScheme.tertiary` (default; overridden by `markerBuilder` for category colors) |
| `headerStyle.titleCentered` | `true` |
| `headerStyle.formatButtonVisible` | `true` (localize the three labels via `availableCalendarFormats`) |

Category color palette (constants file `lib/constants/calendar_colors.dart`):

```dart
abstract final class CalendarColors {
  static const gym         = Color(0xFF1E88E5);
  static const cardio      = Color(0xFFE53935);
  static const rest        = Color(0xFF43A047);
  static const holiday     = Color(0xFFFFB300);
  static const competition = Color(0xFF8E24AA);
  static const measurement = Color(0xFF00897B);
  static const other       = Color(0xFF757575);
}
```

`markerBuilder` returns a Row of up to 3 colored dots (one per unique category for that day, deduped).

---

## 12. `main.dart` initialization

`table_calendar` requires locale date data:

```dart
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();   // <-- new
  // ...existing init...
  runApp(const MyApp());
}
```

Place this call **before** the existing initialization chain. It is cheap and idempotent.

Also register the new BLoC at the appropriate provider level. If other BLoCs are created lazily per-page, follow that pattern: instantiate `CalendarBloc` inside `CalendarPage` via `BlocProvider(create: (_) => CalendarBloc(service: GetIt.I<CalendarEventService>())..add(const LoadCalendarEvents()))`.

---

## 13. Suggested File Tree (final)

```
lib/
  bloc/calendar/
    calendar_bloc.dart
    calendar_event.dart            // sealed CalendarPageEvent
    calendar_state.dart            // sealed CalendarPageState
  constants/
    calendar_colors.dart           // NEW
    json_keys.dart                 // extended
    settings_keys.dart             // extended
  database/
    database.dart                  // extended @DriftDatabase + import
    daos/
      calendar_event_dao.dart      // NEW
      calendar_event_dao.g.dart    // generated
    migrations/
      database_schema.dart         // version bump
      database_migrations.dart     // _migrateV9ToV10
    tables/
      calendar_events_table.dart   // NEW
  models/
    calendar_event.dart            // NEW
    calendar_recurrence_rule.dart  // NEW
  pages/
    calendar_page.dart             // NEW
  repositories/
    calendar_event_repository.dart // NEW
  services/
    app_navigator.dart             // extended (toCalendar)
    calendar_event_service.dart    // NEW
    calendar_recurrence_expander.dart // NEW
    backup_service.dart            // extended
  widgets/
    app_drawer.dart                // extended (drawer entry)
    event_editor_sheet.dart        // NEW
    calendar_event_card.dart       // NEW (optional split from page)
  l10n/
    app_en.arb, app_de.arb, app_ro.arb // extended
  main.dart                        // initializeDateFormatting()
pubspec.yaml                       // + table_calendar, intl (likely present)
```

---

## 14. `pubspec.yaml`

Add under `dependencies:`:

```yaml
table_calendar: ^3.2.0
```

`intl` is almost certainly already a transitive dependency via `flutter_localizations`; promote it to a direct dependency if not already.

Run `flutter pub get` after editing.

---

## 15. Implementation Order (recommended)

Execute in this order to keep each step independently verifiable with `dart analyze lib`:

1. **Dependencies + locale data**
   - Edit `pubspec.yaml`, run `flutter pub get`.
   - Add `initializeDateFormatting()` in `main.dart`.
2. **Drift schema**
   - Add `calendar_events_table.dart`.
   - Wire into `database.dart`.
   - Bump schema version + migration.
   - Run `dart run build_runner build --delete-conflicting-outputs`.
   - Verify `dart analyze lib` clean.
3. **DAO**
   - Add `calendar_event_dao.dart` + run build_runner again to generate `.g.dart`.
4. **Model + recurrence**
   - Add `CalendarRecurrenceRule` (+ `toJson`/`fromJson`).
   - Add `CalendarEvent` model (+ `toJson`/`fromJson`/`fromRow`/`toCompanion`).
   - Add `CalendarRecurrenceExpander` (pure Dart, no Flutter imports).
5. **Repository + Service**
   - Add repository and service. Register service in DI.
6. **BLoC**
   - Add events/state/bloc. Implement rolling ±90-day expansion window.
7. **L10n**
   - Add all keys to all three ARB files. Run `flutter gen-l10n`.
8. **UI**
   - Add `CalendarPage` (skeleton with `TableCalendar` + selected-events list).
   - Add `EventEditorSheet`.
   - Add `calendar_event_card.dart` if extracted.
   - Wire FAB → editor → bloc.
9. **Navigation**
   - Add `AppNavigator.toCalendar`.
   - Add drawer entry in `app_drawer.dart`.
10. **Settings**
    - Add starting-day + default-format prefs in controls settings page.
11. **Backup**
    - Bump backup version to 3, add export + import branch.
12. **Polish**
    - Theming, marker builder, empty states, snackbars, locale-aware date/time formatting via `intl`.
13. **Validation**
    - `dart analyze lib`
    - `flutter run` on a device, sanity-check create / edit / delete / recurring expansion across months / format switching / locale switching / drawer back-navigation / backup round-trip.

---

## 16. Non-Negotiable Cross-Cutting Rules (reminders)

- **Never** edit `database.g.dart` or generated ARB Dart files by hand.
- **Never** wipe the DB to fix schema drift – add a migration.
- **Every** user-visible string goes through `AppLocalizations.of(context)!`.
- **No** new tests, **no** code comments, **no** new markdown docs unless explicitly requested by the user (this spec doc is the exception, explicitly requested).
- Match the local style of nearby BLoCs/services (`Equatable`, `copyWith`, sealed event/state pattern, `Completer` callbacks).
- Honor soft-delete + CRDT semantics on every write (bump `version`, refresh `hlcTimestamp` via `db.hlc.tick()`, set `updatedAt`).
- No heavy work on Flutter build hot paths. `eventLoader` must be O(1).
- No `pushReplacement` or history erasure when entering the calendar from the drawer.

---

## 17. Useful Suggestions / Future Work (do NOT implement now)

The user asked for "any useful suggestions". Capture these in the plan but **do not** build them in v1:

1. **Link events to notes** – add an optional `noteId` FK column in `calendar_events` so tapping an event can jump straight to a workout note. Use `AppNavigator.toNoteEditor`.
2. **Counter aggregation** – show, per day, the sum of selected counters (e.g. "Total volume = 12,500 kg") in the day's event list header. Hooks into `CounterService`.
3. **Workout streak overlay** – `calendarBuilders.defaultBuilder` can render a subtle flame icon on consecutive gym-event days.
4. **Local notifications** – integrate `flutter_local_notifications`; schedule notifications when an event is created/updated, cancel on delete. Persist a `notifyMinutesBefore` field.
5. **iCalendar (.ics) export/import** – useful for users syncing with Google/Apple calendars. Pure-Dart implementation possible.
6. **Range selection mode** – use `TableCalendar`'s `rangeStartDay/rangeEndDay` to bulk-create rest days or holidays.
7. **Drag-and-drop reschedule** – not natively supported by `table_calendar`; would need a custom long-press → date-picker flow.
8. **Per-note inline calendar widget** – embed a mini-calendar at the top of a workout note showing the last 7 days' completion status.
9. **CRDT sync readiness** – the table already includes `hlcTimestamp`, `deviceId`, `version`, `isDeleted`, `deletedAt`, so adding a future sync layer requires no schema migration.
10. **Smart defaults** – when creating a new event, default the category to the user's most-used category for that weekday (read from a small cached histogram in `CalendarEventService`).

---

## 18. Acceptance Checklist

The implementation is complete when ALL of the following are true:

- [ ] `flutter pub get` succeeds with `table_calendar` installed.
- [ ] `dart run build_runner build --delete-conflicting-outputs` succeeds.
- [ ] `dart analyze lib` reports **0 issues** in newly added files.
- [ ] `flutter gen-l10n` succeeds and all three locales contain the new keys.
- [ ] App launches and the drawer shows a new **Calendar** entry under Counter management.
- [ ] Tapping the entry opens the calendar; the AppBar back button returns to the previous page (folder, note editor, or wherever the drawer was opened from).
- [ ] Creating a one-time event renders a marker on that day.
- [ ] Creating a weekly recurring event with selected weekdays renders markers across multiple months when paged.
- [ ] Editing and deleting events updates the markers live without a manual refresh.
- [ ] Recurrence with `until` and `count` end conditions both work and validation messages are localized.
- [ ] Format toggle (month / 2-week / week) works and persists across app restarts.
- [ ] Backup export contains `"calendarEvents": [...]` with `version: 3`; importing it restores events exactly.
- [ ] Language switch (EN/DE/RO) updates header, weekday labels, format button, and all event editor text.
- [ ] Soft-deleted events do not appear in the calendar but remain in the DB (verified via DAO).
- [ ] No new code comments, no new tests, no new markdown files were created (other than this plan).
