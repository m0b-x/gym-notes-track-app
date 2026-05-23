import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/calendar_event.dart';
import '../../services/calendar_event_service.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

export 'calendar_event.dart';
export 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarPageEvent, CalendarPageState> {
  final CalendarEventService _service;

  CalendarBloc({required CalendarEventService service})
    : _service = service,
      super(const CalendarPageInitial()) {
    on<LoadCalendarEvents>(_onLoad);
    on<SelectCalendarDay>(_onSelectDay);
    on<ChangeFocusedDay>(_onChangeFocusedDay);
    on<ChangeCalendarFormat>(_onChangeFormat);
    on<ChangeVisibleCategories>(_onChangeVisibleCategories);
    on<CreateCalendarEvent>(_onCreateEvent);
    on<UpdateCalendarEvent>(_onUpdateEvent);
    on<DeleteCalendarEvent>(_onDeleteEvent);
  }

  /// O(N) lookup over the in-memory cache populated by
  /// [CalendarEventService]. Stays synchronous so `TableCalendar.eventLoader`
  /// can call it directly.
  List<CalendarEvent> eventsForDay(DateTime day) {
    final current = state;
    if (current is! CalendarPageLoaded) return const [];
    return current.allEvents
        .where(
          (e) =>
              current.visibleCategories.contains(e.category) && e.occursOn(day),
        )
        .toList();
  }

  Future<void> _onLoad(
    LoadCalendarEvents event,
    Emitter<CalendarPageState> emit,
  ) async {
    final today = _dateOnly(DateTime.now());
    try {
      await _service.reload();
    } catch (e) {
      debugPrint('[CalendarBloc] Load error: $e');
    }
    emit(
      CalendarPageLoaded(
        allEvents: List.unmodifiable(_service.events),
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

  void _onChangeVisibleCategories(
    ChangeVisibleCategories event,
    Emitter<CalendarPageState> emit,
  ) {
    final current = state;
    if (current is! CalendarPageLoaded) return;
    final next = Set<CalendarEventCategory>.unmodifiable(event.categories);
    if (next.length == current.visibleCategories.length &&
        next.containsAll(current.visibleCategories)) {
      return;
    }
    emit(current.copyWith(visibleCategories: next));
  }

  Future<void> _onCreateEvent(
    CreateCalendarEvent event,
    Emitter<CalendarPageState> emit,
  ) async {
    final current = state;
    if (current is! CalendarPageLoaded) return;
    final normalized = event.event.copyWith(
      startDate: _dateOnly(event.event.startDate),
    );
    try {
      await _service.upsert(normalized);
    } catch (e) {
      debugPrint('[CalendarBloc] Create error: $e');
      return;
    }
    emit(
      current.copyWith(
        allEvents: List.unmodifiable(_service.events),
        selectedDay: normalized.startDate,
        focusedDay: normalized.startDate,
      ),
    );
  }

  Future<void> _onUpdateEvent(
    UpdateCalendarEvent event,
    Emitter<CalendarPageState> emit,
  ) async {
    final current = state;
    if (current is! CalendarPageLoaded) return;
    final normalized = event.event.copyWith(
      startDate: _dateOnly(event.event.startDate),
    );
    try {
      await _service.upsert(normalized);
    } catch (e) {
      debugPrint('[CalendarBloc] Update error: $e');
      return;
    }
    emit(current.copyWith(allEvents: List.unmodifiable(_service.events)));
  }

  Future<void> _onDeleteEvent(
    DeleteCalendarEvent event,
    Emitter<CalendarPageState> emit,
  ) async {
    final current = state;
    if (current is! CalendarPageLoaded) return;
    final hasEvent = current.allEvents.any((e) => e.id == event.eventId);
    if (!hasEvent) return;
    try {
      await _service.deleteById(event.eventId);
    } catch (e) {
      debugPrint('[CalendarBloc] Delete error: $e');
      return;
    }
    emit(current.copyWith(allEvents: List.unmodifiable(_service.events)));
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }
}
