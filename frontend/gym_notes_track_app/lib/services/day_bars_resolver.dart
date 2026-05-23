import '../constants/calendar_colors.dart';
import '../constants/public_holidays.dart';
import '../l10n/app_localizations.dart';
import '../models/calendar_event.dart';
import '../models/day_bar.dart';

/// Contract for anything that contributes bars to a calendar day cell.
///
/// Providers must be pure & cheap: [barsFor] is called by `TableCalendar`'s
/// `markerBuilder` for every visible cell on every rebuild. Avoid I/O,
/// allocations beyond what is needed, and do not call BLoCs from here.
abstract interface class DayBarProvider {
  Iterable<DayBar> barsFor(DateTime day, List<CalendarEvent> events);
}

/// Emits a weekend bar for Saturday/Sunday.
class WeekendDayBarProvider implements DayBarProvider {
  final AppLocalizations l10n;

  const WeekendDayBarProvider(this.l10n);

  @override
  Iterable<DayBar> barsFor(DateTime day, List<CalendarEvent> events) {
    if (day.weekday != DateTime.saturday && day.weekday != DateTime.sunday) {
      return const [];
    }
    return [
      DayBar(
        key: 'weekend',
        color: CalendarColors.weekend,
        priority: 250,
        semanticLabel: l10n.dayBarWeekend,
      ),
    ];
  }
}

/// Emits a public-holiday bar when the date matches `PublicHolidays`.
class PublicHolidayDayBarProvider implements DayBarProvider {
  final AppLocalizations l10n;

  const PublicHolidayDayBarProvider(this.l10n);

  @override
  Iterable<DayBar> barsFor(DateTime day, List<CalendarEvent> events) {
    if (!PublicHolidays.isHoliday(day)) return const [];
    return [
      DayBar(
        key: 'holiday',
        color: CalendarColors.publicHoliday,
        priority: 150,
        semanticLabel: l10n.dayBarPublicHoliday,
      ),
    ];
  }
}

/// Emits one bar per distinct event category present on the day.
class EventCategoryDayBarProvider implements DayBarProvider {
  final AppLocalizations l10n;

  const EventCategoryDayBarProvider(this.l10n);

  @override
  Iterable<DayBar> barsFor(DateTime day, List<CalendarEvent> events) {
    if (events.isEmpty) return const [];
    final seen = <CalendarEventCategory>{};
    final bars = <DayBar>[];
    for (final event in events) {
      if (!seen.add(event.category)) continue;
      bars.add(
        DayBar(
          key: 'event:${event.category.name}',
          color: CalendarColors.forCategory(event.category),
          priority: event.category.index, // 0..N → all above contextual bars
          semanticLabel: _labelFor(event.category),
        ),
      );
    }
    return bars;
  }

  String _labelFor(CalendarEventCategory category) {
    return switch (category) {
      CalendarEventCategory.gym => l10n.eventCategoryGym,
      CalendarEventCategory.cardio => l10n.eventCategoryCardio,
      CalendarEventCategory.rest => l10n.eventCategoryRest,
      CalendarEventCategory.holiday => l10n.eventCategoryHoliday,
      CalendarEventCategory.competition => l10n.eventCategoryCompetition,
      CalendarEventCategory.measurement => l10n.eventCategoryMeasurement,
      CalendarEventCategory.other => l10n.eventCategoryOther,
    };
  }
}

/// Chains a list of [DayBarProvider]s and returns a sorted, deduplicated,
/// length-capped list of bars for a given day.
///
/// To add a new bar type, implement [DayBarProvider] and pass it into the
/// constructor — no other call sites need to change.
class DayBarsResolver {
  final List<DayBarProvider> providers;
  final int maxBars;

  const DayBarsResolver({required this.providers, this.maxBars = 4});

  /// Default resolver bundling weekend + public holiday + event categories.
  factory DayBarsResolver.defaults(AppLocalizations l10n) {
    return DayBarsResolver(
      providers: [
        EventCategoryDayBarProvider(l10n),
        PublicHolidayDayBarProvider(l10n),
        WeekendDayBarProvider(l10n),
      ],
    );
  }

  List<DayBar> resolve(DateTime day, List<CalendarEvent> events) {
    final byKey = <String, DayBar>{};
    for (final provider in providers) {
      for (final bar in provider.barsFor(day, events)) {
        byKey.putIfAbsent(bar.key, () => bar);
      }
    }
    final sorted = byKey.values.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    if (sorted.length <= maxBars) return sorted;
    return sorted.sublist(0, maxBars);
  }
}
