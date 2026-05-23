import 'package:equatable/equatable.dart';

enum CalendarEventCategory { gym, cardio, rest, holiday, competition, measurement, other }

class CalendarEvent extends Equatable {
  final String id;
  final String title;
  final CalendarEventCategory category;
  final DateTime startDate;
  final bool allDay;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.startDate,
    this.allDay = true,
  });

  CalendarEvent copyWith({
    String? id,
    String? title,
    CalendarEventCategory? category,
    DateTime? startDate,
    bool? allDay,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      allDay: allDay ?? this.allDay,
    );
  }

  @override
  List<Object?> get props => [id, title, category, startDate, allDay];
}