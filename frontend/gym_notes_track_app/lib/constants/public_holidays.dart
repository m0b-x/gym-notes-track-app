import '../l10n/app_localizations.dart';

/// Known public holidays recognized by the app.
///
/// To add a new holiday:
///   1. Add a value to [PublicHoliday].
///   2. Map a `(month, day)` tuple to it in [PublicHolidays._byDate].
///   3. Add a localized label key in the ARB files and wire it in
///      [PublicHolidays.nameOf].
enum PublicHoliday { newYear, labourDay, christmasDay, secondChristmasDay }

/// Minimal hard-coded set of public holidays (date-only, year-agnostic for
/// fixed-date holidays).
///
/// For year-specific dates (Easter, regional days, etc.) extend [holidayOn]
/// to consult a dynamic table or a holiday package keyed by locale before
/// falling back to [_byDate].
abstract final class PublicHolidays {
  static const Map<(int, int), PublicHoliday> _byDate = {
    (1, 1): PublicHoliday.newYear,
    (5, 1): PublicHoliday.labourDay,
    (12, 25): PublicHoliday.christmasDay,
    (12, 26): PublicHoliday.secondChristmasDay,
  };

  static PublicHoliday? holidayOn(DateTime day) {
    return _byDate[(day.month, day.day)];
  }

  static bool isHoliday(DateTime day) => holidayOn(day) != null;

  static String nameOf(PublicHoliday holiday, AppLocalizations l10n) {
    return switch (holiday) {
      PublicHoliday.newYear => l10n.publicHolidayNewYear,
      PublicHoliday.labourDay => l10n.publicHolidayLabourDay,
      PublicHoliday.christmasDay => l10n.publicHolidayChristmasDay,
      PublicHoliday.secondChristmasDay => l10n.publicHolidaySecondChristmasDay,
    };
  }
}
