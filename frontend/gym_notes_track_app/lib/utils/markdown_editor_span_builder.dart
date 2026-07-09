import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import '../constants/markdown_constants.dart';
import 'ghost_text.dart';
import 'lru_cache.dart';
import 'markdown_callout_syntax.dart';
import 'markdown_list_syntax.dart';
import 'markdown_tag_syntax.dart';

/// Live markdown rendering for the re_editor text mode (the "live
/// markdown rendering" editor setting, on by default).
///
/// Restyles one line at a time: headers at the preview's scale factors
/// (the re_editor fork gives a line whose root span sets a non-base
/// fontSize its own line height), bullets as `•`, task boxes as
/// check-glyphs, blockquote `>` as a `┃` bar with italic dimmed content,
/// `---` rules as dimmed `─` runs, `#tag` tokens tinted (render-only),
/// and `**bold**` / `*italic*` / `__bold__` / `_italic_` / `~~strike~~` /
/// `==highlight==` / `` `code` `` runs styled inline. Ghost `{{ … }}`
/// runs compose with all of it: their markers stay concealed and the
/// inner text renders dimmed in whatever style surrounds it. Lines
/// covered by the selection render their markdown markers raw (dimmed)
/// so editing never happens on concealed characters.
///
/// Hard invariant (shared with the ghost-text builder): the returned
/// span always contains exactly the source line's UTF-16 code units —
/// markers are concealed or substituted 1:1, never inserted or removed —
/// so caret/selection offsets stay in sync with the model.
///
/// Performance model: everything is O(visible lines). Built spans are
/// memoized per line text in an LRU (cleared when the style/theme
/// generation changes), so steady-state scrolling and typing rebuild
/// only the edited line and the caret's reveal lines; returning the
/// identical span instance also keeps re_editor's paragraph cache on its
/// fast path. The code-fence index is recomputed lazily, only when the
/// CodeLines instance changes (text mutations clone via
/// cloneShallowDirty; selection-only changes don't).
class MarkdownEditorSpanBuilder {
  static final RegExp _headerRe = RegExp(r'^(#{1,6}) ');

  /// Mirrors the preview's horizontal-rule pattern (`^[-*_]{3,}\s*$` on
  /// the trimmed line), with the leading indent folded into the regex so
  /// no trim allocation happens on the hot path.
  static final RegExp _ruleRe = RegExp(r'^[ \t]*[-*_]{3,}[ \t]*$');
  static final String _checkedGlyph = String.fromCharCode(
    Icons.check_box.codePoint,
  );
  static final String _uncheckedGlyph = String.fromCharCode(
    Icons.check_box_outline_blank.codePoint,
  );
  static final String? _glyphFontFamily = Icons.check_box.fontFamily;

  static const Color _transparent = Color(0x00000000);
  static const double _concealedFontSize = 0.01;
  static const double _dimAlpha = 0.45;
  static const double _codeBackgroundAlpha = 0.08;
  static const double _quoteContentAlpha = 0.8;
  static const double _ruleAlpha = 0.3;
  static const double _tagBackgroundAlpha = 0.12;
  static const int _maxInlineDepth = 3;

  /// MaterialIcons glyphs fill the em box from the baseline up, so at
  /// full size the checkbox reads taller and higher than the text.
  /// Scaling down aligns its top with the cap height.
  static const double _checkboxGlyphScale = 0.85;

  /// Lines longer than this render raw — matches the spirit of
  /// re_editor's maxLengthSingleLineRendering guard.
  static const int _maxStyledLineLength = 4096;

  static const int _spanCacheSize = 1024;

  /// Sentinel cached for lines this builder leaves unhandled, so misses
  /// and "raw" lines are distinguishable with a single lookup.
  static const TextSpan _unhandled = TextSpan();

  CodeLineEditingController? _controller;
  CodeLines? _fenceLines;
  List<bool>? _fence;

  final LruCache<String, TextSpan> _spanCache = LruCache(
    maxSize: _spanCacheSize,
  );
  TextStyle? _cacheStyle;
  Color? _cacheBaseColor;
  Color? _cachePrimary;
  bool _isDark = false;

  void bind(CodeLineEditingController controller) {
    _controller = controller;
  }

  /// Returns the restyled span for [codeLine], or `null` when this line
  /// is not handled (caller falls back to the ghost-text builder).
  TextSpan? build({
    required BuildContext context,
    required int index,
    required CodeLine codeLine,
    required TextStyle style,
  }) {
    final controller = _controller;
    if (controller == null) return null;
    final text = codeLine.text;
    if (text.isEmpty || text.length > _maxStyledLineLength) return null;
    // Fence status is positional, not textual — resolve it before the
    // text-keyed cache.
    if (_lineInFence(controller, index)) return null;

    final theme = Theme.of(context);
    final baseColor =
        style.color ?? theme.textTheme.bodyLarge?.color ?? Colors.grey;
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    if (style != _cacheStyle ||
        baseColor != _cacheBaseColor ||
        primary != _cachePrimary ||
        isDark != _isDark) {
      _spanCache.clear();
      _cacheStyle = style;
      _cacheBaseColor = baseColor;
      _cachePrimary = primary;
      _isDark = isDark;
    }

    final reveal = _selectionCoversLine(controller.selection, index);
    if (!reveal) {
      final cached = _spanCache.get(text);
      if (cached != null) {
        return identical(cached, _unhandled) ? null : cached;
      }
    }
    final span = _buildLine(
      text: text,
      style: style,
      baseColor: baseColor,
      primary: primary,
      reveal: reveal,
    );
    if (!reveal) {
      _spanCache.put(text, span ?? _unhandled);
    }
    return span;
  }

  TextSpan? _buildLine({
    required String text,
    required TextStyle style,
    required Color baseColor,
    required Color primary,
    required bool reveal,
  }) {
    final ghosts = GhostText.mightContain(text)
        ? GhostText.findGhosts(text)
        : const <GhostMatch>[];

    if (text.codeUnitAt(0) == 0x23) {
      final match = _headerRe.firstMatch(text);
      if (match != null) {
        return _buildHeader(
          text: text,
          level: match.group(1)!.length,
          style: style,
          baseColor: baseColor,
          primary: primary,
          reveal: reveal,
          ghosts: ghosts,
        );
      }
    }

    final item = MarkdownListSyntax.parse(text);
    if (item != null) {
      return _buildListItem(
        text: text,
        item: item,
        style: style,
        baseColor: baseColor,
        primary: primary,
        reveal: reveal,
        ghosts: ghosts,
      );
    }

    if (MarkdownCalloutSyntax.isBlockquoteLine(text)) {
      return _buildQuote(
        text: text,
        style: style,
        baseColor: baseColor,
        primary: primary,
        reveal: reveal,
        ghosts: ghosts,
      );
    }

    if (_ruleRe.hasMatch(text)) {
      return _buildRule(
        text: text,
        style: style,
        baseColor: baseColor,
        reveal: reveal,
      );
    }

    final hasCandidates = _hasInlineCandidates(text);
    if (!hasCandidates && ghosts.isEmpty) return null;
    final children = <InlineSpan>[];
    var styled = false;
    if (hasCandidates) {
      styled = _appendInline(
        text: text,
        start: 0,
        end: text.length,
        contextStyle: style,
        baseColor: baseColor,
        primary: primary,
        reveal: reveal,
        ghosts: ghosts,
        out: children,
        depth: 0,
      );
    } else {
      _emit(
        text: text,
        start: 0,
        end: text.length,
        style: style,
        baseColor: baseColor,
        ghosts: ghosts,
        out: children,
      );
    }
    if (!styled && ghosts.isEmpty) return null;
    return TextSpan(style: style, children: children);
  }

  TextSpan _buildHeader({
    required String text,
    required int level,
    required TextStyle style,
    required Color baseColor,
    required Color primary,
    required bool reveal,
    required List<GhostMatch> ghosts,
  }) {
    final baseSize = style.fontSize ?? 16.0;
    final headerStyle = style.copyWith(
      fontSize: baseSize * _headerScale(level),
      fontWeight: FontWeight.bold,
    );
    final markerEnd = level + 1;
    final children = <InlineSpan>[
      TextSpan(
        text: text.substring(0, markerEnd),
        style: reveal
            ? _dimStyle(headerStyle, baseColor)
            : _concealStyle(headerStyle),
      ),
    ];
    _appendInline(
      text: text,
      start: markerEnd,
      end: text.length,
      contextStyle: headerStyle,
      baseColor: baseColor,
      primary: primary,
      reveal: reveal,
      ghosts: ghosts,
      out: children,
      depth: 0,
    );
    return TextSpan(style: headerStyle, children: children);
  }

  /// Blockquote line: the `>` is substituted 1:1 with a `┃` bar (both a
  /// single code unit) tinted like the preview's quote bar, and the
  /// content renders italic and dimmed with inline styling intact.
  /// Callout lines (`> [!TIP]`) get the same plain-quote treatment for
  /// now. On reveal the raw `>` shows dimmed; line height never changes.
  TextSpan _buildQuote({
    required String text,
    required TextStyle style,
    required Color baseColor,
    required Color primary,
    required bool reveal,
    required List<GhostMatch> ghosts,
  }) {
    var gt = 0;
    while (text.codeUnitAt(gt) != 0x3E) {
      gt++;
    }
    final children = <InlineSpan>[];
    if (gt > 0) {
      children.add(TextSpan(text: text.substring(0, gt), style: style));
    }
    children.add(
      TextSpan(
        text: reveal ? '>' : '┃',
        style: reveal
            ? _dimStyle(style, baseColor)
            : style.copyWith(
                color: _isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
      ),
    );
    if (gt + 1 < text.length) {
      final quoteColor = baseColor.withValues(alpha: _quoteContentAlpha);
      _appendInline(
        text: text,
        start: gt + 1,
        end: text.length,
        contextStyle: style.copyWith(
          fontStyle: FontStyle.italic,
          color: quoteColor,
        ),
        baseColor: baseColor,
        primary: primary,
        reveal: reveal,
        ghosts: ghosts,
        out: children,
        depth: 0,
      );
    }
    return TextSpan(style: style, children: children);
  }

  /// Horizontal rule: every `-` / `*` / `_` is substituted 1:1 with `─`
  /// (one code unit each) and dimmed, so contiguous glyphs read as a
  /// line. Base font size is kept — like H5/H6, a sub-base line height
  /// buys nothing in the editor. On reveal the raw markers show dimmed.
  TextSpan _buildRule({
    required String text,
    required TextStyle style,
    required Color baseColor,
    required bool reveal,
  }) {
    if (reveal) {
      return TextSpan(
        style: style,
        children: [TextSpan(text: text, style: _dimStyle(style, baseColor))],
      );
    }
    final units = List<int>.generate(text.length, (i) {
      final c = text.codeUnitAt(i);
      return _isSpace(c) ? c : 0x2500;
    });
    return TextSpan(
      style: style,
      children: [
        TextSpan(
          text: String.fromCharCodes(units),
          style: style.copyWith(color: baseColor.withValues(alpha: _ruleAlpha)),
        ),
      ],
    );
  }

  TextSpan _buildListItem({
    required String text,
    required MarkdownListItem item,
    required TextStyle style,
    required Color baseColor,
    required Color primary,
    required bool reveal,
    required List<GhostMatch> ghosts,
  }) {
    final children = <InlineSpan>[];
    if (item.indent.isNotEmpty) {
      children.add(TextSpan(text: item.indent, style: style));
    }
    var contentStyle = style;

    switch (item.kind) {
      case MarkdownListKind.bullet:
        final markerEnd = item.indent.length + item.marker.length;
        children.add(
          TextSpan(
            text: reveal ? item.marker : '•',
            style: reveal
                ? _dimStyle(style, baseColor)
                : style.copyWith(color: primary, fontWeight: FontWeight.bold),
          ),
        );
        if (markerEnd < item.contentStart) {
          children.add(
            TextSpan(
              text: text.substring(markerEnd, item.contentStart),
              style: style,
            ),
          );
        }
      case MarkdownListKind.ordered:
        final markerEnd =
            item.indent.length + item.marker.length + item.delimiter.length;
        children.add(
          TextSpan(
            text: '${item.marker}${item.delimiter}',
            style: style.copyWith(color: primary, fontWeight: FontWeight.w600),
          ),
        );
        if (markerEnd < item.contentStart) {
          children.add(
            TextSpan(
              text: text.substring(markerEnd, item.contentStart),
              style: style,
            ),
          );
        }
      case MarkdownListKind.task:
        final boxEnd = item.bracketStart + 3;
        if (reveal) {
          children.add(
            TextSpan(
              text: text.substring(item.indent.length, boxEnd),
              style: _dimStyle(style, baseColor),
            ),
          );
        } else {
          children.add(
            TextSpan(
              text: text.substring(item.indent.length, item.bracketStart),
              style: _concealStyle(style),
            ),
          );
          children.add(
            TextSpan(
              text: item.checked ? _checkedGlyph : _uncheckedGlyph,
              style: style.copyWith(
                fontFamily: _glyphFontFamily,
                fontSize: (style.fontSize ?? 16.0) * _checkboxGlyphScale,
                color: item.checked
                    ? primary
                    : baseColor.withValues(
                        alpha: MarkdownConstants.uncheckedCheckboxOpacity,
                      ),
              ),
            ),
          );
          children.add(
            TextSpan(
              text: text.substring(item.bracketStart + 1, boxEnd),
              style: _concealStyle(style),
            ),
          );
        }
        if (boxEnd < item.contentStart) {
          children.add(
            TextSpan(
              text: text.substring(boxEnd, item.contentStart),
              style: style,
            ),
          );
        }
        if (item.checked) {
          final checkedColor = baseColor.withValues(
            alpha: MarkdownConstants.checkedTextOpacity,
          );
          contentStyle = style.copyWith(
            color: checkedColor,
            decoration: TextDecoration.lineThrough,
            decorationColor: checkedColor,
          );
        }
    }

    if (item.contentStart < text.length) {
      _appendInline(
        text: text,
        start: item.contentStart,
        end: text.length,
        contextStyle: contentStyle,
        baseColor: baseColor,
        primary: primary,
        reveal: reveal,
        ghosts: ghosts,
        out: children,
        depth: 0,
      );
    }
    return TextSpan(style: style, children: children);
  }

  /// Appends spans covering [start]..[end], styling emphasis / strike /
  /// highlight / code runs and `#tag` tokens against [contextStyle].
  /// Ghost regions are opaque to the scanner (their characters never
  /// open or close a run) and all content is emitted through the
  /// ghost-aware [_emit]. Returns whether any run was styled.
  bool _appendInline({
    required String text,
    required int start,
    required int end,
    required TextStyle contextStyle,
    required Color baseColor,
    required Color primary,
    required bool reveal,
    required List<GhostMatch> ghosts,
    required List<InlineSpan> out,
    required int depth,
  }) {
    var styled = false;
    var plainFrom = start;
    var pos = start;
    while (pos < end) {
      final c = text.codeUnitAt(pos);
      if (c == 0x7B && ghosts.isNotEmpty) {
        final g = _ghostAt(ghosts, pos);
        if (g != null) {
          pos = g.end;
          continue;
        }
        pos++;
        continue;
      }
      if (c == 0x23) {
        final tagEnd = _matchTag(text, pos, end);
        if (tagEnd > 0) {
          if (plainFrom < pos) {
            _emit(
              text: text,
              start: plainFrom,
              end: pos,
              style: contextStyle,
              baseColor: baseColor,
              ghosts: ghosts,
              out: out,
            );
          }
          _emit(
            text: text,
            start: pos,
            end: tagEnd,
            style: contextStyle.copyWith(
              color: primary,
              fontWeight: FontWeight.w600,
              backgroundColor: primary.withValues(alpha: _tagBackgroundAlpha),
            ),
            baseColor: baseColor,
            ghosts: ghosts,
            out: out,
          );
          styled = true;
          pos = tagEnd;
          plainFrom = pos;
        } else {
          pos++;
        }
        continue;
      }
      final _InlineRun? run;
      if (c == 0x2A) {
        run =
            _matchRun(text, pos, end, '***', ghosts: ghosts) ??
            _matchRun(text, pos, end, '**', ghosts: ghosts) ??
            _matchRun(text, pos, end, '*', ghosts: ghosts);
      } else if (c == 0x7E) {
        run = _matchRun(text, pos, end, '~~', ghosts: ghosts);
      } else if (c == 0x3D) {
        run = _matchRun(text, pos, end, '==', ghosts: ghosts);
      } else if (c == 0x60) {
        run = _matchRun(text, pos, end, '`', ghosts: ghosts);
      } else if (c == 0x5F) {
        run =
            _matchRun(text, pos, end, '__', ghosts: ghosts, wordBound: true) ??
            _matchRun(text, pos, end, '_', ghosts: ghosts, wordBound: true);
      } else {
        pos++;
        continue;
      }
      if (run == null) {
        pos++;
        continue;
      }
      if (plainFrom < pos) {
        _emit(
          text: text,
          start: plainFrom,
          end: pos,
          style: contextStyle,
          baseColor: baseColor,
          ghosts: ghosts,
          out: out,
        );
      }
      final markerStyle = reveal
          ? _dimStyle(contextStyle, baseColor)
          : _concealStyle(contextStyle);
      final runStyle = _runStyle(contextStyle, baseColor, run.marker);
      out.add(TextSpan(text: run.marker, style: markerStyle));
      // Code runs are literal: no nested emphasis inside backticks.
      if (run.marker != '`' && depth < _maxInlineDepth) {
        _appendInline(
          text: text,
          start: run.innerStart,
          end: run.innerEnd,
          contextStyle: runStyle,
          baseColor: baseColor,
          primary: primary,
          reveal: reveal,
          ghosts: ghosts,
          out: out,
          depth: depth + 1,
        );
      } else {
        _emit(
          text: text,
          start: run.innerStart,
          end: run.innerEnd,
          style: runStyle,
          baseColor: baseColor,
          ghosts: ghosts,
          out: out,
        );
      }
      out.add(TextSpan(text: run.marker, style: markerStyle));
      styled = true;
      pos = run.innerEnd + run.marker.length;
      plainFrom = pos;
    }
    if (plainFrom < end) {
      _emit(
        text: text,
        start: plainFrom,
        end: end,
        style: contextStyle,
        baseColor: baseColor,
        ghosts: ghosts,
        out: out,
      );
    }
    return styled;
  }

  /// Emits [start]..[end] in [style], splitting around ghost runs so
  /// their markers render concealed and their inner text dimmed (with an
  /// underline when blank, so the empty slot stays findable) — the same
  /// treatment as the standalone ghost builder, but inheriting the
  /// surrounding markdown style.
  void _emit({
    required String text,
    required int start,
    required int end,
    required TextStyle style,
    required Color baseColor,
    required List<GhostMatch> ghosts,
    required List<InlineSpan> out,
  }) {
    if (start >= end) return;
    if (ghosts.isEmpty) {
      out.add(TextSpan(text: text.substring(start, end), style: style));
      return;
    }
    var pos = start;
    for (final g in ghosts) {
      if (g.end <= pos) continue;
      if (g.start >= end) break;
      if (g.start > pos) {
        out.add(TextSpan(text: text.substring(pos, g.start), style: style));
      }
      final ghostColor = baseColor.withValues(alpha: _dimAlpha);
      var innerStyle = style.copyWith(color: ghostColor);
      if (_ghostBlank(text, g)) {
        innerStyle = innerStyle.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: ghostColor,
        );
      }
      final concealStyle = _concealStyle(style);
      _emitClamped(text, g.start, g.innerStart, pos, end, concealStyle, out);
      _emitClamped(text, g.innerStart, g.innerEnd, pos, end, innerStyle, out);
      _emitClamped(text, g.innerEnd, g.end, pos, end, concealStyle, out);
      pos = g.end < end ? g.end : end;
      if (pos >= end) return;
    }
    if (pos < end) {
      out.add(TextSpan(text: text.substring(pos, end), style: style));
    }
  }

  void _emitClamped(
    String text,
    int from,
    int to,
    int lo,
    int hi,
    TextStyle style,
    List<InlineSpan> out,
  ) {
    final a = from > lo ? from : lo;
    final b = to < hi ? to : hi;
    if (a < b) {
      out.add(TextSpan(text: text.substring(a, b), style: style));
    }
  }

  /// Matches `marker…marker` opening at [pos]: the run must be non-empty,
  /// must not start or end with whitespace (so `2 * 3 * 4` stays plain),
  /// and must not close inside a ghost. [wordBound] additionally requires
  /// non-word characters around the run, so snake_case tokens are never
  /// emphasized.
  _InlineRun? _matchRun(
    String text,
    int pos,
    int end,
    String marker, {
    required List<GhostMatch> ghosts,
    bool wordBound = false,
  }) {
    final len = marker.length;
    if (!text.startsWith(marker, pos)) return null;
    if (wordBound && pos > 0 && _isWordChar(text.codeUnitAt(pos - 1))) {
      return null;
    }
    final innerStart = pos + len;
    if (innerStart >= end || _isSpace(text.codeUnitAt(innerStart))) {
      return null;
    }
    var close = text.indexOf(marker, innerStart);
    while (close != -1 && close + len <= end) {
      if (close > innerStart &&
          !_isSpace(text.codeUnitAt(close - 1)) &&
          !_inGhost(ghosts, close) &&
          (!wordBound ||
              close + len == text.length ||
              !_isWordChar(text.codeUnitAt(close + len)))) {
        return _InlineRun(marker, innerStart, close);
      }
      close = text.indexOf(marker, close + 1);
    }
    return null;
  }

  TextStyle _runStyle(TextStyle context, Color baseColor, String marker) {
    switch (marker) {
      case '***':
        return context.copyWith(
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        );
      case '**':
      case '__':
        return context.copyWith(fontWeight: FontWeight.bold);
      case '*':
      case '_':
        return context.copyWith(fontStyle: FontStyle.italic);
      case '~~':
        return context.copyWith(
          decoration: TextDecoration.lineThrough,
          decorationColor: context.color,
        );
      case '==':
        return context.copyWith(
          backgroundColor: _isDark
              ? MarkdownConstants.markBackgroundDark
              : MarkdownConstants.markBackgroundLight,
        );
      case '`':
        return context.copyWith(
          backgroundColor: baseColor.withValues(alpha: _codeBackgroundAlpha),
        );
    }
    return context;
  }

  double _headerScale(int level) {
    switch (level) {
      case 1:
        return MarkdownConstants.h1Scale;
      case 2:
        return MarkdownConstants.h2Scale;
      case 3:
        return MarkdownConstants.h3Scale;
      case 4:
        return MarkdownConstants.h4Scale;
      default:
        // H5/H6 never drop below the base size — a line shorter than the
        // editor's base line height has no upside in the editor.
        return 1.0;
    }
  }

  TextStyle _dimStyle(TextStyle context, Color baseColor) => context.copyWith(
    color: baseColor.withValues(alpha: _dimAlpha),
    fontWeight: FontWeight.normal,
  );

  TextStyle _concealStyle(TextStyle context) =>
      context.copyWith(color: _transparent, fontSize: _concealedFontSize);

  bool _hasInlineCandidates(String text) {
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c == 0x2A ||
          c == 0x7E ||
          c == 0x60 ||
          c == 0x5F ||
          c == 0x3D ||
          c == 0x23) {
        return true;
      }
    }
    return false;
  }

  /// Returns the end (exclusive) of a `#tag` opening at [pos], or `-1`.
  /// Grammar comes from [MarkdownTagSyntax] (shared with the preview);
  /// the end is clamped into the current segment so a tag inside an
  /// emphasis run never styles past the run's closing marker, and the
  /// clamped tag must keep at least one body character.
  int _matchTag(String text, int pos, int end) {
    if (!MarkdownTagSyntax.isWordBoundaryBefore(text, pos)) return -1;
    var tagEnd = MarkdownTagSyntax.tryParseTagAt(text, pos);
    if (tagEnd == null) return -1;
    if (tagEnd > end) tagEnd = end;
    return tagEnd > pos + 1 ? tagEnd : -1;
  }

  bool _isSpace(int codeUnit) => codeUnit == 0x20 || codeUnit == 0x09;

  bool _isWordChar(int c) =>
      (c >= 0x61 && c <= 0x7A) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x30 && c <= 0x39) ||
      c == 0x5F ||
      c > 0x7F;

  GhostMatch? _ghostAt(List<GhostMatch> ghosts, int pos) {
    for (final g in ghosts) {
      if (pos >= g.start && pos < g.end) return g;
      if (g.start > pos) break;
    }
    return null;
  }

  bool _inGhost(List<GhostMatch> ghosts, int pos) =>
      _ghostAt(ghosts, pos) != null;

  bool _ghostBlank(String text, GhostMatch g) {
    for (var i = g.innerStart; i < g.innerEnd; i++) {
      if (!_isSpace(text.codeUnitAt(i))) return false;
    }
    return true;
  }

  bool _selectionCoversLine(CodeLineSelection selection, int index) {
    final a = selection.baseIndex;
    final b = selection.extentIndex;
    return a < b ? (index >= a && index <= b) : (index >= b && index <= a);
  }

  /// Fence-awareness: lines inside (or delimiting) a ``` code fence are
  /// left raw, mirroring MarkdownChunker's fence rule.
  bool _lineInFence(CodeLineEditingController controller, int index) {
    final lines = controller.codeLines;
    if (!identical(lines, _fenceLines)) {
      _rebuildFence(lines);
      _fenceLines = lines;
    }
    final fence = _fence;
    return fence != null && index >= 0 && index < fence.length && fence[index];
  }

  void _rebuildFence(CodeLines lines) {
    final n = lines.length;
    List<bool>? flags;
    var inFence = false;
    for (var i = 0; i < n; i++) {
      if (_isFenceDelimiter(lines[i].text)) {
        flags ??= List<bool>.filled(n, false);
        flags[i] = true;
        inFence = !inFence;
      } else if (inFence) {
        flags![i] = true;
      }
    }
    _fence = flags;
  }

  bool _isFenceDelimiter(String text) {
    var i = 0;
    while (i < text.length && _isSpace(text.codeUnitAt(i))) {
      i++;
    }
    return text.startsWith('```', i);
  }
}

class _InlineRun {
  final String marker;
  final int innerStart;
  final int innerEnd;

  const _InlineRun(this.marker, this.innerStart, this.innerEnd);
}
