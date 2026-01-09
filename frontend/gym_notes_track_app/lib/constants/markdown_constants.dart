/// Constants for markdown rendering and preview
class MarkdownConstants {
  MarkdownConstants._();

  // Thresholds
  /// Character threshold for switching to virtualized preview
  static const int virtualPreviewThreshold = 5000;

  /// Character delta threshold for content change detection
  static const int contentChangeDeltaThreshold = 500;

  // Timing
  /// Debounce duration for search content in milliseconds
  static const int searchDebounceMs = 200;

  /// Animation duration for scroll and transitions in milliseconds
  static const int animationDurationMs = 200;

  // Layout
  /// Default line height multiplier for text
  static const double lineHeight = 1.5;

  /// Cache extent for virtualized ListView
  static const int cacheExtent = 500;

  /// Default item extent for virtualized ListView
  static const double itemExtent = 32.0;

  // Heading scale factors
  static const double h1Scale = 2.0;
  static const double h2Scale = 1.5;
  static const double h3Scale = 1.25;
  static const double h4Scale = 1.125;
  static const double h5Scale = 1.0;
  static const double h6Scale = 0.875;

  // Checkbox
  /// Multiplier for checkbox icon size relative to font size
  static const double checkboxIconScale = 1.25;

  /// Indent multiplier per level for checkboxes and lists
  static const double indentPerLevel = 16.0;

  // Code block
  /// Font size for code blocks
  static const double codeBlockFontSize = 14.0;

  // Border widths
  /// Width of selection border indicator
  static const double selectionBorderWidth = 2.0;

  /// Width of quote border
  static const double quoteBorderWidth = 4.0;

  // Opacity values
  /// Opacity for unchecked checkbox icons
  static const double uncheckedCheckboxOpacity = 0.6;

  /// Opacity for checked/disabled text
  static const double checkedTextOpacity = 0.5;

  /// Opacity for quote text
  static const double quoteTextOpacity = 0.7;

  // List item widths
  /// Width reserved for numbered list numbers
  static const double numberedListNumberWidth = 24.0;
}
