import 'package:flutter/material.dart';

import '../models/day_bar.dart';

/// Renders a vertical stack of thin colored bars inside a calendar day cell.
///
/// Designed to be cheap: a `Column` of `DecoratedBox`es with no animations.
/// Use through `TableCalendar.calendarBuilders.markerBuilder`.
class CalendarDayBars extends StatelessWidget {
  final List<DayBar> bars;
  final double barHeight;
  final double spacing;
  final double horizontalInset;

  const CalendarDayBars({
    super.key,
    required this.bars,
    this.barHeight = 3,
    this.spacing = 1.5,
    this.horizontalInset = 6,
  });

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < bars.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            Semantics(
              label: bars[i].semanticLabel,
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: bars[i].color,
                  borderRadius: BorderRadius.circular(barHeight),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
