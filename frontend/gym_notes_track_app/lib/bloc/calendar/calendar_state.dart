import 'package:equatable/equatable.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/calendar_event.dart';

sealed class CalendarPageState extends Equatable {
  const CalendarPageState();

  @override
  List<Object?> get props => [];
}

final class CalendarPageInitial extends CalendarPageState {
  const CalendarPageInitial();
}

final class CalendarPageLoading extends CalendarPageState {
  const CalendarPageLoading();
}

final class CalendarPageLoaded extends CalendarPageState {
  final List<CalendarEvent> allEvents;
  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarFormat format;
  final Set<CalendarEventCategory> visibleCategories;

  CalendarPageLoaded({
    required this.allEvents,
    required this.focusedDay,
    required this.selectedDay,
    this.format = CalendarFormat.month,
    Set<CalendarEventCategory>? visibleCategories,
  }) : visibleCategories =
           visibleCategories ?? CalendarEventCategory.values.toSet();

  /// Events whose recurrence rule produces an occurrence on [selectedDay]
  /// AND whose category is currently included in [visibleCategories].
  List<CalendarEvent> get selectedEvents {
    return allEvents
        .where(
          (e) =>
              visibleCategories.contains(e.category) && e.occursOn(selectedDay),
        )
        .toList();
  }

  CalendarPageLoaded copyWith({
    List<CalendarEvent>? allEvents,
    DateTime? focusedDay,
    DateTime? selectedDay,
    CalendarFormat? format,
    Set<CalendarEventCategory>? visibleCategories,
  }) {
    return CalendarPageLoaded(
      allEvents: allEvents ?? this.allEvents,
      focusedDay: focusedDay ?? this.focusedDay,
      selectedDay: selectedDay ?? this.selectedDay,
      format: format ?? this.format,
      visibleCategories: visibleCategories ?? this.visibleCategories,
    );
  }

  @override
  List<Object?> get props => [
    allEvents,
    focusedDay,
    selectedDay,
    format,
    visibleCategories,
  ];
}

final class CalendarPageError extends CalendarPageState {
  final String message;

  const CalendarPageError(this.message);

  @override
  List<Object?> get props => [message];
}
