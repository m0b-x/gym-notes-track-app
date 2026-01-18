import '../constants/settings_keys.dart';
import '../database/database.dart';

/// Service for managing app settings using SQLite database
class SettingsService {
  static SettingsService? _instance;
  late AppDatabase _db;

  SettingsService._();

  static Future<SettingsService> getInstance() async {
    if (_instance == null) {
      _instance = SettingsService._();
      _instance!._db = await AppDatabase.getInstance();
    }
    return _instance!;
  }

  // Helper methods for type conversion
  Future<bool> _getBool(String key, bool defaultValue) async {
    final value = await _db.userSettingsDao.getValue(key);
    if (value == null) return defaultValue;
    return value == 'true';
  }

  Future<void> _setBool(String key, bool value) async {
    await _db.userSettingsDao.setValue(key, value.toString());
  }

  Future<int> _getInt(String key, int defaultValue) async {
    final value = await _db.userSettingsDao.getValue(key);
    if (value == null) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }

  Future<void> _setInt(String key, int value) async {
    await _db.userSettingsDao.setValue(key, value.toString());
  }

  // Folder swipe gesture (to open drawer)
  Future<bool> getFolderSwipeEnabled() async {
    return _getBool(
      SettingsKeys.folderSwipeEnabled,
      SettingsKeys.defaultFolderSwipeEnabled,
    );
  }

  Future<void> setFolderSwipeEnabled(bool value) async {
    await _setBool(SettingsKeys.folderSwipeEnabled, value);
  }

  // Note swipe gesture (to open drawer)
  Future<bool> getNoteSwipeEnabled() async {
    return _getBool(
      SettingsKeys.noteSwipeEnabled,
      SettingsKeys.defaultNoteSwipeEnabled,
    );
  }

  Future<void> setNoteSwipeEnabled(bool value) async {
    await _setBool(SettingsKeys.noteSwipeEnabled, value);
  }

  // Confirm before delete
  Future<bool> getConfirmDelete() async {
    return _getBool(
      SettingsKeys.confirmDelete,
      SettingsKeys.defaultConfirmDelete,
    );
  }

  Future<void> setConfirmDelete(bool value) async {
    await _setBool(SettingsKeys.confirmDelete, value);
  }

  // Auto-save
  Future<bool> getAutoSaveEnabled() async {
    return _getBool(
      SettingsKeys.autoSaveEnabled,
      SettingsKeys.defaultAutoSaveEnabled,
    );
  }

  Future<void> setAutoSaveEnabled(bool value) async {
    await _setBool(SettingsKeys.autoSaveEnabled, value);
  }

  // Auto-save interval in seconds
  Future<int> getAutoSaveInterval() async {
    return _getInt(
      SettingsKeys.autoSaveInterval,
      SettingsKeys.defaultAutoSaveInterval,
    );
  }

  Future<void> setAutoSaveInterval(int seconds) async {
    await _setInt(SettingsKeys.autoSaveInterval, seconds);
  }

  // Show note preview in list
  Future<bool> getShowNotePreview() async {
    return _getBool(
      SettingsKeys.showNotePreview,
      SettingsKeys.defaultShowNotePreview,
    );
  }

  Future<void> setShowNotePreview(bool value) async {
    await _setBool(SettingsKeys.showNotePreview, value);
  }

  // Show stats bar in note editor
  Future<bool> getShowStatsBar() async {
    return _getBool(
      SettingsKeys.showStatsBar,
      SettingsKeys.defaultShowStatsBar,
    );
  }

  Future<void> setShowStatsBar(bool value) async {
    await _setBool(SettingsKeys.showStatsBar, value);
  }

  // Default notes sort order (0 = updatedDesc, 1 = updatedAsc, 2 = titleAsc, 3 = titleDesc, 4 = createdDesc, 5 = createdAsc)
  Future<int> getDefaultNotesSortOrder() async {
    return _getInt(
      SettingsKeys.defaultNotesSortOrder,
      SettingsKeys.defaultDefaultNotesSortOrder,
    );
  }

  Future<void> setDefaultNotesSortOrder(int value) async {
    await _setInt(SettingsKeys.defaultNotesSortOrder, value);
  }

  // Haptic feedback
  Future<bool> getHapticFeedback() async {
    return _getBool(
      SettingsKeys.hapticFeedback,
      SettingsKeys.defaultHapticFeedback,
    );
  }

  Future<void> setHapticFeedback(bool value) async {
    await _setBool(SettingsKeys.hapticFeedback, value);
  }

  // Editor settings - Show line numbers
  Future<bool> getShowLineNumbers() async {
    return _getBool(
      SettingsKeys.showLineNumbers,
      SettingsKeys.defaultShowLineNumbers,
    );
  }

  Future<void> setShowLineNumbers(bool value) async {
    await _setBool(SettingsKeys.showLineNumbers, value);
  }

  // Editor settings - Word wrap
  Future<bool> getWordWrap() async {
    return _getBool(SettingsKeys.wordWrap, SettingsKeys.defaultWordWrap);
  }

  Future<void> setWordWrap(bool value) async {
    await _setBool(SettingsKeys.wordWrap, value);
  }

  // Editor settings - Show cursor line highlight
  Future<bool> getShowCursorLine() async {
    return _getBool(
      SettingsKeys.showCursorLine,
      SettingsKeys.defaultShowCursorLine,
    );
  }

  Future<void> setShowCursorLine(bool value) async {
    await _setBool(SettingsKeys.showCursorLine, value);
  }

  // Editor settings - Auto break long lines on paste
  Future<bool> getAutoBreakLongLines() async {
    return _getBool(
      SettingsKeys.autoBreakLongLines,
      SettingsKeys.defaultAutoBreakLongLines,
    );
  }

  Future<void> setAutoBreakLongLines(bool value) async {
    await _setBool(SettingsKeys.autoBreakLongLines, value);
  }

  // Editor settings - Show preview when keyboard is hidden
  Future<bool> getPreviewWhenKeyboardHidden() async {
    return _getBool(
      SettingsKeys.previewWhenKeyboardHidden,
      SettingsKeys.defaultPreviewWhenKeyboardHidden,
    );
  }

  Future<void> setPreviewWhenKeyboardHidden(bool value) async {
    await _setBool(SettingsKeys.previewWhenKeyboardHidden, value);
  }

  // Preview settings - Show scrollbar
  Future<bool> getShowPreviewScrollbar() async {
    return _getBool(
      SettingsKeys.showPreviewScrollbar,
      SettingsKeys.defaultShowPreviewScrollbar,
    );
  }

  Future<void> setShowPreviewScrollbar(bool value) async {
    await _setBool(SettingsKeys.showPreviewScrollbar, value);
  }

  // Preview performance - Lines per chunk
  Future<int> getPreviewLinesPerChunk() async {
    return _getInt(
      SettingsKeys.previewLinesPerChunk,
      SettingsKeys.defaultPreviewLinesPerChunk,
    );
  }

  Future<void> setPreviewLinesPerChunk(int value) async {
    await _setInt(SettingsKeys.previewLinesPerChunk, value);
  }

  Future<bool> isOnboardingCompleted() async {
    return _getBool(SettingsKeys.onboardingCompleted, false);
  }

  Future<void> setOnboardingCompleted(bool value) async {
    await _setBool(SettingsKeys.onboardingCompleted, value);
  }
}
