import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/counter_service.dart';
import '../../services/markdown_bar_service.dart';
import 'markdown_bar_event.dart';
import 'markdown_bar_state.dart';

export 'markdown_bar_event.dart';
export 'markdown_bar_state.dart';

class MarkdownBarBloc extends Bloc<MarkdownBarEvent, MarkdownBarState> {
  final MarkdownBarService _barService;
  final CounterService _counterService;

  MarkdownBarBloc({
    required MarkdownBarService barService,
    required CounterService counterService,
  }) : _barService = barService,
       _counterService = counterService,
       super(const MarkdownBarInitial()) {
    on<LoadMarkdownBar>(_onLoad);
    on<AddBarProfile>(_onAddProfile);
    on<RenameBarProfile>(_onRenameProfile);
    on<DuplicateBarProfile>(_onDuplicateProfile);
    on<DeleteBarProfile>(_onDeleteProfile);
    on<SetActiveProfile>(_onSetActiveProfile);
    on<UpdateShortcuts>(_onUpdateShortcuts);
    on<SetNoteBarAssignment>(_onSetNoteBarAssignment);
    on<ResolveBarForNote>(_onResolveBarForNote);
    on<SwitchEditingProfile>(_onSwitchEditingProfile);
    on<AddCounter>(_onAddCounter);
    on<UpdateCounter>(_onUpdateCounter);
    on<DeleteCounter>(_onDeleteCounter);
    on<ResetCounter>(_onResetCounter);
    on<IncrementCounter>(_onIncrementCounter);
    on<RefreshCounters>(_onRefreshCounters);
  }

  Future<void> _onLoad(
    LoadMarkdownBar event,
    Emitter<MarkdownBarState> emit,
  ) async {
    emit(const MarkdownBarLoading());
    try {
      final profile = await _barService.resolveProfileForNote(event.noteId);
      final counters = _counterService.counters;
      final counterValues = <String, int>{};
      for (final c in counters) {
        if (event.noteId != null) {
          counterValues[c.id] = await _counterService.getValueForNote(
            c.id,
            event.noteId!,
          );
        } else {
          counterValues[c.id] = _counterService.getGlobalValue(c.id);
        }
      }

      emit(
        MarkdownBarLoaded(
          profiles: _barService.profiles,
          activeProfileId: profile.id,
          currentShortcuts: List.from(profile.shortcuts),
          counters: counters,
          counterValues: counterValues,
        ),
      );
    } catch (e) {
      debugPrint('[MarkdownBarBloc] Load error: $e');
      emit(
        MarkdownBarError(
          e.toString(),
          errorType: MarkdownBarErrorType.loadFailed,
        ),
      );
    }
  }

  Future<void> _onAddProfile(
    AddBarProfile event,
    Emitter<MarkdownBarState> emit,
  ) async {
    final current = state;
    if (current is! MarkdownBarLoaded) return;
    try {
      final newId = await _barService.addProfile(event.name);
      emit(
        current.copyWith(
          profiles: _barService.profiles,
          editingProfileId: newId,
          currentShortcuts: _barService.getShortcuts(newId),
        ),
      );
    } catch (e) {
      debugPrint('[MarkdownBarBloc] Add profile error: $e');
      emit(
        MarkdownBarError(
          e.toString(),
          errorType: MarkdownBarErrorType.saveFailed,
        ),
      );
    }
  }

  Future<void> _onRenameProfile(
    RenameBarProfile event,
    Emitter<MarkdownBarState> emit,
  ) async {
    final current = state;
    if (current is! MarkdownBarLoaded) return;
    try {
      await _barService.renameProfile(event.profileId, event.newName);
      emit(current.copyWith(profiles: _barService.profiles));
    } catch (e) {
      debugPrint('[MarkdownBarBloc] Rename profile error: $e');
      emit(
        MarkdownBarError(
          e.toString(),
          errorType: MarkdownBarErrorType.saveFailed,
        ),
      );
    }
  }

  Future<void> _onDuplicateProfile(
    DuplicateBarProfile event,
    Emitter<MarkdownBarState> emit,
  ) async {
    final current = state;
    if (current is! MarkdownBarLoaded) return;
    try {
      final newId = await _barService.duplicateProfile(
        event.sourceId,
        event.newName,
      );
      emit(
        current.copyWith(
          profiles: _barService.profiles,
          editingProfileId: newId,
          currentShortcuts: _barService.getShortcuts(newId),
        ),
      );
    } catch (e) {
      debugPrint('[MarkdownBarBloc] Duplicate profile error: $e');
      emit(
        MarkdownBarError(
          e.toString(),
          errorType: MarkdownBarErrorType.saveFailed,
        ),
      );
    }
  }

  Future<void> _onDeleteProfile(
    DeleteBarProfile event,
    Emitter<MarkdownBarState> emit,
  ) async {
    final current = state;
    if (current is! MarkdownBarLoaded) return;
    try {
      await _barService.deleteProfile(event.profileId);
      final activeId = _barService.activeProfileId;
      emit(
        current.copyWith(
          profiles: _barService.profiles,
          activeProfileId: activeId,
          editingProfileId: activeId,
          currentShortcuts: _barService.getShortcuts(activeId),
        ),
      );
    } catch (e) {
      debugPrint('[MarkdownBarBloc] Delete profile error: $e');
      emit(
        MarkdownBarError(
          e.toString(),
          errorType: MarkdownBarErrorType.saveFailed,
        ),
      );
    }
  }

  Future<void> _onSetActiveProfile(
    SetActiveProfile event,
    Emitter<MarkdownBarState> emit,
  ) async {
    final current = state;
    if (current is! MarkdownBarLoaded) return;
    try {
      await _barService.setActiveProfile(event.profileId);
      emit(
        current.copyWith(
          activeProfileId: event.profileId,
          currentShortcuts: _barService.getShortcuts(event.profileId),
        ),
      );
    } catch (e) {
      debugPrint('[MarkdownBarBloc] Set active profile error: $e');
    }
  }

  Future<void> _onUpdateShortcuts(
    UpdateShortcuts event,
    Emitter<MarkdownBarState> emit,
  ) async {
    final current = state;
    if (current is! MarkdownBarLoaded) return;
    try {
      await _barService.updateShortcuts(event.profileId, event.shortcuts);
      emit(
        current.copyWith(
          profiles: _barService.profiles,
          currentShortcuts: event.profileId == current.activeProfileId
              ? event.shortcuts
              : current.currentShortcuts,
        ),
      );
    } catch (e) {
      debugPrint('[MarkdownBarBloc] Update shortcuts error: $e');
      emit(
        MarkdownBarError(
          e.toString(),
          errorType: MarkdownBarErrorType.saveFailed,
        ),
      );
    }
  }

  Future<void> _onSetNoteBarAssignment(
    SetNoteBarAssignment event,
    Emitter<MarkdownBarState> emit,
  ) async {
    final current = state;
    if (current is! MarkdownBarLoaded) return;
    try {
      await _barService.setNoteBarId(event.noteId, event.profileId);
      final profile = await _barService.resolveProfileForNote(event.noteId);
      emit(
        current.copyWith(
          activeProfileId: profile.id,
          currentShortcuts: List.from(profile.shortcuts),
        ),
      );
    } catch (e) {
      debugPrint('[MarkdownBarBloc] Set note bar assignment error: $e');
    }
  }

  Future<void> _onResolveBarForNote(
    ResolveBarForNote event,
    Emitter<MarkdownBarState> emit,
  ) async {
    final current = state;
    if (current is! MarkdownBarLoaded) return;
    try {
      final profile = await _barService.resolveProfileForNote(event.noteId);
      emit(
        current.copyWith(
          profiles: _barService.profiles,
          activeProfileId: profile.id,
          currentShortcuts: List.from(profile.shortcuts),
        ),
      );
    } catch (e) {
      debugPrint('[MarkdownBarBloc] Resolve bar error: $e');
    }
  }

  void _onSwitchEditingProfile(
    SwitchEditingProfile event,
    Emitter<MarkdownBarState> emit,
  ) {
    final current = state;
    if (current is! MarkdownBarLoaded) return;
    emit(
      current.copyWith(
        editingProfileId: event.profileId,
        currentShortcuts: _barService.getShortcuts(event.profileId),
      ),
    );
  }

  Future<void> _onAddCounter(
    AddCounter event,
    Emitter<MarkdownBarState> emit,
  ) async {
    final current = state;
    if (current is! MarkdownBarLoaded) return;
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
          counterValues: _buildCounterValues(current),
        ),
      );
    } catch (e) {
      debugPrint('[MarkdownBarBloc] Add counter error: $e');
    }
  }

  Future<void> _onUpdateCounter(
    UpdateCounter event,
    Emitter<MarkdownBarState> emit,
  ) async {
    final current = state;
    if (current is! MarkdownBarLoaded) return;
    try {
      await _counterService.updateCounter(event.counter);
      emit(current.copyWith(counters: _counterService.counters));
    } catch (e) {
      debugPrint('[MarkdownBarBloc] Update counter error: $e');
    }
  }

  Future<void> _onDeleteCounter(
    DeleteCounter event,
    Emitter<MarkdownBarState> emit,
  ) async {
    final current = state;
    if (current is! MarkdownBarLoaded) return;
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
      debugPrint('[MarkdownBarBloc] Delete counter error: $e');
    }
  }

  Future<void> _onResetCounter(
    ResetCounter event,
    Emitter<MarkdownBarState> emit,
  ) async {
    final current = state;
    if (current is! MarkdownBarLoaded) return;
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
      debugPrint('[MarkdownBarBloc] Reset counter error: $e');
    }
  }

  Future<void> _onIncrementCounter(
    IncrementCounter event,
    Emitter<MarkdownBarState> emit,
  ) async {
    final current = state;
    if (current is! MarkdownBarLoaded) return;
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
      debugPrint('[MarkdownBarBloc] Increment counter error: $e');
    }
  }

  Future<void> _onRefreshCounters(
    RefreshCounters event,
    Emitter<MarkdownBarState> emit,
  ) async {
    final current = state;
    if (current is! MarkdownBarLoaded) return;
    emit(
      current.copyWith(
        counters: _counterService.counters,
        counterValues: _buildCounterValues(current),
      ),
    );
  }

  Map<String, int> _buildCounterValues(MarkdownBarLoaded current) {
    final values = <String, int>{};
    for (final c in _counterService.counters) {
      values[c.id] = _counterService.getGlobalValue(c.id);
    }
    return values;
  }
}
