import 'package:drift/drift.dart';

/// Persisted custom calendar events. The recurrence rule is stored as
/// [ruleKind] plus an optional JSON [rulePayload] for kinds that carry data
/// (currently only `weekly` uses payload `{"weekdays":[1,3,5]}`).
///
/// [endDate] (added in schema v11) is an inclusive upper bound for any
/// recurring rule — the event stops producing occurrences strictly after
/// this UTC date. `null` means "no end".
///
/// [startMinute] / [durationMinutes] (also v11, reserved) are placeholders
/// for future time-of-day events. They are currently never written by
/// application code; they exist so we can introduce timed events without
/// another migration.
@DataClassName('CalendarEventRow')
class CalendarEvents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get category => text()();
  DateTimeColumn get startDate => dateTime()();
  BoolColumn get allDay => boolean().withDefault(const Constant(true))();
  TextColumn get iconKey => text().nullable()();
  TextColumn get ruleKind => text()();
  TextColumn get rulePayload => text().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get startMinute => integer().nullable()();
  IntColumn get durationMinutes => integer().nullable()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
