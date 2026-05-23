import '../l10n/app_localizations.dart';

/// Known public holidays recognized by the app.
///
/// Built-in holidays are seeded into the `public_holidays` Drift table on
/// first launch (and re-seeded with add-if-not-exists semantics on every
/// app start to extend the year window forward). Each row stores either a
/// built-in [PublicHoliday.name] in `name_key` or the sentinel `custom`
/// alongside a user-provided `custom_label`.
///
/// To add a new built-in holiday:
///   1. Add a value to [PublicHoliday].
///   2. Localize its label in [PublicHolidays.nameOf] and in the ARB files
///      (key pattern: `publicHoliday<EnumName>`).
///   3. Add it to the seed list in `PublicHolidayService._buildDefaultSeeds`.
enum PublicHoliday {
  newYear,
  epiphany,
  goodFriday,
  easterSunday,
  easterMonday,
  labourDay,
  ascension,
  pentecost,
  whitMonday,
  assumption,
  allSaints,
  christmasEve,
  christmasDay,
  secondChristmasDay,
  newYearsEve,
}

/// Sentinel `name_key` used in the `public_holidays` table for user-added
/// rows whose display string lives in the row's `custom_label` column.
const String kCustomPublicHolidayKey = 'custom';

/// Resolved holiday entry as returned by [PublicHolidays.holidayOn].
/// Either [builtIn] is non-null (use [PublicHolidays.nameOf]) or
/// [customLabel] holds the display string verbatim.
class PublicHolidayInfo {
  final PublicHoliday? builtIn;
  final String? customLabel;
  const PublicHolidayInfo._({this.builtIn, this.customLabel});
  const PublicHolidayInfo.builtIn(PublicHoliday holiday)
    : this._(builtIn: holiday);
  const PublicHolidayInfo.custom(String label) : this._(customLabel: label);
}

/// Synchronous facade over the cached holiday set populated by
/// `PublicHolidayService` at startup. Falls back to the static built-in
/// fixed-date set so [isHoliday] keeps working in tests or before the
/// service has initialized.
abstract final class PublicHolidays {
  /// In-memory cache keyed by `DateTime.utc(year, month, day)`. Populated by
  /// `PublicHolidayService` after it loads/seeds the `public_holidays` table.
  static Map<DateTime, PublicHolidayInfo> _cache = const {};

  /// Inclusive `(minYear, maxYear)` covered by the seeded cache. Outside
  /// this range we fall back to the static fixed-date map so far-future
  /// queries like `isHoliday(2099-12-25)` keep returning a sensible answer.
  /// Null while the service has not initialized.
  static (int, int)? _coveredYears;

  /// Built-in fixed-date fallback used when the cache is empty (e.g. tests)
  /// or for years outside the covered window.
  static const Map<(int, int), PublicHoliday> _fixedFallback = {
    (1, 1): PublicHoliday.newYear,
    (1, 6): PublicHoliday.epiphany,
    (5, 1): PublicHoliday.labourDay,
    (8, 15): PublicHoliday.assumption,
    (11, 1): PublicHoliday.allSaints,
    (12, 24): PublicHoliday.christmasEve,
    (12, 25): PublicHoliday.christmasDay,
    (12, 26): PublicHoliday.secondChristmasDay,
    (12, 31): PublicHoliday.newYearsEve,
  };

  /// Replaces the cache. Called by `PublicHolidayService`. [coveredYears]
  /// is the inclusive year range the service guarantees coverage for; pass
  /// null to disable the out-of-window fallback (tests).
  static void updateCache(
    Map<DateTime, PublicHolidayInfo> cache, {
    (int, int)? coveredYears,
  }) {
    _cache = Map.unmodifiable(cache);
    _coveredYears = coveredYears;
  }

  static PublicHolidayInfo? holidayOn(DateTime day) {
    final key = DateTime.utc(day.year, day.month, day.day);
    final cached = _cache[key];
    if (cached != null) return cached;
    final covered = _coveredYears;
    // Inside the seeded window we trust the cache verbatim (so a user can
    // delete a built-in for a given year and have it stay deleted).
    if (covered != null && day.year >= covered.$1 && day.year <= covered.$2) {
      return null;
    }
    final fixed = _fixedFallback[(day.month, day.day)];
    return fixed == null ? null : PublicHolidayInfo.builtIn(fixed);
  }

  static bool isHoliday(DateTime day) => holidayOn(day) != null;

  /// Resolves the localized label for a built-in holiday enum value.
  static String nameOf(PublicHoliday holiday, AppLocalizations l10n) {
    return switch (holiday) {
      PublicHoliday.newYear => l10n.publicHolidayNewYear,
      PublicHoliday.epiphany => l10n.publicHolidayEpiphany,
      PublicHoliday.goodFriday => l10n.publicHolidayGoodFriday,
      PublicHoliday.easterSunday => l10n.publicHolidayEasterSunday,
      PublicHoliday.easterMonday => l10n.publicHolidayEasterMonday,
      PublicHoliday.labourDay => l10n.publicHolidayLabourDay,
      PublicHoliday.ascension => l10n.publicHolidayAscension,
      PublicHoliday.pentecost => l10n.publicHolidayPentecost,
      PublicHoliday.whitMonday => l10n.publicHolidayWhitMonday,
      PublicHoliday.assumption => l10n.publicHolidayAssumption,
      PublicHoliday.allSaints => l10n.publicHolidayAllSaints,
      PublicHoliday.christmasEve => l10n.publicHolidayChristmasEve,
      PublicHoliday.christmasDay => l10n.publicHolidayChristmasDay,
      PublicHoliday.secondChristmasDay => l10n.publicHolidaySecondChristmasDay,
      PublicHoliday.newYearsEve => l10n.publicHolidayNewYearsEve,
    };
  }

  /// Convenience: resolves the localized display label for any
  /// [PublicHolidayInfo], including user-added custom entries.
  static String labelOf(PublicHolidayInfo info, AppLocalizations l10n) {
    final builtIn = info.builtIn;
    if (builtIn != null) return nameOf(builtIn, l10n);
    return info.customLabel ?? '';
  }
}
