import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../models/counter.dart';

class CounterService {
  static CounterService? _instance;
  late AppDatabase _db;

  static const String _countersKey = 'counters';
  static const String _globalValuesKey = 'counter_global_values';
  static const String _noteValuesPrefix = 'counter_note_values_';

  List<Counter> _counters = [];
  Map<String, int> _globalValues = {};

  CounterService._();

  static Future<CounterService> getInstance() async {
    if (_instance == null) {
      _instance = CounterService._();
      _instance!._db = await AppDatabase.getInstance();
      await _instance!._load();
    }
    return _instance!;
  }

  static void reset() {
    _instance = null;
  }

  List<Counter> get counters => List.unmodifiable(_counters);

  Future<void> _load() async {
    final raw = await _db.userSettingsDao.getValue(_countersKey);
    if (raw != null) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        _counters = decoded
            .map((j) => Counter.fromJson(j as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('[CounterService] Error decoding counters: $e');
        _counters = [];
      }
    }

    final valuesRaw = await _db.userSettingsDao.getValue(_globalValuesKey);
    if (valuesRaw != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(valuesRaw);
        _globalValues = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (e) {
        debugPrint('[CounterService] Error decoding global values: $e');
        _globalValues = {};
      }
    }
  }

  Future<void> _persistCounters() async {
    await _db.userSettingsDao.setValue(
      _countersKey,
      jsonEncode(_counters.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> _persistGlobalValues() async {
    await _db.userSettingsDao.setValue(
      _globalValuesKey,
      jsonEncode(_globalValues),
    );
  }

  Future<String> addCounter({
    required String name,
    int startValue = 1,
    int step = 1,
    CounterScope scope = CounterScope.global,
  }) async {
    final id = const Uuid().v4();
    final counter = Counter(
      id: id,
      name: name.trim().isEmpty ? 'Counter' : name.trim(),
      startValue: startValue,
      step: step,
      scope: scope,
      createdAt: DateTime.now(),
    );
    _counters.add(counter);
    _globalValues[id] = startValue;
    await _persistCounters();
    await _persistGlobalValues();
    return id;
  }

  Future<void> updateCounter(Counter updated) async {
    final index = _counters.indexWhere((c) => c.id == updated.id);
    if (index < 0) return;
    _counters[index] = updated;
    await _persistCounters();
  }

  Future<void> reorderCounters(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final counter = _counters.removeAt(oldIndex);
    _counters.insert(newIndex, counter);
    await _persistCounters();
  }

  Future<void> deleteCounter(String counterId) async {
    _counters.removeWhere((c) => c.id == counterId);
    _globalValues.remove(counterId);
    await _persistCounters();
    await _persistGlobalValues();
  }

  int getGlobalValue(String counterId) {
    final counter = _counters.firstWhere(
      (c) => c.id == counterId,
      orElse: () => throw StateError('Counter not found: $counterId'),
    );
    return _globalValues[counterId] ?? counter.startValue;
  }

  Future<int> incrementGlobal(String counterId) async {
    final counter = _counters.firstWhere(
      (c) => c.id == counterId,
      orElse: () => throw StateError('Counter not found: $counterId'),
    );
    final current = _globalValues[counterId] ?? counter.startValue;
    final next = current + counter.step;
    _globalValues[counterId] = next;
    await _persistGlobalValues();
    return current;
  }

  Future<void> resetGlobal(String counterId) async {
    final counter = _counters.firstWhere(
      (c) => c.id == counterId,
      orElse: () => throw StateError('Counter not found: $counterId'),
    );
    _globalValues[counterId] = counter.startValue;
    await _persistGlobalValues();
  }

  Future<void> decrementGlobal(String counterId) async {
    final counter = _counters.firstWhere(
      (c) => c.id == counterId,
      orElse: () => throw StateError('Counter not found: $counterId'),
    );
    final current = _globalValues[counterId] ?? counter.startValue;
    _globalValues[counterId] = current - counter.step;
    await _persistGlobalValues();
  }

  Future<void> setGlobalValue(String counterId, int value) async {
    if (!_counters.any((c) => c.id == counterId)) return;
    _globalValues[counterId] = value;
    await _persistGlobalValues();
  }

  Future<void> decrementForNote(String counterId, String noteId) async {
    final counter = _counters.firstWhere(
      (c) => c.id == counterId,
      orElse: () => throw StateError('Counter not found: $counterId'),
    );

    if (counter.scope == CounterScope.global) {
      await decrementGlobal(counterId);
      return;
    }

    final noteValues = await getNoteValues(noteId);
    final current = noteValues[counterId] ?? counter.startValue;
    noteValues[counterId] = current - counter.step;
    await _db.userSettingsDao.setValue(
      '$_noteValuesPrefix$noteId',
      jsonEncode(noteValues),
    );
  }

  Future<void> setValueForNote(
    String counterId,
    int value, {
    String? noteId,
  }) async {
    final counter = getCounterById(counterId);
    if (counter == null) return;

    if (counter.scope == CounterScope.global || noteId == null) {
      await setGlobalValue(counterId, value);
      return;
    }

    final noteValues = await getNoteValues(noteId);
    noteValues[counterId] = value;
    await _db.userSettingsDao.setValue(
      '$_noteValuesPrefix$noteId',
      jsonEncode(noteValues),
    );
  }

  Future<Map<String, int>> getNoteValues(String noteId) async {
    final raw = await _db.userSettingsDao.getValue('$_noteValuesPrefix$noteId');
    if (raw == null) return {};
    try {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      return decoded.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  Future<int> getValueForNote(String counterId, String noteId) async {
    final counter = _counters.firstWhere(
      (c) => c.id == counterId,
      orElse: () => throw StateError('Counter not found: $counterId'),
    );
    if (counter.scope == CounterScope.global) {
      return getGlobalValue(counterId);
    }
    final noteValues = await getNoteValues(noteId);
    return noteValues[counterId] ?? counter.startValue;
  }

  Future<int> increment(String counterId, {String? noteId}) async {
    final counter = _counters.firstWhere(
      (c) => c.id == counterId,
      orElse: () => throw StateError('Counter not found: $counterId'),
    );

    if (counter.scope == CounterScope.global) {
      return incrementGlobal(counterId);
    }

    if (noteId == null) return counter.startValue;

    final noteValues = await getNoteValues(noteId);
    final current = noteValues[counterId] ?? counter.startValue;
    noteValues[counterId] = current + counter.step;
    await _db.userSettingsDao.setValue(
      '$_noteValuesPrefix$noteId',
      jsonEncode(noteValues),
    );
    return current;
  }

  Future<void> resetForNote(String counterId, String noteId) async {
    final counter = _counters.firstWhere(
      (c) => c.id == counterId,
      orElse: () => throw StateError('Counter not found: $counterId'),
    );

    if (counter.scope == CounterScope.global) {
      await resetGlobal(counterId);
      return;
    }

    final noteValues = await getNoteValues(noteId);
    noteValues[counterId] = counter.startValue;
    await _db.userSettingsDao.setValue(
      '$_noteValuesPrefix$noteId',
      jsonEncode(noteValues),
    );
  }

  Counter? getCounterById(String counterId) {
    try {
      return _counters.firstWhere((c) => c.id == counterId);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> exportData() async {
    return {
      'counters': jsonEncode(_counters.map((c) => c.toJson()).toList()),
      'globalValues': jsonEncode(_globalValues),
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    final countersRaw = data['counters'] as String?;
    if (countersRaw != null) {
      await _db.userSettingsDao.setValue(_countersKey, countersRaw);
    }
    final valuesRaw = data['globalValues'] as String?;
    if (valuesRaw != null) {
      await _db.userSettingsDao.setValue(_globalValuesKey, valuesRaw);
    }
    await _load();
  }
}
