/// Shared definition, scanning, and arithmetic for "money ledger"
/// lines — a line-led syntax for tracking a running sum inside a note:
///
/// ```text
/// $= 100          set the balance (initial sum / period checkpoint)
/// $+ 12.50 label  add an amount
/// $- 8 label      subtract an amount
/// $* 1.19         multiply the balance (e.g. tax)
/// $/ 2            divide the balance (e.g. split)
/// $$ label        show the running total at this point
/// $? label        show the net change since the last `$=` checkpoint
/// $! 500 label    spending target: shows the remaining budget
/// ```
///
/// `$=` doubles as a period boundary: place one under a month/year
/// heading and a later `$?` reports that period's total +/- change,
/// while `$$` always reports the absolute balance.
///
/// This is the single source of truth consumed by:
///   * the preview renderer (styled change rows + running balance),
///   * the editor span builder (tinted ops, painted `$$` total),
///   * the editor line index (incremental balance pass), and
///   * the preview builder's ledger pass in `prepare`.
///
/// Keeping one matcher and one arithmetic core here guarantees all
/// surfaces agree on exactly what is a money line and what the balance
/// is at every point of the document.
///
/// The balance is a pure function of note content — nothing is
/// persisted and no counter is mutated, so re-rendering can never
/// double-count. All arithmetic is fixed-point over ints (cents for
/// balances, 1/10000ths for parsed amounts): no floating-point drift.
/// Lines inside code fences are inert (both surfaces skip them), and a
/// leading backslash or any non-matching shape renders as plain text.
library;

/// Kinds of money line. [total], [delta], and [target] perform no
/// arithmetic — [total] displays the running balance where it appears,
/// [delta] the net change since the last [set] (or the note start),
/// and [target] declares a spending goal whose displayed value is the
/// remaining budget (target − spent since the last [set]).
enum MoneyLineKind {
  set,
  add,
  subtract,
  multiply,
  divide,
  total,
  delta,
  target,
}

/// A parsed money line. All offsets are relative to the scanned line.
///
/// `[markerStart, markerEnd)` covers the `$` + op character (or `$$`),
/// `[amountStart, amountEnd)` covers the amount digits (empty for
/// [MoneyLineKind.total]), and `[labelStart, line.length)` is the
/// optional trailing label (`labelStart == line.length` when absent).
class MoneyLineMatch {
  final MoneyLineKind kind;

  /// Offset of the leading `$`.
  final int markerStart;

  /// Offset just past the op character (`=`, `+`, `-`, `*`, `/`, `$`).
  final int markerEnd;

  /// Offset of the first amount digit; equals [amountEnd] for totals.
  final int amountStart;

  /// Offset just past the last amount code unit.
  final int amountEnd;

  /// Offset of the first label character, or the line length.
  final int labelStart;

  /// The amount in fixed-point 1/10000ths (`12.5` → `125000`). Zero
  /// for totals. Always non-negative — the op carries the sign.
  final int amountFixed;

  const MoneyLineMatch({
    required this.kind,
    required this.markerStart,
    required this.markerEnd,
    required this.amountStart,
    required this.amountEnd,
    required this.labelStart,
    required this.amountFixed,
  });
}

/// One collected money line with its folded running value — the
/// on-demand (tap-time) counterpart of the incremental render passes.
class MoneyLedgerEntry {
  final int lineIndex;

  /// The full source line, so presenters can show the amount and label
  /// exactly as typed without re-fetching the document.
  final String line;
  final MoneyLineMatch match;

  /// Balance after this line; the net change since the last `$=` for
  /// [MoneyLineKind.delta] lines.
  final int valueAfter;

  const MoneyLedgerEntry({
    required this.lineIndex,
    required this.line,
    required this.match,
    required this.valueAfter,
  });
}

/// Money ledger syntax + scanning + fixed-point arithmetic helpers.
class MarkdownMoneySyntax {
  MarkdownMoneySyntax._();

  /// Lines longer than this never parse as money lines, mirroring the
  /// editor's raw-render guard so preview and editor ledgers can never
  /// disagree about an oversized line.
  static const int maxLineLength = 4096;

  /// Balances are clamped to ±[balanceLimitCents] after every op so
  /// repeated multiplication can never overflow 64-bit intermediates.
  static const int balanceLimitCents = 50000000000;

  /// Fixed-point scale of [MoneyLineMatch.amountFixed].
  static const int amountScale = 10000;

  static const int _kDollar = 0x24; // $
  static const int _kEquals = 0x3D; // =
  static const int _kPlus = 0x2B; // +
  static const int _kMinus = 0x2D; // -
  static const int _kStar = 0x2A; // *
  static const int _kSlash = 0x2F; // /
  static const int _kDot = 0x2E; // .
  static const int _kComma = 0x2C; // ,
  static const int _kQuestion = 0x3F; // ?
  static const int _kBang = 0x21; // !

  /// Set/add/subtract amounts: up to 8 integer digits, 2 decimals.
  /// Capped below [balanceLimitCents] so a single amount can never be
  /// silently clamped — in particular a `$=` row's displayed amount is
  /// always exactly the balance it sets.
  static const int _maxAmountIntDigits = 8;
  static const int _maxAmountDecimals = 2;

  /// Multiply/divide factors: up to 4 integer digits, 4 decimals.
  static const int _maxFactorIntDigits = 4;
  static const int _maxFactorDecimals = 4;

  /// Whether [line]'s first non-whitespace character is the `$` marker
  /// (cheap pre-check so hot per-line paths can skip the full parse).
  static bool leadsWithMarker(String line) {
    final n = line.length;
    var i = 0;
    while (i < n && _isSpace(line.codeUnitAt(i))) {
      i++;
    }
    return i < n && line.codeUnitAt(i) == _kDollar;
  }

  /// Parses [line] as a money line, or `null` when it is not one.
  ///
  /// Shape: optional leading spaces/tabs, `$` + op char, then for ops
  /// an amount (`digits` with optional `.`/`,` decimals) that must end
  /// at a space or the line end, then an optional label. `$$` (total)
  /// takes no amount. A malformed amount rejects the whole line so it
  /// renders as plain text — visible feedback that it did not count.
  static MoneyLineMatch? parse(String line) {
    final n = line.length;
    if (n < 2 || n > maxLineLength) return null;
    var i = 0;
    while (i < n && _isSpace(line.codeUnitAt(i))) {
      i++;
    }
    if (i >= n || line.codeUnitAt(i) != _kDollar) return null;
    final markerStart = i;
    i++;
    if (i >= n) return null;
    final op = line.codeUnitAt(i);
    final MoneyLineKind kind;
    switch (op) {
      case _kEquals:
        kind = MoneyLineKind.set;
      case _kPlus:
        kind = MoneyLineKind.add;
      case _kMinus:
        kind = MoneyLineKind.subtract;
      case _kStar:
        kind = MoneyLineKind.multiply;
      case _kSlash:
        kind = MoneyLineKind.divide;
      case _kDollar:
        kind = MoneyLineKind.total;
      case _kQuestion:
        kind = MoneyLineKind.delta;
      case _kBang:
        kind = MoneyLineKind.target;
      default:
        return null;
    }
    i++;
    final markerEnd = i;

    if (kind == MoneyLineKind.total || kind == MoneyLineKind.delta) {
      if (i < n && !_isSpace(line.codeUnitAt(i))) return null;
      while (i < n && _isSpace(line.codeUnitAt(i))) {
        i++;
      }
      return MoneyLineMatch(
        kind: kind,
        markerStart: markerStart,
        markerEnd: markerEnd,
        amountStart: markerEnd,
        amountEnd: markerEnd,
        labelStart: i,
        amountFixed: 0,
      );
    }

    while (i < n && _isSpace(line.codeUnitAt(i))) {
      i++;
    }
    final amountStart = i;
    final bool isFactor =
        kind == MoneyLineKind.multiply || kind == MoneyLineKind.divide;
    final maxInt = isFactor ? _maxFactorIntDigits : _maxAmountIntDigits;
    final maxDec = isFactor ? _maxFactorDecimals : _maxAmountDecimals;

    var intPart = 0;
    var intDigits = 0;
    while (i < n && _isDigit(line.codeUnitAt(i))) {
      intPart = intPart * 10 + (line.codeUnitAt(i) - 0x30);
      i++;
      intDigits++;
      if (intDigits > maxInt) return null;
    }
    if (intDigits == 0) return null;

    var decPart = 0;
    var decDigits = 0;
    if (i < n && (line.codeUnitAt(i) == _kDot || line.codeUnitAt(i) == _kComma)) {
      var j = i + 1;
      while (j < n && _isDigit(line.codeUnitAt(j))) {
        decPart = decPart * 10 + (line.codeUnitAt(j) - 0x30);
        j++;
        decDigits++;
        if (decDigits > maxDec) return null;
      }
      if (decDigits == 0) return null;
      i = j;
    }
    if (i < n && !_isSpace(line.codeUnitAt(i))) return null;
    final amountEnd = i;

    var scale = amountScale;
    for (var d = 0; d < decDigits; d++) {
      scale ~/= 10;
    }
    final amountFixed = intPart * amountScale + decPart * scale;
    if (kind == MoneyLineKind.divide && amountFixed == 0) return null;

    while (i < n && _isSpace(line.codeUnitAt(i))) {
      i++;
    }
    return MoneyLineMatch(
      kind: kind,
      markerStart: markerStart,
      markerEnd: markerEnd,
      amountStart: amountStart,
      amountEnd: amountEnd,
      labelStart: i,
      amountFixed: amountFixed,
    );
  }

  /// Applies [m] to a running [balanceCents] and returns the new
  /// balance in cents, clamped to ±[balanceLimitCents]. Totals return
  /// the balance unchanged. Multiplication/division round half away
  /// from zero to the nearest cent.
  static int apply(int balanceCents, MoneyLineMatch m) {
    switch (m.kind) {
      case MoneyLineKind.set:
        return _clamp(m.amountFixed ~/ 100);
      case MoneyLineKind.add:
        return _clamp(balanceCents + m.amountFixed ~/ 100);
      case MoneyLineKind.subtract:
        return _clamp(balanceCents - m.amountFixed ~/ 100);
      case MoneyLineKind.multiply:
        return _clamp(_roundedDiv(balanceCents * m.amountFixed, amountScale));
      case MoneyLineKind.divide:
        return _clamp(_roundedDiv(balanceCents * amountScale, m.amountFixed));
      case MoneyLineKind.total:
      case MoneyLineKind.delta:
      case MoneyLineKind.target:
        return balanceCents;
    }
  }

  /// The display value a money line's stored entry carries: the running
  /// balance, except `$?` (net change since [anchor]) and `$!` (the
  /// remaining budget: target − spent since [anchor]). Single source of
  /// truth for the editor index pass, the preview ledger fold, and
  /// [collectEntries], so the three can never disagree.
  static int displayValue(MoneyLineMatch m, int balance, int anchor) {
    switch (m.kind) {
      case MoneyLineKind.delta:
        return balance - anchor;
      case MoneyLineKind.target:
        return m.amountFixed ~/ 100 + balance - anchor;
      default:
        return balance;
    }
  }

  /// Formats [cents] as a plain decimal with exactly two decimals and a
  /// leading `-` when negative (`-1250` → `-12.50`). Content-level like
  /// the syntax itself, so no locale formatting is applied.
  static String formatCents(int cents) {
    final sign = cents < 0 ? '-' : '';
    final a = cents.abs();
    final units = a ~/ 100;
    final f = a % 100;
    return '$sign$units.${f < 10 ? '0$f' : '$f'}';
  }

  /// Formats [cents] like [formatCents] but with an explicit sign:
  /// `+12.50`, `-8.00`, `±0.00`. Used by `$?` net-change rows.
  static String formatCentsSigned(int cents) {
    if (cents == 0) return '±0.00';
    return cents > 0 ? '+${formatCents(cents)}' : formatCents(cents);
  }

  /// [formatCents] with a currency symbol: prefix symbols attach to the
  /// number after the sign (`-lei12.50` never happens — `-` first, then
  /// symbol), suffix symbols follow with a space (`12.50 lei`). An
  /// empty [symbol] falls back to the plain form.
  static String formatCentsWithSymbol(
    int cents, {
    required String symbol,
    required bool suffix,
  }) {
    final plain = formatCents(cents);
    if (symbol.isEmpty) return plain;
    if (suffix) return '$plain $symbol';
    return cents < 0 ? '-$symbol${plain.substring(1)}' : '$symbol$plain';
  }

  /// [formatCentsSigned] with a currency symbol; the sign char stays
  /// first (`+€12.50`, `-€8.00`, `±€0.00`), suffix symbols follow with
  /// a space (`+12.50 lei`).
  static String formatCentsSignedWithSymbol(
    int cents, {
    required String symbol,
    required bool suffix,
  }) {
    final plain = formatCentsSigned(cents);
    if (symbol.isEmpty) return plain;
    if (suffix) return '$plain $symbol';
    return '${plain.substring(0, 1)}$symbol${plain.substring(1)}';
  }

  /// Collects every money line from line 0 through [toLine] (inclusive;
  /// -1 = whole document), folding the ledger exactly like the render
  /// passes: [startCents] seeds both the balance and the `$?` anchor,
  /// [isInert] excludes fence/block lines (each surface passes its own
  /// predicate so the collector always agrees with what is rendered).
  /// `valueAfter` is the running balance after the line (the net change
  /// since the last `$=` for delta lines); `anchorLine` is the line
  /// index of the last `$=` at [toLine], or -1 when none. Runs on tap
  /// (rare, user-initiated), so the O(document) scan is fine — this is
  /// deliberately not part of the incremental passes.
  static ({List<MoneyLedgerEntry> entries, int anchorLine}) collectEntries({
    required int lineCount,
    required String Function(int) lineAt,
    required bool Function(int) isInert,
    int toLine = -1,
    int startCents = 0,
  }) {
    final last = toLine < 0 ? lineCount - 1 : toLine;
    final entries = <MoneyLedgerEntry>[];
    var balance = startCents;
    var anchor = startCents;
    var anchorLine = -1;
    for (var i = 0; i <= last && i < lineCount; i++) {
      final line = lineAt(i);
      if (line.isEmpty || !leadsWithMarker(line) || isInert(i)) continue;
      final m = parse(line);
      if (m == null) continue;
      balance = apply(balance, m);
      if (m.kind == MoneyLineKind.set) {
        anchor = balance;
        anchorLine = i;
      }
      entries.add(
        MoneyLedgerEntry(
          lineIndex: i,
          line: line,
          match: m,
          valueAfter: displayValue(m, balance, anchor),
        ),
      );
    }
    return (entries: entries, anchorLine: anchorLine);
  }

  static int _clamp(int cents) => cents < -balanceLimitCents
      ? -balanceLimitCents
      : cents > balanceLimitCents
      ? balanceLimitCents
      : cents;

  static int _roundedDiv(int a, int b) {
    final r = (a.abs() + (b >> 1)) ~/ b;
    return a < 0 ? -r : r;
  }

  static bool _isSpace(int c) => c == 0x20 || c == 0x09;

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
}
