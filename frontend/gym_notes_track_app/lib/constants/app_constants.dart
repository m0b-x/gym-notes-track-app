class AppConstants {
  // ============================================================
  // SHARED PREFERENCES KEYS (for device-local state only)
  // ============================================================
  static const String recentSearchesKey = 'recent_searches';

  // ============================================================
  // TIMING CONSTANTS
  // ============================================================
  static const Duration autoSaveInterval = Duration(seconds: 30);
  static const Duration autoSaveDelay = Duration(seconds: 5);
  static const Duration debounceDelay = Duration(milliseconds: 500);
  static const Duration longPressDelay = Duration(milliseconds: 300);
  static const Duration shortDelay = Duration(milliseconds: 100);
  static const Duration animationDuration = Duration(milliseconds: 200);
  static const Duration historyDebounceDuration = Duration(milliseconds: 400);
  static const Duration autoScrollTickDuration = Duration(milliseconds: 50);

  // ============================================================
  // UI CONSTANTS
  // ============================================================
  static const double edgeScrollThreshold = 80.0;
  static const double autoScrollSpeed = 10.0;

  // Markdown toolbar sizing
  static const double markdownToolbarPadding = 8.0;
  static const double markdownToolbarButtonPadding = 10.0;
  static const double markdownToolbarButtonMargin = 2.0;
  static const double markdownToolbarIconSize = 20.0;
  static const double markdownToolbarTextSize = 16.0;

  // ============================================================
  // PAGINATION CONSTANTS
  // ============================================================
  static const int defaultPageSize = 20;

  // ============================================================
  // CACHE CONSTANTS
  // ============================================================
  static const int maxNoteCacheSize = 200;
  static const int maxContentCacheSize = 50;
  static const int maxFolderCacheSize = 100;
  static const Duration cacheExpiry = Duration(minutes: 5);

  // ============================================================
  // CONTENT CONSTANTS
  // ============================================================
  static const int defaultChunkSize = 10000; // 10KB chunks
  static const int compressionThreshold = 5000;
  static const int previewMaxLength = 200;

  // ============================================================
  // SEARCH CONSTANTS
  // ============================================================
  static const int maxRecentSearches = 10;
  static const int maxSearchMatches = 1000;

  // ============================================================
  // PREVIEW CONSTANTS
  // ============================================================
  /// Notes under this line count get instant preview switching (pre-loaded offstage).
  /// Larger notes use lazy loading with a short scroll animation to avoid memory overhead.
  static const int previewPreloadLineThreshold = 3000;

  AppConstants._();
}
