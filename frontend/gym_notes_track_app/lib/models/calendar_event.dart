import 'package:equatable/equatable.dart';

import 'recurrence_rule.dart';

enum CalendarEventCategory {
  gym,
  cardio,
  rest,
  holiday,
  competition,
  measurement,
  other,
}

class CalendarEvent extends Equatable {
  final String id;
  final String title;
  final CalendarEventCategory category;
  final DateTime startDate;
  final bool allDay;
  final RecurrenceRule rule;

  /// Optional inclusive upper bound for [rule] occurrences. When non-null
  /// and [day] is strictly after this date (date-only UTC), [occursOn]
  /// returns false regardless of the rule. `null` means "no end".
  ///
  /// Ignored for one-time events (their start *is* their end).
  final DateTime? endDate;

  /// Optional free-form description / notes for the event (e.g., "focus on
  /// hamstrings, drop sets on the third exercise"). `null` or empty means
  /// no description. Stored verbatim — no markdown rendering today.
  final String? description;

  /// Optional explicit icon override (a key into `CalendarIcons.palette`).
  /// When `null`, the icon falls back to the category default.
  final String? iconKey;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.startDate,
    this.allDay = true,
    this.rule = const OneTimeRecurrence(),
    this.endDate,
    this.description,
    this.iconKey,
  });

  CalendarEvent copyWith({
    String? id,
    String? title,
    CalendarEventCategory? category,
    DateTime? startDate,
    bool? allDay,
    RecurrenceRule? rule,
    DateTime? endDate,
    String? description,
    String? iconKey,
    bool clearEndDate = false,
    bool clearDescription = false,
    bool clearIconKey = false,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      allDay: allDay ?? this.allDay,
      rule: rule ?? this.rule,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      description: clearDescription ? null : (description ?? this.description),
      iconKey: clearIconKey ? null : (iconKey ?? this.iconKey),
    );
  }

  /// Returns true if this event has an occurrence on [day].
  ///
  /// All edge cases (Feb 29 yearly, day 31 monthly, pre-start dates, public
  /// holidays for the workdays/holidays-only rules) are owned by the
  /// underlying [RecurrenceRule]. The [endDate] upper bound, if any, is
  /// applied at this layer because it is orthogonal to the rule shape.
  bool occursOn(DateTime day) {
    final start = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final target = DateTime.utc(day.year, day.month, day.day);
    final end = endDate;
    if (end != null) {
      final endUtc = DateTime.utc(end.year, end.month, end.day);
      if (target.isAfter(endUtc)) return false;
    }
    return rule.occursOn(target, start);
  }

  @override
  List<Object?> get props => [
    id,
    title,
    category,
    startDate,
    allDay,
    rule,
    endDate,
    description,
    iconKey,
  ];
}
