import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/calendar_event.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

export 'calendar_event.dart';
export 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarPageEvent, CalendarPageState> {
  CalendarBloc() : super(const CalendarPageInitial()) {
    on<LoadCalendarEvents>(_onLoad);
    on<SelectCalendarDay>(_onSelectDay);
    on<ChangeFocusedDay>(_onChangeFocusedDay);
    on<ChangeCalendarFormat>(_onChangeFormat);
    on<CreateCalendarEvent>(_onCreateEvent);
  }

  List<CalendarEvent> eventsForDay(DateTime day) {
    final current = state;
    if (current is! CalendarPageLoaded) return const [];
    return current.expandedByDay[_dateOnly(day)] ?? const [];
  }

  void _onLoad(LoadCalendarEvents event, Emitter<CalendarPageState> emit) {
    final today = _dateOnly(DateTime.now());
    emit(
      CalendarPageLoaded(
        allEvents: const [],
        focusedDay: today,
        selectedDay: today,
        expandedByDay: const {},
      ),
    );
  }

  void _onSelectDay(
    SelectCalendarDay event,
    Emitter<CalendarPageState> emit,
  ) {
    final current = state;
    if (current is! CalendarPageLoaded) return;
    emit(
      current.copyWith(
        selectedDay: _dateOnly(event.day),
        focusedDay: _dateOnly(event.focusedDay),
      ),
    );
  }

  void _onChangeFocusedDay(
    ChangeFocusedDay event,
    Emitter<CalendarPageState> emit,
  ) {
    final current = state;
    if (current is! CalendarPageLoaded) return;
    emit(current.copyWith(focusedDay: _dateOnly(event.focusedDay)));
  }

  void _onChangeFormat(
    ChangeCalendarFormat event,
    Emitter<CalendarPageState> emit,
  ) {
    final current = state;
    if (current is! CalendarPageLoaded || current.format == event.format) {
      return;
    }
    emit(current.copyWith(format: event.format));
  }

  void _onCreateEvent(
    CreateCalendarEvent event,
    Emitter<CalendarPageState> emit,
  ) {
    final current = state;
    if (current is! CalendarPageLoaded) return;
    final normalized = event.event.copyWith(
      startDate: _dateOnly(event.event.startDate),
    );
    final nextEvents = [...current.allEvents, normalized];
    emit(
      current.copyWith(
        allEvents: nextEvents,
        expandedByDay: _buildEventsByDay(nextEvents),
        selectedDay: normalized.startDate,
        focusedDay: normalized.startDate,
      ),
    );
  }

  static Map<DateTime, List<CalendarEvent>> _buildEventsByDay(
    List<CalendarEvent> events,
  ) {
    final result = <DateTime, List<CalendarEvent>>{};
    for (final event in events) {
      final day = _dateOnly(event.startDate);
      result.putIfAbsent(day, () => []).add(event);
    }
    return result;
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }
}