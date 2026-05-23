import 'package:drift/drift.dart';

/// Persisted public holidays. Each row is a specific dated holiday.
///
/// [nameKey] holds the localizable enum name (e.g. `newYear`, `easterMonday`)
/// for built-in holidays. User-added rows use the sentinel `custom` and
/// store their display string in [customLabel].
///
/// Movable holidays (Easter) are seeded as concrete dated rows per year by
/// `PublicHolidayService` using add-if-not-exists semantics, so the year
/// window naturally extends forward without manual migrations.
@DataClassName('PublicHolidayRow')
class PublicHolidaysTable extends Table {
  @override
  String get tableName => 'public_holidays';

  /// UTC date-only (year, month, day) — the primary key.
  DateTimeColumn get date => dateTime()();
  TextColumn get nameKey => text()();
  TextColumn get customLabel => text().nullable()();

  @override
  Set<Column> get primaryKey => {date};
}
