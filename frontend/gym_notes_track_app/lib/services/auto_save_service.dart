import 'dart:async';
import 'package:flutter/foundation.dart';

enum SaveStatus { saved, unsaved, saving, error }

class AutoSaveService {
  final Duration saveInterval;
  final Duration debounceDelay;
  final Future<void> Function(String noteId, String? title, String? content)
  onSave;
  final void Function(String noteId, bool hasChanges)? onChangeDetected;

  // Fingerprint of the last-saved content — avoids storing a full copy.
  final Map<String, int> _originalContentHash = {};
  final Map<String, int> _originalContentLength = {};
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

  // Lazy content providers — content is only materialised when a save fires,
  // not on every keystroke.  This avoids keeping a full content copy in RAM.
  final Map<String, String Function()> _contentProviders = {};
  final Map<String, String> _latestTitle = {};

  AutoSaveService({
    required this.onSave,
    this.onChangeDetected,
    this.saveInterval = const Duration(seconds: 30),
    this.debounceDelay = const Duration(seconds: 5),
  });

  // ---- Tracking lifecycle ----

  void startTracking(
    String noteId,
    String title,
    String content, {
    required String Function() contentProvider,
  }) {
    _originalTitle[noteId] = title;
    _originalContentHash[noteId] = content.hashCode;
    _originalContentLength[noteId] = content.length;
    _contentProviders[noteId] = contentProvider;
    _latestTitle[noteId] = title;
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
    _originalContentHash.remove(noteId);
    _originalContentLength.remove(noteId);
    _contentProviders.remove(noteId);
    _latestTitle.remove(noteId);
    _hasPendingChanges.remove(noteId);
  }

  // ---- Content changed (called on every keystroke) ----

  /// Notify that the user edited content.  No content string is required —
  /// the actual text is read lazily from the [contentProvider] only when a
  /// save is triggered (debounce / periodic / force).  This avoids a 500 KB+
  /// String allocation on every keystroke.
  void onContentChanged(String noteId, String currentTitle) {
    _latestTitle[noteId] = currentTitle;

    // Mark dirty — actual change detection happens at save time.
    _hasPendingChanges[noteId] = true;
    _updateStatus(SaveStatus.unsaved);
    onChangeDetected?.call(noteId, true);

    _debounceTimers[noteId]?.cancel();
    _debounceTimers[noteId] = Timer(debounceDelay, () async {
      await _checkAndSave(noteId);
    });
  }

  // ---- Internal save helpers ----

  Future<void> _checkAndSave(String noteId) async {
    if (_hasPendingChanges[noteId] != true) return;

    final currentTitle = _latestTitle[noteId];
    final currentContent = _contentProviders[noteId]?.call();

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
    final titleChanged = currentTitle != originalTitle;
    final contentChanged =
        currentContent.length != (_originalContentLength[noteId] ?? 0) ||
        currentContent.hashCode != (_originalContentHash[noteId] ?? 0);

    if (!titleChanged && !contentChanged) {
      // Content matches the last-saved fingerprint — nothing to persist.
      _hasPendingChanges[noteId] = false;
      _updateStatus(SaveStatus.saved);
      onChangeDetected?.call(noteId, false);
      return;
    }

    _updateStatus(SaveStatus.saving);

    try {
      await onSave(
        noteId,
        titleChanged ? currentTitle : null,
        contentChanged ? currentContent : null,
      );

      _originalTitle[noteId] = currentTitle;
      _originalContentHash[noteId] = currentContent.hashCode;
      _originalContentLength[noteId] = currentContent.length;
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
  ///
  /// When [content] is omitted the content provider registered in
  /// [startTracking] is called to obtain the current text, avoiding an
  /// extra allocation by the caller.
  Future<void> forceSave(
    String noteId, {
    String? title,
    String? content,
  }) async {
    _debounceTimers[noteId]?.cancel();
    final saveTitle = title ?? _latestTitle[noteId];
    final saveContent = content ?? _contentProviders[noteId]?.call();
    if (saveTitle == null || saveContent == null) return;
    _latestTitle[noteId] = saveTitle;
    await _performSave(noteId, saveTitle, saveContent);
  }

  /// Flush all tracked notes that have pending changes.
  /// Ideal for app‑lifecycle events (pause / detach) where you don't know
  /// which specific noteId is dirty.
  Future<void> flushAll() async {
    for (final noteId in _hasPendingChanges.keys.toList()) {
      if (_hasPendingChanges[noteId] != true) continue;
      final title = _latestTitle[noteId];
      final content = _contentProviders[noteId]?.call();
      if (title == null || content == null) continue;
      await _performSave(noteId, title, content);
    }
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
    _originalContentHash.clear();
    _originalContentLength.clear();
    _contentProviders.clear();
    _latestTitle.clear();
    _hasPendingChanges.clear();
    saveStatusNotifier.dispose();
  }
}

/// Internal helper to remember a failed save for retry.
class _PendingSave {
  final String noteId;
  final String title;
  final String content;
  const _PendingSave(this.noteId, this.title, this.content);
}
