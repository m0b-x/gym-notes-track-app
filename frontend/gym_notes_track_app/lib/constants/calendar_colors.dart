import 'package:flutter/material.dart';

/// Centralized colors for the calendar's **contextual** (non-event) day bars
/// and summary entries.
///
/// Per-category colors are no longer defined here — categories are
/// data-driven (see `CalendarCategory.colorValue` / `CategoryService`), so a
/// category's tint comes from its persisted row. The seed colors for built-in
/// categories live in `CalendarCategories.builtInSeeds`.
///
/// To add a new non-event bar kind (e.g. "training cycle", "deload week"):
///   Prefer writing a custom `DayBarProvider` over extending this class.
abstract final class CalendarColors {
  static const Color weekend = Color(0xFFB0BEC5); // blue grey 200
  static const Color publicHoliday = Color(0xFFFFB300); // amber 600
}
