import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import '../constants/markdown_constants.dart';
import 'ghost_text.dart';
import 'lru_cache.dart';
import 'markdown_callout_syntax.dart';
import 'markdown_link_patterns.dart';
import 'markdown_list_syntax.dart';
import 'markdown_tag_syntax.dart';

/// Live markdown rendering for the re_editor text mode (the "live
/// markdown rendering" editor setting, on by default).
///
/// Restyles one line at a time: headers at the preview's scale factors
/// (the re_editor fork gives a line whose root span sets a non-base
/// fontSize its own line height), bullets as `•`, task boxes as
/// custom-painted placeholder marks (checked / unchecked / indeterminate
/// when a parent's subtree is partially complete),
/// blockquote `>` as a `┃` bar with italic dimmed content,
/// `---` rules as dimmed `─` runs, `#tag` tokens tinted (render-only),
/// and `**bold**` / `*italic*` / `__bold__` / `_italic_` / `~~strike~~` /
/// `==highlight==` / `` `code` `` runs styled inline. `[text](url)`
/// links show their text tinted and underlined with the brackets + URL
/// concealed (render-only — tapping places the caret and the line
/// reveals raw for editing); bare `http(s)://` / `www.` URLs tint in
/// place with nothing concealed. Backslash escapes render the escaped
/// punctuation literally with the `\` concealed. Callout lead lines
/// (`> [!TIP] title`) tint the quote bar and the `[!TYPE]` token with
/// the type's accent. Code-fence delimiter lines render monospace and
/// dimmed, fence interiors monospace over the inline-code background.
/// H5/H6 stay at base size but blend toward the primary colour (H6
/// additionally muted) so they read as headings. Ghost `{{ … }}`
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

  static const Color _transparent = Color(0x00000000);
  static const double _concealedFontSize = 0.01;
  static const double _dimAlpha = 0.45;
  static const double _codeBackgroundAlpha = 0.08;
  static const double _quoteContentAlpha = 0.8;
  static const double _ruleAlpha = 0.3;
  static const double _tagBackgroundAlpha = 0.12;
  static const double _fenceDelimiterAlpha = 0.6;
  static const double _h56PrimaryBlend = 0.35;
  static const double _h6Alpha = 0.7;
  static const int _maxInlineDepth = 3;

  /// Lines longer than this render raw — matches the spirit of
  /// re_editor's maxLengthSingleLineRendering guard. Public so the
  /// wrapper's tap interception can refuse zones on lines that render
  /// raw for length.
  static const int maxStyledLineLength = 4096;

  static const int _spanCacheSize = 1024;

  /// Sentinel cached for lines this builder leaves unhandled, so misses
  /// and "raw" lines are distinguishable with a single lookup.
  static const TextSpan _unhandled = TextSpan();

  CodeLineEditingController? _controller;
  CodeLines? _fenceLines;
  List<_FenceRole>? _fence;

  /// Positional task-parent aggregation: line indices whose unchecked
  /// box renders indeterminate because their subtree of task lines is
  /// partially complete. Recomputed lazily per [CodeLines] instance,
  /// same contract as the fence index.
  CodeLines? _taskLines;
  Set<int>? _taskIndeterminate;

  final LruCache<String, TextSpan> _spanCache = LruCache(
    maxSize: _spanCacheSize,
  );

  /// Positionally-styled lines (fence delimiter/interior, indeterminate
  /// task parents) can't share [_spanCache] — the same text renders
  /// differently depending on surrounding lines — but they still must
  /// return identical span instances so re_editor's paragraph cache
  /// stays on its fast path. Hence a small memo keyed by role + text
  /// ('d:'/'i:' fence roles, 't:' indeterminate task).
  static const int _positionalSpanCacheSize = 128;
  final LruCache<String, TextSpan> _positionalSpanCache = LruCache(
    maxSize: _positionalSpanCacheSize,
  );
  TextStyle? _cacheStyle;
  Color? _cacheBaseColor;
  Color? _cachePrimary;
  bool _isDark = false;

  /// Contrast colour for the check mark on a [_cachePrimary]-filled
  /// box; refreshed with the other theme-generation fields.
  Color _cacheOnAccent = Colors.white;

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
    if (text.isEmpty || text.length > maxStyledLineLength) return null;

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
      _positionalSpanCache.clear();
      _cacheStyle = style;
      _cacheBaseColor = baseColor;
      _cachePrimary = primary;
      _isDark = isDark;
      _cacheOnAccent =
          ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
          ? Colors.white
          : Colors.black87;
    }

    // Fence status is positional, not textual — fence lines are styled
    // straight from their role and never touch the text-keyed cache.
    final fenceRole = _fenceRoleAt(controller, index);
    if (fenceRole != _FenceRole.none) {
      final fenceKey = fenceRole == _FenceRole.delimiter
          ? 'd:$text'
          : 'i:$text';
      final cached = _positionalSpanCache.get(fenceKey);
      if (cached != null) return cached;
      final span = _buildFenceLine(
        text: text,
        role: fenceRole,
        style: style,
        baseColor: baseColor,
      );
      _positionalSpanCache.put(fenceKey, span);
      return span;
    }

    final reveal = selectionCoversLine(controller.selection, index);

    // Task-parent aggregate state is positional too (it depends on the
    // child lines), so indeterminate parents style through the
    // positional memo, mirroring fences. Reveal lines show raw markers
    // and skip the facet entirely.
    if (!reveal && _isTaskIndeterminate(controller, index)) {
      final taskKey = 't:$text';
      final cached = _positionalSpanCache.get(taskKey);
      if (cached != null) return cached;
      final span = _buildLine(
        text: text,
        style: style,
        baseColor: baseColor,
        primary: primary,
        reveal: false,
        taskIndeterminate: true,
      );
      if (span != null) {
        _positionalSpanCache.put(taskKey, span);
      }
      return span;
    }

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
    bool taskIndeterminate = false,
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
        indeterminate: taskIndeterminate,
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
    var headerStyle = style.copyWith(
      fontSize: baseSize * _headerScale(level),
      fontWeight: FontWeight.bold,
    );
    // H5/H6 keep the base size (sub-base line heights buy nothing in the
    // editor), so they distinguish themselves by colour instead: blended
    // toward primary, H6 additionally muted below H5.
    if (level >= 5) {
      final blended = Color.lerp(baseColor, primary, _h56PrimaryBlend)!;
      headerStyle = headerStyle.copyWith(
        color: level == 5 ? blended : blended.withValues(alpha: _h6Alpha),
      );
    }
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
  /// Callout lead lines (`> [!TIP] title`) tint the bar and the
  /// `[!TYPE]` token with the type's accent (palette shared with the
  /// preview via [MarkdownConstants.calloutAccent]); the token stays
  /// tinted on reveal since nothing in it is concealed. Continuation
  /// lines keep the plain-quote treatment — the styling stays purely
  /// textual so the span memo stays valid. On reveal the raw `>` shows
  /// dimmed; line height never changes.
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
    final lead = MarkdownCalloutSyntax.parseLead(text);
    final accent = lead != null
        ? MarkdownConstants.calloutAccent(lead.type, dark: _isDark)
        : null;
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
                color:
                    accent ??
                    (_isDark ? Colors.grey.shade700 : Colors.grey.shade300),
              ),
      ),
    );
    var contentStart = gt + 1;
    if (lead != null && accent != null) {
      if (lead.tokenStart > contentStart) {
        children.add(
          TextSpan(
            text: text.substring(contentStart, lead.tokenStart),
            style: style,
          ),
        );
      }
      children.add(
        TextSpan(
          text: text.substring(lead.tokenStart, lead.tokenEnd),
          style: style.copyWith(color: accent, fontWeight: FontWeight.w600),
        ),
      );
      contentStart = lead.tokenEnd;
    }
    if (contentStart < text.length) {
      _appendInline(
        text: text,
        start: contentStart,
        end: text.length,
        contextStyle: style.copyWith(
          fontStyle: FontStyle.italic,
          color: baseColor.withValues(alpha: _quoteContentAlpha),
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
    bool indeterminate = false,
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
          // The box substitutes 1:1 for the `[` code unit as a
          // placeholder run (fork's CodeInlinePaintSpan): custom-painted,
          // sized off the line's own font size, and centered on the line
          // box by the paragraph layout itself — no font-metric fudging.
          // Clamped under the strut height so the line never grows.
          final baseSize = style.fontSize ?? 16.0;
          final lineBox =
              baseSize * (style.height ?? MarkdownConstants.lineHeight);
          var side = baseSize * MarkdownConstants.editorCheckboxScale;
          if (side > lineBox * 0.85) side = lineBox * 0.85;
          children.add(
            _EditorCheckboxSpan(
              side: side,
              visual: item.checked
                  ? _CheckboxVisual.checked
                  : indeterminate
                  ? _CheckboxVisual.indeterminate
                  : _CheckboxVisual.unchecked,
              accent: primary,
              border: baseColor.withValues(
                alpha: MarkdownConstants.uncheckedCheckboxOpacity,
              ),
              mark: _cacheOnAccent,
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
      // Hanging indent: the fork lays out the marker prefix and the
      // content as two paragraphs, so soft-wrapped continuation lines
      // align under the content (Obsidian-style). Code units and span
      // order are untouched — this only tags the root span.
      return CodeHangingTextSpan(
        hangingChars: item.contentStart,
        style: style,
        children: children,
      );
    }
    return TextSpan(style: style, children: children);
  }

  /// Appends spans covering [start]..[end], styling emphasis / strike /
  /// highlight / code runs, `[text](url)` links, bare URLs, `#tag`
  /// tokens, and backslash escapes against [contextStyle].
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
      // Backslash escape: the escaped punctuation renders literally and
      // never opens a run/tag/link (mirrors the preview's scan). The `\`
      // is concealed off-caret, dimmed on reveal. A `\` in front of a
      // ghost's `{{` is left alone — ghosts win, GhostText owns that
      // grammar.
      if (c == 0x5C && pos + 1 < end) {
        final next = text.codeUnitAt(pos + 1);
        if (_isEscapablePunctuation(next) && !_inGhost(ghosts, pos + 1)) {
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
          out.add(
            TextSpan(
              text: r'\',
              style: reveal
                  ? _dimStyle(contextStyle, baseColor)
                  : _concealStyle(contextStyle),
            ),
          );
          out.add(
            TextSpan(text: text.substring(pos + 1, pos + 2), style: contextStyle),
          );
          styled = true;
          pos += 2;
          plainFrom = pos;
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
            ),
            baseColor: baseColor,
            ghosts: ghosts,
            out: out,
            decoration: _tagDecoration(contextStyle, primary),
          );
          styled = true;
          pos = tagEnd;
          plainFrom = pos;
        } else {
          pos++;
        }
        continue;
      }
      if (c == 0x5B) {
        final link = _matchLink(text, pos, end, ghosts);
        if (link == null) {
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
        final linkStyle = _linkStyle(contextStyle, primary);
        out.add(TextSpan(text: '[', style: markerStyle));
        if (depth < _maxInlineDepth) {
          _appendInline(
            text: text,
            start: pos + 1,
            end: link.textEnd,
            contextStyle: linkStyle,
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
            start: pos + 1,
            end: link.textEnd,
            style: linkStyle,
            baseColor: baseColor,
            ghosts: ghosts,
            out: out,
          );
        }
        _emit(
          text: text,
          start: link.textEnd,
          end: link.end,
          style: markerStyle,
          baseColor: baseColor,
          ghosts: ghosts,
          out: out,
        );
        styled = true;
        pos = link.end;
        plainFrom = pos;
        continue;
      }
      if (c == 0x68 || c == 0x77) {
        final urlEnd = _matchBareUrl(text, pos, end, ghosts);
        if (urlEnd < 0) {
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
        _emit(
          text: text,
          start: pos,
          end: urlEnd,
          style: _linkStyle(contextStyle, primary),
          baseColor: baseColor,
          ghosts: ghosts,
          out: out,
        );
        styled = true;
        pos = urlEnd;
        plainFrom = pos;
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
          decoration: run.marker == '`'
              ? _codeDecoration(contextStyle, baseColor)
              : null,
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
    CodeTextDecoration? decoration,
  }) {
    if (start >= end) return;
    if (ghosts.isEmpty) {
      out.add(_plainSpan(text.substring(start, end), style, decoration));
      return;
    }
    var pos = start;
    for (final g in ghosts) {
      if (g.end <= pos) continue;
      if (g.start >= end) break;
      if (g.start > pos) {
        out.add(_plainSpan(text.substring(pos, g.start), style, decoration));
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
      out.add(_plainSpan(text.substring(pos, end), style, decoration));
    }
  }

  /// A plain emitted segment: an ordinary [TextSpan], or a
  /// [CodeDecoratedTextSpan] when the run paints a chip behind itself
  /// (tags, inline code). Ghost segments inside a decorated run keep
  /// plain spans — the ghost treatment wins there.
  static InlineSpan _plainSpan(
    String text,
    TextStyle style,
    CodeTextDecoration? decoration,
  ) => decoration == null
      ? TextSpan(text: text, style: style)
      : CodeDecoratedTextSpan(decoration: decoration, text: text, style: style);

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

  /// Matches a `[text](url)` link opening at [pos]. Grammar comes from
  /// [MarkdownLinkPatterns.matchInlineLinkAt] (shared with the preview
  /// and the wrapper's tap interception), clamped to [end] so a link
  /// inside an emphasis run never styles past the run's closing marker.
  /// Rejected when the `[` is preceded by `!` (image syntax stays raw in
  /// the editor — preview owns image rendering) or when a structural
  /// character falls inside a ghost run.
  MarkdownInlineLink? _matchLink(
    String text,
    int pos,
    int end,
    List<GhostMatch> ghosts,
  ) {
    if (pos > 0 && text.codeUnitAt(pos - 1) == 0x21) return null;
    final link = MarkdownLinkPatterns.matchInlineLinkAt(text, pos, end);
    if (link == null) return null;
    if (_inGhost(ghosts, link.textEnd) || _inGhost(ghosts, link.urlEnd)) {
      return null;
    }
    return link;
  }

  /// Returns the end (exclusive) of a bare `http(s)://` / `www.` URL
  /// opening at [pos], or `-1`. Grammar comes from [MarkdownLinkPatterns]
  /// (shared with the preview and the paste line-breaker); the match is
  /// clamped to the current segment and to the first ghost run, so a URL
  /// never styles past either.
  int _matchBareUrl(String text, int pos, int end, List<GhostMatch> ghosts) {
    if (!MarkdownTagSyntax.isWordBoundaryBefore(text, pos)) return -1;
    var limit = end;
    for (final g in ghosts) {
      if (g.end <= pos) continue;
      if (g.start <= pos) return -1;
      if (g.start < limit) limit = g.start;
      break;
    }
    return MarkdownLinkPatterns.matchBareUrlEnd(text, pos, limit);
  }

  TextStyle _linkStyle(TextStyle context, Color primary) => context.copyWith(
    color: primary,
    decoration: TextDecoration.underline,
    decorationColor: primary,
  );

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
        // The background is a painted chip (CodeDecoratedTextSpan) at
        // the emit site, not a style backgroundColor — rounded corners
        // and uniform height need real paint, not per-glyph rects.
        return context;
    }
    return context;
  }

  /// Stadium pill behind a `#tag` run. Radius past half the chip height
  /// clamps to a stadium; the vertical inset trims the strut-height box
  /// to ~1.06em so pills read uniform at every editor font size.
  CodeTextDecoration _tagDecoration(TextStyle context, Color primary) {
    final size = context.fontSize ?? 16.0;
    return CodeTextDecoration(
      color: primary.withValues(alpha: _tagBackgroundAlpha),
      radius: size,
      horizontalPadding: size * 0.15,
      verticalInset: size * 0.22,
    );
  }

  /// Rounded chip behind inline `` `code` `` content (markers stay
  /// outside the chip).
  CodeTextDecoration _codeDecoration(TextStyle context, Color baseColor) {
    final size = context.fontSize ?? 16.0;
    return CodeTextDecoration(
      color: baseColor.withValues(alpha: _codeBackgroundAlpha),
      radius: size * 0.25,
      horizontalPadding: size * 0.1,
      verticalInset: size * 0.16,
    );
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
          c == 0x23 ||
          c == 0x5B ||
          c == 0x5C) {
        return true;
      }
      // Bare-URL candidates need the second scheme char too ("ht", "ww"),
      // or every prose line containing an h/w would defeat this
      // quick-reject and run the full inline scanner for nothing.
      if ((c == 0x68 || c == 0x77) && i + 1 < text.length) {
        final n = text.codeUnitAt(i + 1);
        if ((c == 0x68 && n == 0x74) || (c == 0x77 && n == 0x77)) {
          return true;
        }
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

  bool _isEscapablePunctuation(int c) =>
      MarkdownConstants.isEscapablePunctuation(c);

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

  /// Whether the selection covers (reveals) [index]. Public and static
  /// so the wrapper's tap interception uses the exact same reveal
  /// predicate as the rendering — the two must never disagree.
  static bool selectionCoversLine(CodeLineSelection selection, int index) {
    final a = selection.baseIndex;
    final b = selection.extentIndex;
    return a < b ? (index >= a && index <= b) : (index >= b && index <= a);
  }

  /// Whether [index] is inside (or delimiting) a ``` code fence. Public
  /// so the wrapper's tap interception can refuse to treat fence text as
  /// a link or checkbox; rendering resolves roles via [_fenceRoleAt].
  bool lineInFence(int index) {
    final controller = _controller;
    if (controller == null) return false;
    return _fenceRoleAt(controller, index) != _FenceRole.none;
  }

  /// Fence-awareness: mirrors MarkdownChunker's fence rule. Delimiter
  /// and interior lines carry distinct roles so they can style
  /// differently; both are positional, so neither touches the memo.
  _FenceRole _fenceRoleAt(CodeLineEditingController controller, int index) {
    final lines = controller.codeLines;
    if (!identical(lines, _fenceLines)) {
      _rebuildFence(lines);
      _fenceLines = lines;
    }
    final fence = _fence;
    if (fence == null || index < 0 || index >= fence.length) {
      return _FenceRole.none;
    }
    return fence[index];
  }

  void _rebuildFence(CodeLines lines) {
    final n = lines.length;
    List<_FenceRole>? flags;
    var inFence = false;
    for (var i = 0; i < n; i++) {
      if (_isFenceDelimiter(lines[i].text)) {
        flags ??= List<_FenceRole>.filled(n, _FenceRole.none);
        flags[i] = _FenceRole.delimiter;
        inFence = !inFence;
      } else if (inFence) {
        flags![i] = _FenceRole.interior;
      }
    }
    _fence = flags;
  }

  /// Whether the task line at [index] renders its unchecked box as
  /// indeterminate: its subtree holds at least one checked and at least
  /// one unchecked task. Positional, so it follows the fence index's
  /// lazy-recompute contract.
  bool _isTaskIndeterminate(CodeLineEditingController controller, int index) {
    final lines = controller.codeLines;
    if (!identical(lines, _taskLines)) {
      _rebuildTaskIndex(controller, lines);
      _taskLines = lines;
    }
    return _taskIndeterminate?.contains(index) ?? false;
  }

  /// One pass over the document with a stack of open task items. A task
  /// line's subtree is the run of deeper-indented list lines directly
  /// below it; any blank, non-list, or fence line terminates all open
  /// subtrees (aggregation spans contiguous list lines only — same
  /// "fences win" rule as [build]). Each closed frame folds its counts
  /// into its parent, so parents aggregate descendants at every depth.
  void _rebuildTaskIndex(CodeLineEditingController controller,
      CodeLines lines) {
    Set<int>? result;
    final frames = <_TaskFrame>[];

    void closeFrames(int level) {
      while (frames.isNotEmpty && frames.last.level >= level) {
        final frame = frames.removeLast();
        if (!frame.checked &&
            frame.checkedDescendants > 0 &&
            frame.checkedDescendants < frame.totalDescendants) {
          (result ??= <int>{}).add(frame.line);
        }
        if (frames.isNotEmpty) {
          frames.last.checkedDescendants += frame.checkedDescendants;
          frames.last.totalDescendants += frame.totalDescendants;
        }
      }
    }

    final n = lines.length;
    for (var i = 0; i < n; i++) {
      final text = lines[i].text;
      final candidate = text.isNotEmpty &&
          text.length <= maxStyledLineLength &&
          _isListCandidate(text);
      if (!candidate) {
        if (frames.isNotEmpty) closeFrames(0);
        continue;
      }
      if (_fenceRoleAt(controller, i) != _FenceRole.none) {
        if (frames.isNotEmpty) closeFrames(0);
        continue;
      }
      final item = MarkdownListSyntax.parse(text);
      if (item == null) {
        if (frames.isNotEmpty) closeFrames(0);
        continue;
      }
      final level = item.level;
      closeFrames(level);
      if (item.kind == MarkdownListKind.task) {
        if (frames.isNotEmpty) {
          if (item.checked) frames.last.checkedDescendants++;
          frames.last.totalDescendants++;
        }
        frames.add(_TaskFrame(line: i, level: level, checked: item.checked));
      }
    }
    closeFrames(0);
    _taskIndeterminate = result;
  }

  /// Cheap pre-filter so the regex list parse only runs on lines that
  /// can possibly be list items: first non-indent char is a bullet
  /// marker or a digit.
  static bool _isListCandidate(String text) {
    var i = 0;
    while (i < text.length) {
      final c = text.codeUnitAt(i);
      if (c != 0x20 && c != 0x09) break;
      i++;
    }
    if (i >= text.length) return false;
    final c = text.codeUnitAt(i);
    return c == 0x2D ||
        c == 0x2A ||
        c == 0x2B ||
        c == 0x2022 ||
        (c >= 0x30 && c <= 0x39);
  }

  /// Code-fence lines mirror the preview's treatment at base size: ```
  /// delimiter lines render monospace and dimmed, interior lines plain
  /// monospace. No per-line background: an empty interior line can't
  /// paint one (no glyphs, and inserting characters is forbidden), so a
  /// background would render striped around blank lines. Nothing is
  /// concealed, so the styling holds on reveal lines too (same rule as
  /// tags), and ghosts compose on delimiter and interior lines alike.
  TextSpan _buildFenceLine({
    required String text,
    required _FenceRole role,
    required TextStyle style,
    required Color baseColor,
  }) {
    final ghosts = GhostText.mightContain(text)
        ? GhostText.findGhosts(text)
        : const <GhostMatch>[];
    final lineStyle = role == _FenceRole.delimiter
        ? style.copyWith(
            fontFamily: 'monospace',
            color: baseColor.withValues(alpha: _fenceDelimiterAlpha),
          )
        : style.copyWith(fontFamily: 'monospace');
    final children = <InlineSpan>[];
    _emit(
      text: text,
      start: 0,
      end: text.length,
      style: lineStyle,
      baseColor: baseColor,
      ghosts: ghosts,
      out: children,
    );
    return TextSpan(style: style, children: children);
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

/// Positional role of a line relative to ``` code fences. Delimiter and
/// interior lines style differently, and both bypass the text-keyed
/// span memo because the role depends on position, not content.
enum _FenceRole { none, delimiter, interior }

/// Mutable accumulator for one open task item during the task-index
/// pass: how many task descendants its subtree holds and how many of
/// them are checked.
class _TaskFrame {
  final int line;
  final int level;
  final bool checked;
  int checkedDescendants = 0;
  int totalDescendants = 0;

  _TaskFrame({required this.line, required this.level, required this.checked});
}

/// Which glyph the editor checkbox paints. `indeterminate` is a purely
/// visual facet of an unchecked box whose child tasks are partially
/// complete — the source text stays `[ ]`, and a tap still checks it.
enum _CheckboxVisual { unchecked, checked, indeterminate }

/// The live editor's task checkbox: a rounded box custom-painted into a
/// placeholder run (fork's [CodeInlinePaintSpan]), replacing the old
/// icon-font glyph. The paragraph layout centers the reserved box on
/// the line box (PlaceholderAlignment.middle) and its side scales with
/// the line's own font size, so the mark stays proportional and
/// vertically centered at every editor text-size setting, independent
/// of any font's metrics. Substitutes 1:1 for the `[` code unit; the
/// `x]` stays concealed beside it.
class _EditorCheckboxSpan extends CodeInlinePaintSpan {
  final _CheckboxVisual visual;
  final Color accent;
  final Color border;
  final Color mark;

  const _EditorCheckboxSpan({
    required double side,
    required this.visual,
    required this.accent,
    required this.border,
    required this.mark,
  }) : super(width: side, height: side);

  // Glyph geometry as fractions of the box side.
  static const double _strokeFrac = 0.09;
  static const double _minStroke = 1.4;
  static const double _radiusFrac = 0.21;
  static const double _insetFrac = 0.05;

  // Paint objects are shared across all checkboxes (single-threaded UI
  // painting) so per-frame drawing allocates nothing but the check path.
  static final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  static final Paint _markPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Rect rect) {
    final side = rect.height;
    var stroke = side * _strokeFrac;
    if (stroke < _minStroke) stroke = _minStroke;
    final box = rect.deflate(side * _insetFrac + stroke / 2);
    final rrect = RRect.fromRectAndRadius(
      box,
      Radius.circular(side * _radiusFrac),
    );
    switch (visual) {
      case _CheckboxVisual.unchecked:
        _strokePaint
          ..color = border
          ..strokeWidth = stroke;
        canvas.drawRRect(rrect, _strokePaint);
      case _CheckboxVisual.checked:
        _fillPaint.color = accent;
        canvas.drawRRect(rrect, _fillPaint);
        _markPaint
          ..color = mark
          ..strokeWidth = stroke * 1.15;
        final check = Path()
          ..moveTo(box.left + box.width * 0.24, box.top + box.height * 0.53)
          ..lineTo(box.left + box.width * 0.43, box.top + box.height * 0.72)
          ..lineTo(box.left + box.width * 0.78, box.top + box.height * 0.30);
        canvas.drawPath(check, _markPaint);
      case _CheckboxVisual.indeterminate:
        _strokePaint
          ..color = accent
          ..strokeWidth = stroke;
        canvas.drawRRect(rrect, _strokePaint);
        _markPaint
          ..color = accent
          ..strokeWidth = stroke * 1.3;
        canvas.drawLine(
          Offset(box.left + box.width * 0.28, box.center.dy),
          Offset(box.right - box.width * 0.28, box.center.dy),
          _markPaint,
        );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _EditorCheckboxSpan &&
          other.visual == visual &&
          other.accent == accent &&
          other.border == border &&
          other.mark == mark &&
          other.width == width &&
          other.height == height &&
          other.style == style;

  @override
  int get hashCode =>
      Object.hash(visual, accent, border, mark, width, height, style);
}
