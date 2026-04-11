import 'package:equatable/equatable.dart';

import '../../models/counter.dart';

sealed class CounterEvent extends Equatable {
  const CounterEvent();

  @override
  List<Object?> get props => [];
}

final class LoadCounters extends CounterEvent {
  final String? noteId;

  const LoadCounters({this.noteId});

  @override
  List<Object?> get props => [noteId];
}

final class AddCounter extends CounterEvent {
  final String name;
  final int startValue;
  final int step;
  final CounterScope scope;

  const AddCounter({
    required this.name,
    this.startValue = 1,
    this.step = 1,
    this.scope = CounterScope.global,
  });

  @override
  List<Object?> get props => [name, startValue, step, scope];
}

final class UpdateCounter extends CounterEvent {
  final Counter counter;

  const UpdateCounter({required this.counter});

  @override
  List<Object?> get props => [counter];
}

final class DeleteCounter extends CounterEvent {
  final String counterId;

  const DeleteCounter({required this.counterId});

  @override
  List<Object?> get props => [counterId];
}

final class ResetCounter extends CounterEvent {
  final String counterId;
  final String? noteId;

  const ResetCounter({required this.counterId, this.noteId});

  @override
  List<Object?> get props => [counterId, noteId];
}

final class IncrementCounter extends CounterEvent {
  final String counterId;
  final String? noteId;

  const IncrementCounter({required this.counterId, this.noteId});

  @override
  List<Object?> get props => [counterId, noteId];
}

final class DecrementCounter extends CounterEvent {
  final String counterId;
  final String? noteId;

  const DecrementCounter({required this.counterId, this.noteId});

  @override
  List<Object?> get props => [counterId, noteId];
}

final class SetCounterValue extends CounterEvent {
  final String counterId;
  final int value;
  final String? noteId;

  const SetCounterValue({
    required this.counterId,
    required this.value,
    this.noteId,
  });

  @override
  List<Object?> get props => [counterId, value, noteId];
}

final class RefreshCounters extends CounterEvent {
  const RefreshCounters();
}

final class ReorderCounters extends CounterEvent {
  final int oldIndex;
  final int newIndex;

  const ReorderCounters({required this.oldIndex, required this.newIndex});

  @override
  List<Object?> get props => [oldIndex, newIndex];
}
