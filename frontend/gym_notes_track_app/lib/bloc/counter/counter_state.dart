import 'package:equatable/equatable.dart';

import '../../models/counter.dart';

sealed class CounterState extends Equatable {
  const CounterState();

  @override
  List<Object?> get props => [];
}

final class CounterInitial extends CounterState {
  const CounterInitial();
}

final class CounterLoading extends CounterState {
  const CounterLoading();
}

final class CounterLoaded extends CounterState {
  final List<Counter> counters;
  final Map<String, int> counterValues;

  /// The noteId context that was used when [counterValues] was last loaded.
  /// Stored explicitly so bloc handlers never rely on hidden mutable state.
  final String? loadedNoteId;

  /// Values for counters whose note was picked locally on a management-page
  /// card. Key format: `"$counterId::$noteId"`. Kept separate from
  /// [counterValues] so a single card's local pick never pollutes the shared
  /// view for all other cards.
  final Map<String, int> pickedNoteValues;

  const CounterLoaded({
    this.counters = const [],
    this.counterValues = const {},
    this.loadedNoteId,
    this.pickedNoteValues = const {},
  });

  CounterLoaded copyWith({
    List<Counter>? counters,
    Map<String, int>? counterValues,
    String? loadedNoteId,
    Map<String, int>? pickedNoteValues,
  }) {
    return CounterLoaded(
      counters: counters ?? this.counters,
      counterValues: counterValues ?? this.counterValues,
      loadedNoteId: loadedNoteId ?? this.loadedNoteId,
      pickedNoteValues: pickedNoteValues ?? this.pickedNoteValues,
    );
  }

  @override
  List<Object?> get props => [
    counters,
    counterValues,
    loadedNoteId,
    pickedNoteValues,
  ];
}

final class CounterError extends CounterState {
  final String message;

  const CounterError(this.message);

  @override
  List<Object?> get props => [message];
}
