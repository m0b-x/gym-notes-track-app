import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/public_holidays_table.dart';

part 'public_holiday_dao.g.dart';

@DriftAccessor(tables: [PublicHolidaysTable])
class PublicHolidayDao extends DatabaseAccessor<AppDatabase>
    with _$PublicHolidayDaoMixin {
  PublicHolidayDao(super.db);

  Future<List<PublicHolidayRow>> getAll() {
    return (select(
      publicHolidaysTable,
    )..orderBy([(h) => OrderingTerm.asc(h.date)])).get();
  }

  /// Insert-if-not-exists. Returns true when the row was actually inserted.
  Future<bool> insertIfMissing({
    required DateTime date,
    required String nameKey,
    String? customLabel,
  }) async {
    final inserted = await into(publicHolidaysTable).insert(
      PublicHolidaysTableCompanion(
        date: Value(date),
        nameKey: Value(nameKey),
        customLabel: Value(customLabel),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    return inserted > 0;
  }

  Future<void> deleteOn(DateTime date) {
    return (delete(
      publicHolidaysTable,
    )..where((h) => h.date.equals(date))).go();
  }

  Future<void> deleteAll() {
    return delete(publicHolidaysTable).go();
  }
}
