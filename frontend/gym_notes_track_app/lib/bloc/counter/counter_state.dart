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

  const CounterLoaded({
    this.counters = const [],
    this.counterValues = const {},
  });

  CounterLoaded copyWith({
    List<Counter>? counters,
    Map<String, int>? counterValues,
  }) {
    return CounterLoaded(
      counters: counters ?? this.counters,
      counterValues: counterValues ?? this.counterValues,
    );
  }

  @override
  List<Object?> get props => [counters, counterValues];
}

final class CounterError extends CounterState {
  final String message;

  const CounterError(this.message);

  @override
  List<Object?> get props => [message];
}
