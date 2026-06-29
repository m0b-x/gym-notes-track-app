import 'package:flutter/material.dart';

import '../models/day_bar.dart';

/// Renders a vertical stack of thin colored bars inside a calendar day cell.
///
/// Designed to be cheap: a `Column` of `DecoratedBox`es with no animations.
/// Use through `TableCalendar.calendarBuilders.markerBuilder`.
///
/// When [bars] contains more than [maxBars] entries, the first
/// `maxBars - 1` bars are rendered followed by a compact "+N" overflow
/// indicator that takes the slot of the last bar. The widget never grows
/// beyond [maxBars] visual rows so calendar cells keep a stable height.
class CalendarDayBars extends StatelessWidget {
  final List<DayBar> bars;
  final int maxBars;
  final double barHeight;
  final double spacing;
  final double horizontalInset;

  const CalendarDayBars({
    super.key,
    required this.bars,
    this.maxBars = 3,
    this.barHeight = 3,
    this.spacing = 1.5,
    this.horizontalInset = 6,
  });

  /// Below this luminance delta against the cell surface, a bar gets a
  /// hairline outline so pale / low-contrast colors stay visible.
  static const double _lowContrastThreshold = 0.22;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty || maxBars <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final hasOverflow = bars.length > maxBars;
    // Reserve the last slot for the "+N" indicator when overflowing.
    final visibleCount = hasOverflow ? maxBars - 1 : bars.length;
    final hiddenCount = hasOverflow ? bars.length - visibleCount : 0;
    // Reference luminance of the calendar cell background, used to outline
    // bars whose color is too close to it (e.g. a pale custom color).
    final surfaceLum = theme.colorScheme.surface.computeLuminance();
    final outlineColor = theme.colorScheme.onSurface.withValues(alpha: 0.4);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < visibleCount; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            Semantics(
              label: bars[i].semanticLabel,
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: bars[i].color,
                  borderRadius: BorderRadius.circular(barHeight),
                  border:
                      (bars[i].color.computeLuminance() - surfaceLum).abs() <
                          _lowContrastThreshold
                      ? Border.all(color: outlineColor, width: 0.5)
                      : null,
                ),
              ),
            ),
          ],
          if (hasOverflow) ...[
            if (visibleCount > 0) SizedBox(height: spacing),
            _OverflowChip(
              count: hiddenCount,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}

class _OverflowChip extends StatelessWidget {
  final int count;
  final Color color;

  const _OverflowChip({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      '+$count',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        height: 1.0,
        color: color,
      ),
    );
  }
}
