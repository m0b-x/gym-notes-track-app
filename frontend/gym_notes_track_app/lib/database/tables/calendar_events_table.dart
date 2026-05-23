import 'package:drift/drift.dart';

/// Persisted custom calendar events. The recurrence rule is stored as
/// [ruleKind] plus an optional JSON [rulePayload] for kinds that carry data
/// (currently only `weekly` uses payload `{"weekdays":[1,3,5]}`).
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
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
