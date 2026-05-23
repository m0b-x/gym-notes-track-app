import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/recurrence_rule.dart';

/// Locale-aware human-readable label for a [RecurrenceRule].
abstract final class RecurrenceFormatter {
  static String format(
    RecurrenceRule rule,
    AppLocalizations l10n,
    String localeName,
  ) {
    return switch (rule) {
      OneTimeRecurrence() => l10n.recurrenceNone,
      DailyRecurrence() => l10n.recurrenceDaily,
      WeeklyRecurrence(:final weekdays) => weekdays.isEmpty
          ? l10n.recurrenceWeekly
          : l10n.recurrenceWeeklyOn(formatWeekdays(weekdays, localeName)),
      MonthlyRecurrence() => l10n.recurrenceMonthly,
      YearlyRecurrence() => l10n.recurrenceYearly,
      WorkdaysRecurrence() => l10n.recurrenceWorkdays,
      WeekendsRecurrence() => l10n.recurrenceWeekends,
      PublicHolidaysOnlyRecurrence() => l10n.recurrenceHolidaysOnly,
    };
  }

  /// "Mon, Wed, Fri" (locale-aware abbreviated weekday names).
  static String formatWeekdays(Set<int> weekdays, String localeName) {
    final sorted = weekdays.toList()..sort();
    return sorted.map((d) => weekdayShort(d, localeName)).join(', ');
  }

  /// 1=Mon..7=Sun → locale-specific short weekday label.
  static String weekdayShort(int weekday, String localeName) {
    // 2024-01-01 was a Monday; offset by (weekday-1) days to land on it.
    final anchor = DateTime(2024, 1, 1).add(Duration(days: weekday - 1));
    return DateFormat.E(localeName).format(anchor);
  }
}
