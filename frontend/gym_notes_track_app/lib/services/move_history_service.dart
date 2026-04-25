import 'dart:async';
import 'package:uuid/uuid.dart';

enum MoveItemType { note, folder }

class MoveHistoryEntry {
  final String id;
  final MoveItemType itemType;
  final String itemId;
  final String itemName;
  final String? sourceParentId;
  final String? sourceParentName;
  final String? targetParentId;
  final String? targetParentName;
  final DateTime movedAt;
  final bool isUndone;

  const MoveHistoryEntry({
    required this.id,
    required this.itemType,
    required this.itemId,
    required this.itemName,
    this.sourceParentId,
    this.sourceParentName,
    this.targetParentId,
    this.targetParentName,
    required this.movedAt,
    this.isUndone = false,
  });

  MoveHistoryEntry copyWith({bool? isUndone}) => MoveHistoryEntry(
    id: id,
    itemType: itemType,
    itemId: itemId,
    itemName: itemName,
    sourceParentId: sourceParentId,
    sourceParentName: sourceParentName,
    targetParentId: targetParentId,
    targetParentName: targetParentName,
    movedAt: movedAt,
    isUndone: isUndone ?? this.isUndone,
  );
}

class MoveHistoryService {
  static const int _maxHistorySize = 20;
  static const _uuid = Uuid();

  final List<MoveHistoryEntry> _history = [];
  final _changesController = StreamController<int>.broadcast();

  Stream<int> get changes => _changesController.stream;

  List<MoveHistoryEntry> get history => List.unmodifiable(_history);

  int get undoableCount => _history.where((e) => !e.isUndone).length;

  bool isEntryUndone(String entryId) {
    final entry = _history.where((e) => e.id == entryId).firstOrNull;
    return entry == null || entry.isUndone;
  }

  void addMove({
    required MoveItemType itemType,
    required String itemId,
    required String itemName,
    String? sourceParentId,
    String? sourceParentName,
    String? targetParentId,
    String? targetParentName,
  }) {
    final now = DateTime.now();
    final entry = MoveHistoryEntry(
      id: _uuid.v4(),
      itemType: itemType,
      itemId: itemId,
      itemName: itemName,
      sourceParentId: sourceParentId,
      sourceParentName: sourceParentName,
      targetParentId: targetParentId,
      targetParentName: targetParentName,
      movedAt: now,
    );

    _history.insert(0, entry);

    if (_history.length > _maxHistorySize) {
      _history.removeRange(_maxHistorySize, _history.length);
    }

    _notifyChanges();
  }

  bool markUndone(String entryId) {
    final index = _history.indexWhere((e) => e.id == entryId);
    if (index == -1 || _history[index].isUndone) return false;
    _history[index] = _history[index].copyWith(isUndone: true);
    _notifyChanges();
    return true;
  }

  void clearHistory() {
    _history.clear();
    _notifyChanges();
  }

  void _notifyChanges() {
    if (_changesController.isClosed) return;
    _changesController.add(undoableCount);
  }

  void dispose() {
    _changesController.close();
  }
}
