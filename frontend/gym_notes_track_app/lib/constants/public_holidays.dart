import '../l10n/app_localizations.dart';

/// Available built-in holiday profiles.
///
/// Each profile is a curated list of holidays for a region or tradition.
/// `PublicHolidayService` seeds the active profile into the database on
/// startup using insert-if-not-exists semantics; switching profiles
/// (via `setProfile`) wipes the previous profile's seeded rows and
/// re-seeds, while user-added custom rows always survive.
///
/// To add a new profile:
///   1. Add a value here.
///   2. Add a builder branch in `PublicHolidayService._buildSeeds`.
///   3. Localize its display name in `PublicHolidays.profileNameOf`
///      and add the matching ARB key (`holidayProfile<EnumName>`).
enum HolidayProfile {
  /// Catholic-leaning Christian set with Gregorian Easter. Historical
  /// default — matches what the app shipped before profiles existed.
  generic,

  /// Romanian national + Orthodox Christian set (Orthodox Easter dates).
  romania,

  /// United States federal holidays (movable Mondays/Thursdays included).
  unitedStates,

  /// United Kingdom (England & Wales) bank holidays.
  unitedKingdom,

  /// German nationwide federal public holidays.
  germany,

  /// Pan-European combined set: the most widely shared Christian and civil
  /// holidays across Europe, plus Europe Day.
  europe,

  /// Empty set: no built-in holidays. Users can still add customs.
  none,
}

/// Sentinel `profile` value used in the `public_holidays` table for
/// user-added rows. Distinct from any [HolidayProfile.name] so profile
/// switches can purge built-ins without touching customs.
const String kCustomHolidayProfileKey = 'custom';

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
///   3. Add it to the appropriate per-profile seed list in
///      `PublicHolidayService._buildSeeds`.
enum PublicHoliday {
  // ── Christian / shared ─────────────────────────────────────────────
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

  // ── Romania-specific ───────────────────────────────────────────────
  /// 24 January — Unification of the Romanian Principalities.
  unificationDay,

  /// 1 June — Children's Day.
  childrensDay,

  /// 30 November — Saint Andrew's Day.
  stAndrewDay,

  /// 1 December — Romanian National Day.
  nationalDayRomania,

  // ── United States ──────────────────────────────────────────────────
  /// 3rd Monday of January — Martin Luther King Jr. Day.
  martinLutherKingDay,

  /// 3rd Monday of February — Presidents' Day (Washington's Birthday).
  presidentsDay,

  /// Last Monday of May — Memorial Day.
  memorialDay,

  /// 19 June — Juneteenth National Independence Day.
  juneteenth,

  /// 4 July — Independence Day.
  independenceDay,

  /// 1st Monday of September — Labor Day (US).
  laborDayUnitedStates,

  /// 2nd Monday of October — Columbus Day.
  columbusDay,

  /// 11 November — Veterans Day.
  veteransDay,

  /// 4th Thursday of November — Thanksgiving.
  thanksgiving,

  // ── United Kingdom ─────────────────────────────────────────────────
  /// 1st Monday of May — Early May Bank Holiday.
  earlyMayBankHoliday,

  /// Last Monday of May — Spring Bank Holiday.
  springBankHoliday,

  /// Last Monday of August — Summer Bank Holiday.
  summerBankHoliday,

  // ── Germany ────────────────────────────────────────────────────────
  /// 3 October — German Unity Day.
  germanUnityDay,

  // ── Europe ─────────────────────────────────────────────────────────
  /// 9 May — Europe Day (Schuman Day).
  europeDay,
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
      PublicHoliday.unificationDay => l10n.publicHolidayUnificationDay,
      PublicHoliday.childrensDay => l10n.publicHolidayChildrensDay,
      PublicHoliday.stAndrewDay => l10n.publicHolidayStAndrewDay,
      PublicHoliday.nationalDayRomania => l10n.publicHolidayNationalDayRomania,
      PublicHoliday.martinLutherKingDay =>
        l10n.publicHolidayMartinLutherKingDay,
      PublicHoliday.presidentsDay => l10n.publicHolidayPresidentsDay,
      PublicHoliday.memorialDay => l10n.publicHolidayMemorialDay,
      PublicHoliday.juneteenth => l10n.publicHolidayJuneteenth,
      PublicHoliday.independenceDay => l10n.publicHolidayIndependenceDay,
      PublicHoliday.laborDayUnitedStates =>
        l10n.publicHolidayLaborDayUnitedStates,
      PublicHoliday.columbusDay => l10n.publicHolidayColumbusDay,
      PublicHoliday.veteransDay => l10n.publicHolidayVeteransDay,
      PublicHoliday.thanksgiving => l10n.publicHolidayThanksgiving,
      PublicHoliday.earlyMayBankHoliday =>
        l10n.publicHolidayEarlyMayBankHoliday,
      PublicHoliday.springBankHoliday => l10n.publicHolidaySpringBankHoliday,
      PublicHoliday.summerBankHoliday => l10n.publicHolidaySummerBankHoliday,
      PublicHoliday.germanUnityDay => l10n.publicHolidayGermanUnityDay,
      PublicHoliday.europeDay => l10n.publicHolidayEuropeDay,
    };
  }

  /// Resolves the localized display name for a [HolidayProfile].
  static String profileNameOf(HolidayProfile profile, AppLocalizations l10n) {
    return switch (profile) {
      HolidayProfile.generic => l10n.holidayProfileGeneric,
      HolidayProfile.romania => l10n.holidayProfileRomania,
      HolidayProfile.unitedStates => l10n.holidayProfileUnitedStates,
      HolidayProfile.unitedKingdom => l10n.holidayProfileUnitedKingdom,
      HolidayProfile.germany => l10n.holidayProfileGermany,
      HolidayProfile.europe => l10n.holidayProfileEurope,
      HolidayProfile.none => l10n.holidayProfileNone,
    };
  }

  /// Parses a stored [HolidayProfile.name] back into the enum, falling
  /// back to [HolidayProfile.generic] for unrecognized values (forward
  /// compatibility with backups taken from a future version that adds
  /// new profiles).
  static HolidayProfile profileFromName(String? name) {
    if (name == null) return HolidayProfile.generic;
    for (final value in HolidayProfile.values) {
      if (value.name == name) return value;
    }
    return HolidayProfile.generic;
  }

  /// Convenience: resolves the localized display label for any
  /// [PublicHolidayInfo], including user-added custom entries.
  static String labelOf(PublicHolidayInfo info, AppLocalizations l10n) {
    final builtIn = info.builtIn;
    if (builtIn != null) return nameOf(builtIn, l10n);
    return info.customLabel ?? '';
  }
}
