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

/// Monday-aligned epoch for stable "every N weeks" math. 2000-01-03 is a
/// Monday and predates the calendar's representable range, so the week
/// index of any in-range date is well defined and weeks are counted from a
/// fixed grid rather than from each event's start (which keeps interval
/// phase consistent regardless of the anchor's weekday).
final DateTime _weekEpoch = DateTime.utc(2000, 1, 3);

/// Whole weeks between [_weekEpoch] and [day], flooring toward negative
/// infinity so dates before the epoch still index monotonically.
int _weekIndex(DateTime day) {
  final days = day.difference(_weekEpoch).inDays;
  return days >= 0 ? days ~/ 7 : -((-days + 6) ~/ 7);
}

/// Single-occurrence event. Fires only on its [start] date.
final class OneTimeRecurrence extends RecurrenceRule {
  const OneTimeRecurrence();

  @override
  bool occursOn(DateTime day, DateTime start) => day == start;
}

/// Fires every [interval] days on or after [start] (1 = every day).
final class DailyRecurrence extends RecurrenceRule {
  final int interval;

  const DailyRecurrence({this.interval = 1}) : assert(interval >= 1);

  @override
  bool occursOn(DateTime day, DateTime start) {
    if (day.isBefore(start)) return false;
    if (interval <= 1) return true;
    return day.difference(start).inDays % interval == 0;
  }

  @override
  List<Object?> get props => [interval];
}

/// Fires every [interval] weeks on the selected [weekdays] (1=Mon..7=Sun).
///
/// An empty weekday set never fires; the editor guards against this. With
/// [interval] > 1 only the matching weeks fire (e.g. an A/B split every
/// two weeks), counted on a fixed Monday-aligned grid anchored at [start]'s
/// week.
final class WeeklyRecurrence extends RecurrenceRule {
  final Set<int> weekdays;
  final int interval;

  const WeeklyRecurrence({required this.weekdays, this.interval = 1})
    : assert(interval >= 1);

  @override
  bool occursOn(DateTime day, DateTime start) {
    if (day.isBefore(start)) return false;
    if (!weekdays.contains(day.weekday)) return false;
    if (interval <= 1) return true;
    return (_weekIndex(day) - _weekIndex(start)) % interval == 0;
  }

  @override
  List<Object?> get props => [weekdays, interval];
}

/// Fires every [interval] months on the same day-of-month as [start].
/// Naturally skips months that don't have that day (e.g. day 31 in
/// February).
final class MonthlyRecurrence extends RecurrenceRule {
  final int interval;

  const MonthlyRecurrence({this.interval = 1}) : assert(interval >= 1);

  @override
  bool occursOn(DateTime day, DateTime start) {
    if (day.isBefore(start)) return false;
    if (day.day != start.day) return false;
    if (interval <= 1) return true;
    final months = (day.year - start.year) * 12 + (day.month - start.month);
    return months % interval == 0;
  }

  @override
  List<Object?> get props => [interval];
}

/// Fires every [interval] years on the same (month, day) as [start].
/// Anchoring on Feb 29 naturally limits the rule to leap years.
final class YearlyRecurrence extends RecurrenceRule {
  final int interval;

  const YearlyRecurrence({this.interval = 1}) : assert(interval >= 1);

  @override
  bool occursOn(DateTime day, DateTime start) {
    if (day.isBefore(start)) return false;
    if (day.month != start.month || day.day != start.day) return false;
    if (interval <= 1) return true;
    return (day.year - start.year) % interval == 0;
  }

  @override
  List<Object?> get props => [interval];
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
