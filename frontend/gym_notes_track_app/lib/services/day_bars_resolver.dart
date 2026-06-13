import '../constants/calendar_categories.dart';
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
    final seen = <String>{};
    final bars = <DayBar>[];
    for (final event in events) {
      if (!seen.add(event.categoryId)) continue;
      final category = CalendarCategories.resolve(event.categoryId);
      bars.add(
        DayBar(
          key: 'event:${event.categoryId}',
          color: category.color,
          priority: category.sortOrder, // categories sort above contextual bars
          semanticLabel: CalendarCategories.labelOf(category, l10n),
        ),
      );
    }
    return bars;
  }
}

/// Chains a list of [DayBarProvider]s and returns a sorted, deduplicated
/// list of bars for a given day.
///
/// To add a new bar type, implement [DayBarProvider] and pass it into the
/// constructor — no other call sites need to change.
///
/// Note: this resolver does **not** cap the returned list. The
/// [CalendarDayBars] widget decides how many bars to render and renders a
/// "+N" overflow indicator for the remainder, controlled by the user's
/// `calendarMaxDayBars` setting.
class DayBarsResolver {
  final List<DayBarProvider> providers;

  const DayBarsResolver({required this.providers});

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
    return sorted;
  }
}
