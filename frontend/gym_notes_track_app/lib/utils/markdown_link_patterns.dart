/// Regex patterns for markdown link detection, shared between the
/// preview renderer (which turns matches into tappable spans) and the
/// paste line-breaker (which protects matches from being split mid-URL).
///
/// Keeping a single source of truth for the bare-URL character class
/// guarantees that anything the preview will render as a link is also
/// preserved as one unbroken token after a paste reformat. Drift between
/// the two regexes used to manifest as URLs that rendered as links in
/// preview mode but got chopped into fragments during paste, leaving
/// only the first fragment clickable.
class MarkdownLinkPatterns {
  MarkdownLinkPatterns._();

  /// Bare autolink character class.
  ///
  /// Matches `http://...`, `https://...`, or `www....` URLs that stop at
  /// whitespace or the bracket/paren/angle characters that commonly
  /// terminate a URL inside prose. Trailing punctuation
  /// (`.`, `,`, `;`, `:`, `!`, `?`, `)`, `]`, `'`, `"`) is stripped by
  /// the preview renderer when the match is converted to a clickable
  /// span (see `_trailingPunctuation` in `LineBasedMarkdownBuilder`).
  static final RegExp bareUrl = RegExp(
    r'https?://[^\s<>()\[\]]+|www\.[^\s<>()\[\]]+',
  );
}
