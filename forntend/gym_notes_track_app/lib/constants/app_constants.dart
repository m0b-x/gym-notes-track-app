class AppConstants {
  // Storage Keys
  static const String foldersStorageKey = 'folders';
  static const String notesStorageKey = 'notes';
  static const String markdownShortcutsStorageKey = 'custom_markdown_shortcuts';

  // Auto-save timing
  static const Duration autoSaveInterval = Duration(seconds: 30);
  static const Duration autoSaveDelay = Duration(seconds: 5);

  // UI constants
  static const double edgeScrollThreshold = 80.0;
  static const double autoScrollSpeed = 10.0;
  static const Duration autoScrollTickDuration = Duration(milliseconds: 50);
  static const Duration debounceDelay = Duration(milliseconds: 500);
  static const Duration longPressDelay = Duration(milliseconds: 300);
  static const Duration shortDelay = Duration(milliseconds: 100);

  // Private constructor to prevent instantiation
  AppConstants._();
}
