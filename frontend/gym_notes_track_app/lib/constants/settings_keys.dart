import 'app_constants.dart';
class SettingsKeys {
  // Onboarding
  static const String onboardingCompleted = 'onboarding_completed';

  // Font settings
  static const String previewFontSize = 'preview_font_size';
  static const String editorFontSize = 'editor_font_size';

  // App settings (from app_settings_bloc)
  static const String locale = 'locale';
  static const String themeMode = 'theme_mode';

  // Date settings
  static const String dateFormat = 'date_format';
  static const String defaultDateFormat = 'MMMM d, yyyy';

  // Markdown settings
  static const String markdownShortcuts = 'markdown_shortcuts';
  static const String customShortcuts = 'custom_shortcuts';

  // Control settings (migrated from SharedPreferences)
  static const String folderSwipeEnabled = 'folder_swipe_enabled';
  static const String noteSwipeEnabled = 'note_swipe_enabled';
  static const String confirmDelete = 'confirm_delete';
  static const String autoSaveEnabled = 'auto_save_enabled';
  static const String autoSaveInterval = 'auto_save_interval';
  static const String showNotePreview = 'show_note_preview';
  static const String showStatsBar = 'show_stats_bar';
  static const String defaultNotesSortOrder = 'default_notes_sort_order';
  static const String hapticFeedback = 'haptic_feedback';
  static const String searchCursorBehavior = 'search_cursor_behavior';

  // Editor settings
  static const String showLineNumbers = 'show_line_numbers';
  static const String wordWrap = 'word_wrap';
  static const String showCursorLine = 'show_cursor_line';

  // Note position (prefix for per-note storage)
  static const String notePositionPrefix = 'note_position_';

  // Default values for control settings
  static const bool defaultFolderSwipeEnabled = true;
  static const bool defaultNoteSwipeEnabled = true;
  static const bool defaultConfirmDelete = true;
  static const bool defaultAutoSaveEnabled = true;
  static const int defaultAutoSaveInterval = 5;
  static const bool defaultShowNotePreview = true;
  static const bool defaultShowStatsBar = true;
  static const bool defaultHapticFeedback = true;
  static const int defaultDefaultNotesSortOrder = 0;
  static const int defaultSearchCursorBehavior = AppConstants.defaultSearchCursorBehavior;

  // Default values for editor settings
  static const bool defaultShowLineNumbers = false;
  static const bool defaultWordWrap = true;
  static const bool defaultShowCursorLine = false;
}

