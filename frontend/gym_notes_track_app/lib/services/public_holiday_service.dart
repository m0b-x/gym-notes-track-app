import 'package:flutter/foundation.dart';

import '../constants/public_holidays.dart';
import '../database/database.dart';
import '../database/database_lifecycle.dart';
import '../database/daos/public_holiday_dao.dart';

/// Loads and seeds the `public_holidays` table, exposes a synchronous
/// in-memory cache used by [PublicHolidays.isHoliday]/[PublicHolidays.holidayOn].
///
/// On [getInstance] it:
///   1. Seeds the default built-in holidays for the current year and the
///      five following years using insert-if-not-exists semantics, so the
///      window naturally rolls forward and never overwrites user edits.
///   2. Loads every row into memory and publishes the cache via
///      [PublicHolidays.updateCache].
class PublicHolidayService {
  static PublicHolidayService? _instance;

  late AppDatabase _db;
  late PublicHolidayDao _dao;
  Map<DateTime, PublicHolidayInfo> _cache = const {};

  /// Number of upcoming years (inclusive of the current year) that
  /// built-in seeds cover. Six years balances DB size with the user not
  /// having to re-launch every year.
  static const int _seedYearWindow = 6;

  PublicHolidayService._();

  static Future<PublicHolidayService> getInstance() async {
    if (_instance != null) return _instance!;
    final service = PublicHolidayService._();
    service._db = await AppDatabase.getInstance();
    service._dao = service._db.publicHolidayDao;
    await service._seedDefaults();
    await service._load();
    _instance = service;
    DatabaseLifecycle.registerResetHandler(reset);
    return service;
  }

  /// Drops the cached singleton and clears the static [PublicHolidays] cache so
  /// stale holiday data from a closed database cannot leak into
  /// [PublicHolidays.holidayOn] before the next [getInstance] republishes it.
  /// Invoked by [DatabaseLifecycle] when the active database changes.
  static void reset() {
    _instance = null;
    PublicHolidays.updateCache(const {});
  }

  /// Unmodifiable view over the in-memory cache. Callers must never mutate
  /// the returned map — use [addCustom] / [removeOn] to change persisted
  /// holiday data and let the service republish the cache.
  Map<DateTime, PublicHolidayInfo> get cache => Map.unmodifiable(_cache);

  Future<void> _load() async {
    final rows = await _dao.getAll();
    final next = <DateTime, PublicHolidayInfo>{};
    for (final row in rows) {
      final key = _dateOnlyUtc(row.date);
      if (row.nameKey == kCustomPublicHolidayKey) {
        next[key] = PublicHolidayInfo.custom(row.customLabel ?? '');
      } else {
        final builtIn = _nameToHoliday[row.nameKey];
        if (builtIn != null) {
          next[key] = PublicHolidayInfo.builtIn(builtIn);
        }
      }
    }
    _cache = next;
    PublicHolidays.updateCache(next, coveredYears: _seedYearRange);
  }

  /// Range of years (inclusive) that this seeder guarantees coverage for.
  /// `PublicHolidays` uses this to decide when to fall back to the
  /// static fixed-date map for out-of-window queries.
  (int min, int max) get _seedYearRange {
    final start = DateTime.now().year;
    return (start, start + _seedYearWindow - 1);
  }

  Future<void> _seedDefaults() async {
    final (startYear, endYearInclusive) = _seedYearRange;
    try {
      await _db.transaction(() async {
        for (var year = startYear; year <= endYearInclusive; year++) {
          for (final seed in _buildDefaultSeeds(year)) {
            await _dao.insertIfMissing(
              date: seed.date,
              nameKey: seed.holiday.name,
            );
          }
        }
      });
    } catch (e) {
      debugPrint('[PublicHolidayService] Seed error: $e');
    }
  }

  /// All built-in holidays for a single [year]. Movable Christian feasts
  /// are derived from Easter Sunday via the Anonymous Gregorian algorithm.
  Iterable<_HolidaySeed> _buildDefaultSeeds(int year) sync* {
    final easter = _easterSunday(year);
    yield _HolidaySeed(DateTime.utc(year, 1, 1), PublicHoliday.newYear);
    yield _HolidaySeed(DateTime.utc(year, 1, 6), PublicHoliday.epiphany);
    yield _HolidaySeed(
      easter.subtract(const Duration(days: 2)),
      PublicHoliday.goodFriday,
    );
    yield _HolidaySeed(easter, PublicHoliday.easterSunday);
    yield _HolidaySeed(
      easter.add(const Duration(days: 1)),
      PublicHoliday.easterMonday,
    );
    yield _HolidaySeed(DateTime.utc(year, 5, 1), PublicHoliday.labourDay);
    yield _HolidaySeed(
      easter.add(const Duration(days: 39)),
      PublicHoliday.ascension,
    );
    yield _HolidaySeed(
      easter.add(const Duration(days: 49)),
      PublicHoliday.pentecost,
    );
    yield _HolidaySeed(
      easter.add(const Duration(days: 50)),
      PublicHoliday.whitMonday,
    );
    yield _HolidaySeed(DateTime.utc(year, 8, 15), PublicHoliday.assumption);
    yield _HolidaySeed(DateTime.utc(year, 11, 1), PublicHoliday.allSaints);
    yield _HolidaySeed(DateTime.utc(year, 12, 24), PublicHoliday.christmasEve);
    yield _HolidaySeed(DateTime.utc(year, 12, 25), PublicHoliday.christmasDay);
    yield _HolidaySeed(
      DateTime.utc(year, 12, 26),
      PublicHoliday.secondChristmasDay,
    );
    yield _HolidaySeed(DateTime.utc(year, 12, 31), PublicHoliday.newYearsEve);
  }

  /// Anonymous Gregorian algorithm (Meeus/Jones/Butcher) — returns Easter
  /// Sunday for the given Gregorian [year] as a date-only UTC `DateTime`.
  static DateTime _easterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime.utc(year, month, day);
  }

  static final Map<String, PublicHoliday> _nameToHoliday = {
    for (final v in PublicHoliday.values) v.name: v,
  };

  static DateTime _dateOnlyUtc(DateTime value) {
    final asUtc = DateTime.fromMillisecondsSinceEpoch(
      value.millisecondsSinceEpoch,
      isUtc: true,
    );
    return DateTime.utc(asUtc.year, asUtc.month, asUtc.day);
  }

  /// Adds a user-defined custom holiday. No-op if a row already exists
  /// for [date].
  Future<void> addCustom(DateTime date, String label) async {
    final key = DateTime.utc(date.year, date.month, date.day);
    final inserted = await _dao.insertIfMissing(
      date: key,
      nameKey: kCustomPublicHolidayKey,
      customLabel: label,
    );
    if (inserted) await _load();
  }

  Future<void> removeOn(DateTime date) async {
    final key = DateTime.utc(date.year, date.month, date.day);
    await _dao.deleteOn(key);
    await _load();
  }

  // ── Backup export / import ────────────────────────────────────────────

  /// Snapshot of every holiday row (both built-in and user-custom) for
  /// inclusion in a full-app backup. User edits to the built-in set
  /// (deletions for a given year, custom additions) round-trip exactly
  /// because we mirror the row shape verbatim.
  Future<List<Map<String, dynamic>>> exportData() async {
    final rows = await _dao.getAll();
    return [
      for (final row in rows)
        {
          'dateMs': row.date.millisecondsSinceEpoch,
          'nameKey': row.nameKey,
          'customLabel': row.customLabel,
        },
    ];
  }

  /// Replaces every persisted holiday with the contents of [data]. The
  /// next startup will re-seed any built-in rows that are still missing
  /// (idempotent), so a backup taken before a new built-in was added
  /// will not block the seeder from filling it in.
  Future<void> importData(List<dynamic> data) async {
    await _dao.deleteAll();
    for (final raw in data) {
      if (raw is! Map) continue;
      final map = raw.cast<String, dynamic>();
      final dateMs = map['dateMs'];
      final nameKey = map['nameKey'] as String?;
      if (dateMs is! int || nameKey == null) continue;
      final date = _dateOnlyUtc(
        DateTime.fromMillisecondsSinceEpoch(dateMs, isUtc: true),
      );
      try {
        await _dao.insertIfMissing(
          date: date,
          nameKey: nameKey,
          customLabel: map['customLabel'] as String?,
        );
      } catch (e) {
        debugPrint('[PublicHolidayService] Import row error: $e');
      }
    }
    await _load();
  }
}

class _HolidaySeed {
  final DateTime date;
  final PublicHoliday holiday;
  const _HolidaySeed(this.date, this.holiday);
}
