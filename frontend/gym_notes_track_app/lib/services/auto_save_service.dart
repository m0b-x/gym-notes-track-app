import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/isolate_worker.dart';

// ---------------------------------------------------------------------------
// Save status
// ---------------------------------------------------------------------------

/// Represents the current save state of a note.
enum SaveStatus {
  /// All changes are persisted – nothing to save.
  saved,

  /// The user has made edits that have not been persisted yet.
  unsaved,

  /// A save operation is in progress right now.
  saving,

  /// The last save attempt failed. A retry is scheduled.
  error,
}

// ---------------------------------------------------------------------------
// Diff helpers (unchanged)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// AutoSaveService
// ---------------------------------------------------------------------------

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

  // --- Save‑status tracking ---
  final ValueNotifier<SaveStatus> saveStatusNotifier = ValueNotifier(
    SaveStatus.saved,
  );

  // --- Retry state ---
  static const int _maxRetries = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  Timer? _retryTimer;
  int _retryCount = 0;
  _PendingSave? _lastFailedSave;

  // Track the latest content so lifecycle / retry saves use fresh data
  final Map<String, String> _latestTitle = {};
  final Map<String, String> _latestContent = {};

  AutoSaveService({
    required this.onSave,
    this.onChangeDetected,
    this.saveInterval = const Duration(seconds: 30),
    this.debounceDelay = const Duration(seconds: 5),
    DiffService? diffService,
  }) : _diffService = diffService ?? DiffService();

  // ---- Tracking lifecycle ----

  void startTracking(String noteId, String title, String content) {
    _originalTitle[noteId] = title;
    _originalContent[noteId] = content;
    _latestTitle[noteId] = title;
    _latestContent[noteId] = content;
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
    _latestTitle.remove(noteId);
    _latestContent.remove(noteId);
    _hasPendingChanges.remove(noteId);
  }

  // ---- Content changed (called on every keystroke) ----

  void onContentChanged(
    String noteId,
    String currentTitle,
    String currentContent,
  ) {
    // Always keep track of the very latest content for lifecycle saves.
    _latestTitle[noteId] = currentTitle;
    _latestContent[noteId] = currentContent;

    final originalTitle = _originalTitle[noteId] ?? '';
    final originalContent = _originalContent[noteId] ?? '';

    final titleChanged = currentTitle != originalTitle;
    final contentChanged = _diffService.quickHasChanges(
      originalContent,
      currentContent,
    );

    final hasChanges = titleChanged || contentChanged;
    _hasPendingChanges[noteId] = hasChanges;

    if (hasChanges) {
      _updateStatus(SaveStatus.unsaved);
    }

    onChangeDetected?.call(noteId, hasChanges);

    if (!hasChanges) return;

    _debounceTimers[noteId]?.cancel();
    _debounceTimers[noteId] = Timer(debounceDelay, () async {
      await _performSave(noteId, currentTitle, currentContent);
    });
  }

  // ---- Internal save helpers ----

  Future<void> _checkAndSave(String noteId) async {
    if (_hasPendingChanges[noteId] != true) return;

    final currentTitle = _latestTitle[noteId];
    final currentContent = _latestContent[noteId];

    if (currentTitle == null || currentContent == null) return;

    await _performSave(noteId, currentTitle, currentContent);
  }

  /// Central save method – handles status updates and error recovery.
  Future<void> _performSave(
    String noteId,
    String currentTitle,
    String currentContent,
  ) async {
    final originalTitle = _originalTitle[noteId] ?? '';
    final originalContent = _originalContent[noteId] ?? '';

    final titleChanged = currentTitle != originalTitle;
    final contentChanged = currentContent != originalContent;

    if (!titleChanged && !contentChanged) return;

    _updateStatus(SaveStatus.saving);

    try {
      await onSave(
        noteId,
        titleChanged ? currentTitle : null,
        contentChanged ? currentContent : null,
      );

      _originalTitle[noteId] = currentTitle;
      _originalContent[noteId] = currentContent;
      _hasPendingChanges[noteId] = false;
      _retryCount = 0;
      _lastFailedSave = null;
      _retryTimer?.cancel();

      _updateStatus(SaveStatus.saved);
      onChangeDetected?.call(noteId, false);
    } catch (e, stackTrace) {
      debugPrint('[AutoSaveService] Save failed: $e');
      debugPrintStack(stackTrace: stackTrace, maxFrames: 5);

      _lastFailedSave = _PendingSave(noteId, currentTitle, currentContent);
      _updateStatus(SaveStatus.error);
      _scheduleRetry();
    }
  }

  // ---- Retry with exponential back‑off ----

  void _scheduleRetry() {
    if (_retryCount >= _maxRetries) {
      debugPrint(
        '[AutoSaveService] Max retries ($_maxRetries) reached – giving up until next edit.',
      );
      return;
    }

    final delay = _initialRetryDelay * (1 << _retryCount); // 2s, 4s, 8s
    _retryCount++;

    debugPrint(
      '[AutoSaveService] Scheduling retry #$_retryCount in ${delay.inSeconds}s',
    );

    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () async {
      final pending = _lastFailedSave;
      if (pending == null) return;
      await _performSave(pending.noteId, pending.title, pending.content);
    });
  }

  // ---- Public API ----

  /// Force an immediate save – used on back‑navigation and lifecycle events.
  Future<void> forceSave(String noteId, String title, String content) async {
    _debounceTimers[noteId]?.cancel();
    // Update latest so lifecycle calls always use fresh data
    _latestTitle[noteId] = title;
    _latestContent[noteId] = content;
    await _performSave(noteId, title, content);
  }

  /// Flush all tracked notes that have pending changes.
  /// Ideal for app‑lifecycle events (pause / detach) where you don't know
  /// which specific noteId is dirty.
  Future<void> flushAll() async {
    for (final noteId in _hasPendingChanges.keys.toList()) {
      if (_hasPendingChanges[noteId] != true) continue;
      final title = _latestTitle[noteId];
      final content = _latestContent[noteId];
      if (title == null || content == null) continue;
      await _performSave(noteId, title, content);
    }
  }

  Future<DiffResult> getDiff(String noteId, String currentContent) async {
    final originalContent = _originalContent[noteId] ?? '';
    return _diffService.computeDiff(originalContent, currentContent);
  }

  bool hasChanges(String noteId) {
    return _hasPendingChanges[noteId] ?? false;
  }

  // ---- Status helpers ----

  void _updateStatus(SaveStatus status) {
    if (saveStatusNotifier.value != status) {
      saveStatusNotifier.value = status;
    }
  }

  /// Resets the retry counter – call after the user makes a new edit so that
  /// a previously exhausted retry budget is refreshed.
  void resetRetries() {
    _retryCount = 0;
    _lastFailedSave = null;
    _retryTimer?.cancel();
  }

  // ---- Dispose ----

  void dispose() {
    _retryTimer?.cancel();
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
    _latestTitle.clear();
    _latestContent.clear();
    _hasPendingChanges.clear();
    saveStatusNotifier.dispose();
    _diffService.dispose();
  }
}

/// Internal helper to remember a failed save for retry.
class _PendingSave {
  final String noteId;
  final String title;
  final String content;
  const _PendingSave(this.noteId, this.title, this.content);
}
