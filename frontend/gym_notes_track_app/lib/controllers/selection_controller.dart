import 'dart:async';

import '../models/movable_item.dart';

/// In-memory controller that holds the current multi-select state for the
/// folder content page. Exposes a broadcast stream so widgets can react
/// without rebuilding the whole page.
///
/// One instance per page (do NOT register globally) — selection state is
/// inherently view-scoped.
class SelectionController {
  final Map<MovableItemRef, MovableItemRef> _selected = {};
  final _changesController = StreamController<Set<MovableItemRef>>.broadcast();

  Stream<Set<MovableItemRef>> get changes => _changesController.stream;

  bool get isActive => _selected.isNotEmpty;
  int get count => _selected.length;
  Set<MovableItemRef> get items => _selected.values.toSet();

  bool contains(MovableItemRef ref) => _selected.containsKey(ref);

  void toggle(MovableItemRef ref) {
    if (_selected.containsKey(ref)) {
      _selected.remove(ref);
    } else {
      _selected[ref] = ref;
    }
    _emit();
  }

  void add(MovableItemRef ref) {
    if (_selected.containsKey(ref)) return;
    _selected[ref] = ref;
    _emit();
  }

  void clear() {
    if (_selected.isEmpty) return;
    _selected.clear();
    _emit();
  }

  void _emit() {
    if (_changesController.isClosed) return;
    _changesController.add(items);
  }

  void dispose() {
    _changesController.close();
  }
}
