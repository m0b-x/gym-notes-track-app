import 'package:equatable/equatable.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/calendar_event.dart';

sealed class CalendarPageEvent extends Equatable {
  const CalendarPageEvent();

  @override
  List<Object?> get props => [];
}

final class LoadCalendarEvents extends CalendarPageEvent {
  const LoadCalendarEvents();
}

final class SelectCalendarDay extends CalendarPageEvent {
  final DateTime day;
  final DateTime focusedDay;

  const SelectCalendarDay({required this.day, required this.focusedDay});

  @override
  List<Object?> get props => [day, focusedDay];
}

final class ChangeFocusedDay extends CalendarPageEvent {
  final DateTime focusedDay;

  const ChangeFocusedDay({required this.focusedDay});

  @override
  List<Object?> get props => [focusedDay];
}

final class ChangeCalendarFormat extends CalendarPageEvent {
  final CalendarFormat format;

  const ChangeCalendarFormat({required this.format});

  @override
  List<Object?> get props => [format];
}

final class ChangeVisibleCategories extends CalendarPageEvent {
  final Set<CalendarEventCategory> categories;

  const ChangeVisibleCategories({required this.categories});

  @override
  List<Object?> get props => [categories];
}

final class CreateCalendarEvent extends CalendarPageEvent {
  final CalendarEvent event;

  const CreateCalendarEvent({required this.event});

  @override
  List<Object?> get props => [event];
}

final class UpdateCalendarEvent extends CalendarPageEvent {
  final CalendarEvent event;

  const UpdateCalendarEvent({required this.event});

  @override
  List<Object?> get props => [event];
}

final class DeleteCalendarEvent extends CalendarPageEvent {
  final String eventId;

  const DeleteCalendarEvent({required this.eventId});

  @override
  List<Object?> get props => [eventId];
}
