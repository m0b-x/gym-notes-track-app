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
    on<UpdateCalendarEvent>(_onUpdateEvent);
    on<DeleteCalendarEvent>(_onDeleteEvent);
  }

  /// O(N) lookup over all events using [CalendarEvent.occursOn]. Fine for
  /// the in-memory Phase 1 slice; replace with a windowed cache once Drift
  /// persistence lands.
  List<CalendarEvent> eventsForDay(DateTime day) {
    final current = state;
    if (current is! CalendarPageLoaded) return const [];
    return current.allEvents.where((e) => e.occursOn(day)).toList();
  }

  void _onLoad(LoadCalendarEvents event, Emitter<CalendarPageState> emit) {
    final today = _dateOnly(DateTime.now());
    emit(
      CalendarPageLoaded(
        allEvents: const [],
        focusedDay: today,
        selectedDay: today,
      ),
    );
  }

  void _onSelectDay(SelectCalendarDay event, Emitter<CalendarPageState> emit) {
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
    emit(
      current.copyWith(
        allEvents: [...current.allEvents, normalized],
        selectedDay: normalized.startDate,
        focusedDay: normalized.startDate,
      ),
    );
  }

  void _onUpdateEvent(
    UpdateCalendarEvent event,
    Emitter<CalendarPageState> emit,
  ) {
    final current = state;
    if (current is! CalendarPageLoaded) return;
    final normalized = event.event.copyWith(
      startDate: _dateOnly(event.event.startDate),
    );
    final next = [
      for (final e in current.allEvents)
        if (e.id == normalized.id) normalized else e,
    ];
    emit(current.copyWith(allEvents: next));
  }

  void _onDeleteEvent(
    DeleteCalendarEvent event,
    Emitter<CalendarPageState> emit,
  ) {
    final current = state;
    if (current is! CalendarPageLoaded) return;
    final next = current.allEvents
        .where((e) => e.id != event.eventId)
        .toList(growable: false);
    if (next.length == current.allEvents.length) return;
    emit(current.copyWith(allEvents: next));
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }
}
