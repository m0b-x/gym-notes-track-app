import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/counter.dart';
import '../../services/counter_service.dart';
import 'counter_event.dart';
import 'counter_state.dart';

export 'counter_event.dart';
export 'counter_state.dart';

class CounterBloc extends Bloc<CounterEvent, CounterState> {
  final CounterService _counterService;
  String? _activeNoteId;

  CounterBloc({required CounterService counterService})
    : _counterService = counterService,
      super(const CounterInitial()) {
    on<LoadCounters>(_onLoad);
    on<AddCounter>(_onAddCounter);
    on<UpdateCounter>(_onUpdateCounter);
    on<DeleteCounter>(_onDeleteCounter);
    on<ResetCounter>(_onResetCounter);
    on<IncrementCounter>(_onIncrementCounter);
    on<DecrementCounter>(_onDecrementCounter);
    on<SetCounterValue>(_onSetCounterValue);
    on<RefreshCounters>(_onRefreshCounters);
    on<ReorderCounters>(_onReorderCounters);
  }

  Future<void> _onLoad(LoadCounters event, Emitter<CounterState> emit) async {
    emit(const CounterLoading());
    _activeNoteId = event.noteId;
    try {
      final counters = _counterService.counters;
      final counterValues = <String, int>{};
      final noteValues = event.noteId != null
          ? await _counterService.getNoteValues(event.noteId!)
          : <String, int>{};
      for (final c in counters) {
        if (event.noteId != null && c.scope == CounterScope.perNote) {
          counterValues[c.id] = noteValues[c.id] ?? c.startValue;
        } else {
          counterValues[c.id] = _counterService.getGlobalValue(c.id);
        }
      }

      emit(CounterLoaded(counters: counters, counterValues: counterValues));
    } catch (e) {
      debugPrint('[CounterBloc] Load error: $e');
      emit(CounterError(e.toString()));
    }
  }

  Future<void> _onAddCounter(
    AddCounter event,
    Emitter<CounterState> emit,
  ) async {
    final current = state;
    if (current is! CounterLoaded) return;
    try {
      await _counterService.addCounter(
        name: event.name,
        startValue: event.startValue,
        step: event.step,
        scope: event.scope,
      );
      emit(
        current.copyWith(
          counters: _counterService.counters,
          counterValues: await _buildCounterValues(),
        ),
      );
    } catch (e) {
      debugPrint('[CounterBloc] Add counter error: $e');
    }
  }

  Future<void> _onUpdateCounter(
    UpdateCounter event,
    Emitter<CounterState> emit,
  ) async {
    final current = state;
    if (current is! CounterLoaded) return;
    try {
      await _counterService.updateCounter(event.counter);
      emit(current.copyWith(counters: _counterService.counters));
    } catch (e) {
      debugPrint('[CounterBloc] Update counter error: $e');
    }
  }

  Future<void> _onDeleteCounter(
    DeleteCounter event,
    Emitter<CounterState> emit,
  ) async {
    final current = state;
    if (current is! CounterLoaded) return;
    try {
      await _counterService.deleteCounter(event.counterId);
      final values = Map<String, int>.from(current.counterValues);
      values.remove(event.counterId);
      emit(
        current.copyWith(
          counters: _counterService.counters,
          counterValues: values,
        ),
      );
    } catch (e) {
      debugPrint('[CounterBloc] Delete counter error: $e');
    }
  }

  Future<void> _onResetCounter(
    ResetCounter event,
    Emitter<CounterState> emit,
  ) async {
    final current = state;
    if (current is! CounterLoaded) return;
    try {
      if (event.noteId != null) {
        await _counterService.resetForNote(event.counterId, event.noteId!);
      } else {
        await _counterService.resetGlobal(event.counterId);
      }
      final counter = _counterService.getCounterById(event.counterId);
      if (counter != null) {
        final values = Map<String, int>.from(current.counterValues);
        values[event.counterId] = counter.startValue;
        emit(current.copyWith(counterValues: values));
      }
    } catch (e) {
      debugPrint('[CounterBloc] Reset counter error: $e');
    }
  }

  Future<void> _onIncrementCounter(
    IncrementCounter event,
    Emitter<CounterState> emit,
  ) async {
    final current = state;
    if (current is! CounterLoaded) return;
    try {
      final insertedValue = await _counterService.increment(
        event.counterId,
        noteId: event.noteId,
      );
      final values = Map<String, int>.from(current.counterValues);
      final counter = _counterService.getCounterById(event.counterId);
      if (counter != null) {
        values[event.counterId] = insertedValue + counter.step;
      }
      emit(current.copyWith(counterValues: values));
    } catch (e) {
      debugPrint('[CounterBloc] Increment counter error: $e');
    }
  }

  Future<void> _onDecrementCounter(
    DecrementCounter event,
    Emitter<CounterState> emit,
  ) async {
    final current = state;
    if (current is! CounterLoaded) return;
    try {
      if (event.noteId != null) {
        await _counterService.decrementForNote(event.counterId, event.noteId!);
        final value = await _counterService.getValueForNote(
          event.counterId,
          event.noteId!,
        );
        final values = Map<String, int>.from(current.counterValues);
        values[event.counterId] = value;
        emit(current.copyWith(counterValues: values));
      } else {
        await _counterService.decrementGlobal(event.counterId);
        final values = Map<String, int>.from(current.counterValues);
        values[event.counterId] = _counterService.getGlobalValue(
          event.counterId,
        );
        emit(current.copyWith(counterValues: values));
      }
    } catch (e) {
      debugPrint('[CounterBloc] Decrement counter error: $e');
    }
  }

  Future<void> _onSetCounterValue(
    SetCounterValue event,
    Emitter<CounterState> emit,
  ) async {
    final current = state;
    if (current is! CounterLoaded) return;
    try {
      await _counterService.setValueForNote(
        event.counterId,
        event.value,
        noteId: event.noteId,
      );
      final values = Map<String, int>.from(current.counterValues);
      values[event.counterId] = event.value;
      emit(current.copyWith(counterValues: values));
    } catch (e) {
      debugPrint('[CounterBloc] Set counter value error: $e');
    }
  }

  Future<void> _onRefreshCounters(
    RefreshCounters event,
    Emitter<CounterState> emit,
  ) async {
    final current = state;
    if (current is! CounterLoaded) return;
    emit(
      current.copyWith(
        counters: _counterService.counters,
        counterValues: await _buildCounterValues(),
      ),
    );
  }

  Future<Map<String, int>> _buildCounterValues() async {
    final values = <String, int>{};
    final noteValues = _activeNoteId != null
        ? await _counterService.getNoteValues(_activeNoteId!)
        : <String, int>{};
    for (final c in _counterService.counters) {
      if (_activeNoteId != null && c.scope == CounterScope.perNote) {
        values[c.id] = noteValues[c.id] ?? c.startValue;
      } else {
        values[c.id] = _counterService.getGlobalValue(c.id);
      }
    }
    return values;
  }

  Future<void> _onReorderCounters(
    ReorderCounters event,
    Emitter<CounterState> emit,
  ) async {
    final current = state;
    if (current is! CounterLoaded) return;
    try {
      await _counterService.reorderCounters(event.oldIndex, event.newIndex);
      emit(current.copyWith(counters: _counterService.counters));
    } catch (e) {
      debugPrint('[CounterBloc] Reorder counters error: $e');
    }
  }
}
