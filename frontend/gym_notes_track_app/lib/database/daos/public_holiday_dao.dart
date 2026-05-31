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
  /// [profile] tags ownership so [deleteProfile] can later remove only the
  /// rows that belong to a given preset.
  Future<bool> insertIfMissing({
    required DateTime date,
    required String nameKey,
    required String profile,
    String? customLabel,
  }) async {
    final inserted = await into(publicHolidaysTable).insert(
      PublicHolidaysTableCompanion(
        date: Value(date),
        nameKey: Value(nameKey),
        profile: Value(profile),
        customLabel: Value(customLabel),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    return inserted > 0;
  }

  /// Deletes every row on [date] regardless of name or profile.
  /// Used by the existing "remove holiday on this day" UI affordance.
  Future<void> deleteOn(DateTime date) {
    return (delete(
      publicHolidaysTable,
    )..where((h) => h.date.equals(date))).go();
  }

  /// Deletes every built-in row owned by [profile]. Custom rows
  /// (`profile = kCustomHolidayProfileKey`) are intentionally untouched
  /// so user data survives every profile switch.
  Future<int> deleteProfile(String profile) {
    return (delete(
      publicHolidaysTable,
    )..where((h) => h.profile.equals(profile))).go();
  }

  Future<void> deleteAll() {
    return delete(publicHolidaysTable).go();
  }
}
