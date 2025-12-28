import 'dart:async';
import '../utils/isolate_worker.dart';

class DiffResult {
  final bool hasChanges;
  final List<DiffChange> changes;
  final int originalLength;
  final int modifiedLength;

  const DiffResult({
    required this.hasChanges,
    this.changes = const [],
    this.originalLength = 0,
    this.modifiedLength = 0,
  });

  int get changeCount => changes.length;

  double get changeRatio {
    if (originalLength == 0 && modifiedLength == 0) return 0.0;
    final total = originalLength + modifiedLength;
    return changes.length / (total / 2);
  }
}

class DiffChange {
  final DiffChangeType type;
  final int line;
  final String content;
  final String? originalContent;

  const DiffChange({
    required this.type,
    required this.line,
    required this.content,
    this.originalContent,
  });
}

enum DiffChangeType { add, remove, modify }

class DiffService {
  IsolatePool? _isolatePool;
  bool _isInitialized = false;

  DiffService({IsolatePool? isolatePool}) : _isolatePool = isolatePool;

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    _isolatePool ??= IsolatePool();
    await _isolatePool!.initialize();
    _isInitialized = true;
  }

  Future<DiffResult> computeDiff(String original, String modified) async {
    if (original == modified) {
      return const DiffResult(hasChanges: false);
    }

    await _ensureInitialized();
    final result = await _isolatePool!.execute<Map<String, dynamic>>(
      'computeDiff',
      {'original': original, 'modified': modified},
    );

    if (!result.isSuccess || result.data == null) {
      return DiffResult(
        hasChanges: original != modified,
        originalLength: original.length,
        modifiedLength: modified.length,
      );
    }

    final data = result.data!;

    if (data['hasChanges'] != true) {
      return const DiffResult(hasChanges: false);
    }

    final changesData = data['changes'] as List<dynamic>? ?? [];
    final changes = changesData.map((c) {
      final changeMap = c as Map<String, dynamic>;
      return DiffChange(
        type: _parseChangeType(changeMap['type'] as String),
        line:
            changeMap['line'] as int? ?? changeMap['modifiedLine'] as int? ?? 0,
        content:
            changeMap['content'] as String? ??
            changeMap['modified'] as String? ??
            '',
        originalContent: changeMap['original'] as String?,
      );
    }).toList();

    return DiffResult(
      hasChanges: true,
      changes: changes,
      originalLength: data['originalLength'] as int? ?? original.length,
      modifiedLength: data['modifiedLength'] as int? ?? modified.length,
    );
  }

  DiffChangeType _parseChangeType(String type) {
    switch (type) {
      case 'add':
        return DiffChangeType.add;
      case 'remove':
        return DiffChangeType.remove;
      case 'modify':
        return DiffChangeType.modify;
      default:
        return DiffChangeType.modify;
    }
  }

  bool quickHasChanges(String original, String modified) {
    return original != modified;
  }

  int quickChangeCount(String original, String modified) {
    if (original == modified) return 0;

    final originalLines = original.split('\n');
    final modifiedLines = modified.split('\n');

    int changes = (originalLines.length - modifiedLines.length).abs();

    final minLength = originalLines.length < modifiedLines.length
        ? originalLines.length
        : modifiedLines.length;

    for (int i = 0; i < minLength; i++) {
      if (originalLines[i] != modifiedLines[i]) {
        changes++;
      }
    }

    return changes;
  }

  void dispose() {
    _isolatePool?.dispose();
  }
}

class AutoSaveService {
  final Duration saveInterval;
  final Duration debounceDelay;
  final Future<void> Function(String noteId, String? title, String? content)
  onSave;
  final void Function(String noteId, bool hasChanges)? onChangeDetected;

  final DiffService _diffService;
  final Map<String, String> _originalContent = {};
  final Map<String, String> _originalTitle = {};
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, Timer> _intervalTimers = {};
  final Map<String, bool> _hasPendingChanges = {};

  AutoSaveService({
    required this.onSave,
    this.onChangeDetected,
    this.saveInterval = const Duration(seconds: 30),
    this.debounceDelay = const Duration(seconds: 5),
    DiffService? diffService,
  }) : _diffService = diffService ?? DiffService();

  void startTracking(String noteId, String title, String content) {
    _originalTitle[noteId] = title;
    _originalContent[noteId] = content;
    _hasPendingChanges[noteId] = false;

    _intervalTimers[noteId]?.cancel();
    _intervalTimers[noteId] = Timer.periodic(saveInterval, (_) {
      _checkAndSave(noteId);
    });
  }

  void stopTracking(String noteId) {
    _debounceTimers[noteId]?.cancel();
    _intervalTimers[noteId]?.cancel();
    _debounceTimers.remove(noteId);
    _intervalTimers.remove(noteId);
    _originalTitle.remove(noteId);
    _originalContent.remove(noteId);
    _hasPendingChanges.remove(noteId);
  }

  void onContentChanged(
    String noteId,
    String currentTitle,
    String currentContent,
  ) {
    final originalTitle = _originalTitle[noteId] ?? '';
    final originalContent = _originalContent[noteId] ?? '';

    final titleChanged = currentTitle != originalTitle;
    final contentChanged = _diffService.quickHasChanges(
      originalContent,
      currentContent,
    );

    final hasChanges = titleChanged || contentChanged;
    _hasPendingChanges[noteId] = hasChanges;

    onChangeDetected?.call(noteId, hasChanges);

    if (!hasChanges) return;

    _debounceTimers[noteId]?.cancel();
    _debounceTimers[noteId] = Timer(debounceDelay, () {
      _saveIfChanged(noteId, currentTitle, currentContent);
    });
  }

  Future<void> _checkAndSave(String noteId) async {
    if (_hasPendingChanges[noteId] != true) return;

    final currentTitle = _originalTitle[noteId];
    final currentContent = _originalContent[noteId];

    if (currentTitle == null || currentContent == null) return;

    await _saveIfChanged(noteId, currentTitle, currentContent);
  }

  Future<void> _saveIfChanged(
    String noteId,
    String currentTitle,
    String currentContent,
  ) async {
    final originalTitle = _originalTitle[noteId] ?? '';
    final originalContent = _originalContent[noteId] ?? '';

    final titleChanged = currentTitle != originalTitle;
    final contentChanged = currentContent != originalContent;

    if (!titleChanged && !contentChanged) return;

    await onSave(
      noteId,
      titleChanged ? currentTitle : null,
      contentChanged ? currentContent : null,
    );

    _originalTitle[noteId] = currentTitle;
    _originalContent[noteId] = currentContent;
    _hasPendingChanges[noteId] = false;

    onChangeDetected?.call(noteId, false);
  }

  Future<void> forceSave(String noteId, String title, String content) async {
    _debounceTimers[noteId]?.cancel();
    await _saveIfChanged(noteId, title, content);
  }

  Future<DiffResult> getDiff(String noteId, String currentContent) async {
    final originalContent = _originalContent[noteId] ?? '';
    return _diffService.computeDiff(originalContent, currentContent);
  }

  bool hasChanges(String noteId) {
    return _hasPendingChanges[noteId] ?? false;
  }

  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    for (final timer in _intervalTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _intervalTimers.clear();
    _originalTitle.clear();
    _originalContent.clear();
    _hasPendingChanges.clear();
    _diffService.dispose();
  }
}
