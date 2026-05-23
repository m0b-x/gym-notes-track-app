import 'package:equatable/equatable.dart';

import '../constants/public_holidays.dart';

/// Sealed hierarchy of recurrence rules for a calendar event.
///
/// All rules are pure value objects. [occursOn] takes a normalized date-only
/// UTC [day] plus the event's anchor [start] date and returns whether the
/// rule produces an occurrence on that day. Implementations must never
/// return `true` for dates before [start].
///
/// To add a new rule:
///   1. Add a new `final class` here extending [RecurrenceRule].
///   2. Add a case in `RecurrenceFormatter.format` (services).
///   3. Add a case in `EventEditorSheet` (state init + build mapping).
sealed class RecurrenceRule extends Equatable {
  const RecurrenceRule();

  bool occursOn(DateTime day, DateTime start);

  @override
  List<Object?> get props => const [];
}

/// Single-occurrence event. Fires only on its [start] date.
final class OneTimeRecurrence extends RecurrenceRule {
  const OneTimeRecurrence();

  @override
  bool occursOn(DateTime day, DateTime start) => day == start;
}

/// Fires every day on or after [start].
final class DailyRecurrence extends RecurrenceRule {
  const DailyRecurrence();

  @override
  bool occursOn(DateTime day, DateTime start) => !day.isBefore(start);
}

/// Fires every week on the selected [weekdays] (1=Mon..7=Sun).
///
/// An empty weekday set never fires; the editor guards against this.
final class WeeklyRecurrence extends RecurrenceRule {
  final Set<int> weekdays;

  const WeeklyRecurrence({required this.weekdays});

  @override
  bool occursOn(DateTime day, DateTime start) {
    if (day.isBefore(start)) return false;
    return weekdays.contains(day.weekday);
  }

  @override
  List<Object?> get props => [weekdays];
}

/// Fires monthly on the same day-of-month as [start]. Naturally skips
/// months that don't have that day (e.g. day 31 in February).
final class MonthlyRecurrence extends RecurrenceRule {
  const MonthlyRecurrence();

  @override
  bool occursOn(DateTime day, DateTime start) {
    if (day.isBefore(start)) return false;
    return day.day == start.day;
  }
}

/// Fires once per year on the same (month, day) as [start]. Anchoring on
/// Feb 29 naturally limits the rule to leap years.
final class YearlyRecurrence extends RecurrenceRule {
  const YearlyRecurrence();

  @override
  bool occursOn(DateTime day, DateTime start) {
    if (day.isBefore(start)) return false;
    return day.month == start.month && day.day == start.day;
  }
}

/// Every Mon–Fri that is NOT a public holiday.
final class WorkdaysRecurrence extends RecurrenceRule {
  const WorkdaysRecurrence();

  @override
  bool occursOn(DateTime day, DateTime start) {
    if (day.isBefore(start)) return false;
    if (day.weekday > DateTime.friday) return false;
    return !PublicHolidays.isHoliday(day);
  }
}

/// Every Saturday and Sunday on or after [start].
final class WeekendsRecurrence extends RecurrenceRule {
  const WeekendsRecurrence();

  @override
  bool occursOn(DateTime day, DateTime start) {
    if (day.isBefore(start)) return false;
    return day.weekday >= DateTime.saturday;
  }
}

/// Fires only on public holidays on or after [start].
final class PublicHolidaysOnlyRecurrence extends RecurrenceRule {
  const PublicHolidaysOnlyRecurrence();

  @override
  bool occursOn(DateTime day, DateTime start) {
    if (day.isBefore(start)) return false;
    return PublicHolidays.isHoliday(day);
  }
}
