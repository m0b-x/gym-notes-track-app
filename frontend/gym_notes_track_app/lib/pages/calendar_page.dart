import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../bloc/calendar/calendar_bloc.dart';
import '../constants/settings_keys.dart';
import '../l10n/app_localizations.dart';
import '../models/calendar_event.dart';
import '../services/day_bars_resolver.dart';
import '../services/day_summary_resolver.dart';
import '../services/settings_service.dart';
import '../widgets/calendar_day_bars.dart';
import '../widgets/calendar_filter_sheet.dart';
import '../widgets/day_summary_panel.dart';
import '../widgets/event_editor_sheet.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CalendarView();
  }
}

class _CalendarView extends StatefulWidget {
  const _CalendarView();

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  int _maxDayBars = SettingsKeys.defaultCalendarMaxDayBars;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService.getInstance();
    final maxBars = await settings.getCalendarMaxDayBars();
    if (!mounted) return;
    setState(() => _maxDayBars = maxBars);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calendar),
        actions: [
          BlocBuilder<CalendarBloc, CalendarPageState>(
            builder: (context, state) {
              final loaded = state is CalendarPageLoaded ? state : null;
              final hasFilter =
                  loaded != null &&
                  loaded.visibleCategories.length !=
                      CalendarEventCategory.values.length;
              return IconButton(
                tooltip: l10n.filterCalendar,
                icon: Icon(
                  hasFilter
                      ? Icons.filter_alt_rounded
                      : Icons.filter_alt_outlined,
                ),
                onPressed: loaded == null
                    ? null
                    : () => _openFilterSheet(context, loaded),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<CalendarBloc, CalendarPageState>(
        builder: (context, state) {
          if (state is CalendarPageLoading || state is CalendarPageInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is CalendarPageError) {
            return Center(child: Text(state.message));
          }
          final loaded = state as CalendarPageLoaded;
          final summaryResolver = DaySummaryResolver.defaults(l10n);
          final entries = summaryResolver.resolve(
            loaded.selectedDay,
            loaded.selectedEvents,
          );
          return Column(
            children: [
              _CalendarTable(state: loaded, maxDayBars: _maxDayBars),
              const Divider(height: 1),
              Expanded(
                child: DaySummaryPanel(
                  entries: entries,
                  onEventTap: (event) =>
                      _openEditorSheet(context, initialEvent: event),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: BlocBuilder<CalendarBloc, CalendarPageState>(
        builder: (context, state) {
          final selectedDay = state is CalendarPageLoaded
              ? state.selectedDay
              : DateTime.now();
          return FloatingActionButton(
            tooltip: l10n.addEvent,
            onPressed: () => _openEditorSheet(context, day: selectedDay),
            child: const Icon(Icons.add_rounded),
          );
        },
      ),
    );
  }

  Future<void> _openEditorSheet(
    BuildContext context, {
    CalendarEvent? initialEvent,
    DateTime? day,
  }) async {
    final result = await EventEditorSheet.show(
      context,
      defaultDate: initialEvent?.startDate ?? day ?? DateTime.now(),
      initialEvent: initialEvent,
    );
    if (result == null || !context.mounted) return;
    final bloc = context.read<CalendarBloc>();
    switch (result) {
      case EventEditorSaved(:final event):
        if (initialEvent == null) {
          bloc.add(CreateCalendarEvent(event: event));
        } else {
          bloc.add(UpdateCalendarEvent(event: event));
        }
      case EventEditorDeleted(:final id):
        bloc.add(DeleteCalendarEvent(eventId: id));
    }
  }

  Future<void> _openFilterSheet(
    BuildContext context,
    CalendarPageLoaded state,
  ) async {
    final result = await CalendarFilterSheet.show(
      context,
      format: state.format,
      categories: state.visibleCategories,
    );
    if (result == null || !context.mounted) return;
    final bloc = context.read<CalendarBloc>();
    if (result.format != state.format) {
      bloc.add(ChangeCalendarFormat(format: result.format));
    }
    bloc.add(ChangeVisibleCategories(categories: result.visibleCategories));
  }
}

class _CalendarTable extends StatelessWidget {
  final CalendarPageLoaded state;
  final int maxDayBars;

  const _CalendarTable({required this.state, required this.maxDayBars});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final calendarBloc = context.read<CalendarBloc>();
    final barsResolver = DayBarsResolver.defaults(l10n);

    return TableCalendar<CalendarEvent>(
      firstDay: DateTime.utc(2000, 1, 1),
      lastDay: DateTime.utc(2100, 12, 31),
      focusedDay: state.focusedDay,
      selectedDayPredicate: (day) => isSameDay(state.selectedDay, day),
      calendarFormat: state.format,
      eventLoader: calendarBloc.eventsForDay,
      startingDayOfWeek: StartingDayOfWeek.monday,
      locale: l10n.localeName,
      availableCalendarFormats: {
        CalendarFormat.month: l10n.calendarFormatMonth,
        CalendarFormat.twoWeeks: l10n.calendarFormatTwoWeeks,
        CalendarFormat.week: l10n.calendarFormatWeek,
      },
      headerStyle: const HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false,
      ),
      calendarStyle: CalendarStyle(
        // Show leading/trailing days from adjacent months, faded so the
        // focused month still reads as the primary content.
        outsideDaysVisible: true,
        outsideTextStyle: theme.textTheme.bodyMedium!.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.35),
        ),
        weekendTextStyle: theme.textTheme.bodyMedium!.copyWith(
          color: colorScheme.error.withValues(alpha: 0.85),
        ),
        // Transparent today bubble with a subtle ring, so the day-bar
        // markers underneath stay visible and the cell does not visually
        // fight with bar colors.
        todayDecoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.55),
            width: 1.4,
          ),
        ),
        todayTextStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        selectedDecoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(color: colorScheme.onPrimary),
        // Default dot markers are replaced by markerBuilder bars below.
        markersMaxCount: 0,
      ),
      calendarBuilders: CalendarBuilders<CalendarEvent>(
        headerTitleBuilder: (context, day) {
          final title = DateFormat.yMMMM(l10n.localeName).format(day);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: l10n.goToToday,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(Icons.today_rounded, size: 20),
                onPressed: () {
                  final today = DateTime.now();
                  final normalized = DateTime.utc(
                    today.year,
                    today.month,
                    today.day,
                  );
                  context.read<CalendarBloc>().add(
                    SelectCalendarDay(day: normalized, focusedDay: normalized),
                  );
                },
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
        markerBuilder: (context, day, events) {
          final bars = barsResolver.resolve(day, events);
          if (bars.isEmpty) return const SizedBox.shrink();
          final isOutside =
              day.month != state.focusedDay.month ||
              day.year != state.focusedDay.year;
          Widget child = Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: CalendarDayBars(bars: bars, maxBars: maxDayBars),
            ),
          );
          if (isOutside) child = Opacity(opacity: 0.35, child: child);
          return child;
        },
      ),
      onDaySelected: (selectedDay, focusedDay) {
        context.read<CalendarBloc>().add(
          SelectCalendarDay(day: selectedDay, focusedDay: focusedDay),
        );
      },
      onPageChanged: (focusedDay) {
        context.read<CalendarBloc>().add(
          ChangeFocusedDay(focusedDay: focusedDay),
        );
      },
      onFormatChanged: (format) {
        context.read<CalendarBloc>().add(ChangeCalendarFormat(format: format));
      },
    );
  }
}
