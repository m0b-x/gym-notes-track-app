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
    this.iconKey,
  });

  CalendarEvent copyWith({
    String? id,
    String? title,
    CalendarEventCategory? category,
    DateTime? startDate,
    bool? allDay,
    RecurrenceRule? rule,
    String? iconKey,
    bool clearIconKey = false,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      allDay: allDay ?? this.allDay,
      rule: rule ?? this.rule,
      iconKey: clearIconKey ? null : (iconKey ?? this.iconKey),
    );
  }

  /// Returns true if this event has an occurrence on [day].
  ///
  /// All edge cases (Feb 29 yearly, day 31 monthly, pre-start dates, public
  /// holidays for the workdays/holidays-only rules) are owned by the
  /// underlying [RecurrenceRule].
  bool occursOn(DateTime day) {
    final start = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final target = DateTime.utc(day.year, day.month, day.day);
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
    iconKey,
  ];
}
