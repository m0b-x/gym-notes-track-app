import 'package:flutter/material.dart';

import '../models/calendar_event.dart';

/// Centralized color palette for calendar cells, bars and category chips.
///
/// To add a new event category bar:
///   1. Add a value to [CalendarEventCategory].
///   2. Add a case to [forCategory] returning the bar color.
///   3. Add a localized label in `event_category_labels.dart` / ARBs.
///
/// To add a new non-event bar kind (e.g. "training cycle", "deload week"):
///   Prefer writing a custom `DayBarProvider` instead of extending this class.
abstract final class CalendarColors {
  // --- Non-event bars -------------------------------------------------------
  static const Color weekend = Color(0xFFB0BEC5); // blue grey 200
  static const Color publicHoliday = Color(0xFFFFB300); // amber 600

  // --- Event category bars --------------------------------------------------
  static const Color gym = Color(0xFF1E88E5); // blue 600
  static const Color cardio = Color(0xFFE53935); // red 600
  static const Color rest = Color(0xFF43A047); // green 600
  static const Color holiday = Color(0xFFFFA000); // amber 700
  static const Color competition = Color(0xFF8E24AA); // purple 600
  static const Color measurement = Color(0xFF00897B); // teal 600
  static const Color other = Color(0xFF757575); // grey 600

  static Color forCategory(CalendarEventCategory category) {
    return switch (category) {
      CalendarEventCategory.gym => gym,
      CalendarEventCategory.cardio => cardio,
      CalendarEventCategory.rest => rest,
      CalendarEventCategory.holiday => holiday,
      CalendarEventCategory.competition => competition,
      CalendarEventCategory.measurement => measurement,
      CalendarEventCategory.other => other,
    };
  }
}
