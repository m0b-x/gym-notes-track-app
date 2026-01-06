import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app settings using SharedPreferences
class SettingsService {
  static SettingsService? _instance;
  late SharedPreferences _prefs;

  // Settings keys
  static const String _keyFolderSwipeEnabled = 'folder_swipe_enabled';
  static const String _keyNoteSwipeEnabled = 'note_swipe_enabled';
  static const String _keyConfirmDelete = 'confirm_delete';
  static const String _keyAutoSaveEnabled = 'auto_save_enabled';
  static const String _keyAutoSaveInterval = 'auto_save_interval';
  static const String _keyShowNotePreview = 'show_note_preview';
  static const String _keyDefaultNotesSortOrder = 'default_notes_sort_order';
  static const String _keyHapticFeedback = 'haptic_feedback';

  static const String defaultDateFormat = 'MMMM d, yyyy';
  static const String dateFormatKey = 'date_format';

  SettingsService._();

  static Future<SettingsService> getInstance() async {
    if (_instance == null) {
      _instance = SettingsService._();
      _instance!._prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  // Folder swipe gesture (to open drawer)
  bool get folderSwipeEnabled => _prefs.getBool(_keyFolderSwipeEnabled) ?? true;
  Future<void> setFolderSwipeEnabled(bool value) async {
    await _prefs.setBool(_keyFolderSwipeEnabled, value);
  }

  // Note swipe gesture (to open drawer)
  bool get noteSwipeEnabled => _prefs.getBool(_keyNoteSwipeEnabled) ?? true;
  Future<void> setNoteSwipeEnabled(bool value) async {
    await _prefs.setBool(_keyNoteSwipeEnabled, value);
  }

  // Confirm before delete
  bool get confirmDelete => _prefs.getBool(_keyConfirmDelete) ?? true;
  Future<void> setConfirmDelete(bool value) async {
    await _prefs.setBool(_keyConfirmDelete, value);
  }

  // Auto-save
  bool get autoSaveEnabled => _prefs.getBool(_keyAutoSaveEnabled) ?? true;
  Future<void> setAutoSaveEnabled(bool value) async {
    await _prefs.setBool(_keyAutoSaveEnabled, value);
  }

  // Auto-save interval in seconds
  int get autoSaveInterval => _prefs.getInt(_keyAutoSaveInterval) ?? 5;
  Future<void> setAutoSaveInterval(int seconds) async {
    await _prefs.setInt(_keyAutoSaveInterval, seconds);
  }

  // Show note preview in list
  bool get showNotePreview => _prefs.getBool(_keyShowNotePreview) ?? true;
  Future<void> setShowNotePreview(bool value) async {
    await _prefs.setBool(_keyShowNotePreview, value);
  }

  // Default notes sort order (0 = updatedDesc, 1 = updatedAsc, 2 = titleAsc, 3 = titleDesc, 4 = createdDesc, 5 = createdAsc)
  int get defaultNotesSortOrder =>
      _prefs.getInt(_keyDefaultNotesSortOrder) ?? 0;
  Future<void> setDefaultNotesSortOrder(int value) async {
    await _prefs.setInt(_keyDefaultNotesSortOrder, value);
  }

  // Haptic feedback
  bool get hapticFeedback => _prefs.getBool(_keyHapticFeedback) ?? true;
  Future<void> setHapticFeedback(bool value) async {
    await _prefs.setBool(_keyHapticFeedback, value);
  }
}
