import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';

import '../bloc/calendar/calendar_bloc.dart';
import '../l10n/app_localizations.dart';
import '../models/calendar_event.dart';
import '../services/day_bars_resolver.dart';
import '../services/day_summary_resolver.dart';
import '../widgets/calendar_day_bars.dart';
import '../widgets/day_summary_panel.dart';
import '../widgets/event_editor_sheet.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CalendarView();
  }
}

class _CalendarView extends StatelessWidget {
  const _CalendarView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendar)),
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
              _CalendarTable(state: loaded),
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
}

class _CalendarTable extends StatelessWidget {
  final CalendarPageLoaded state;

  const _CalendarTable({required this.state});

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
      headerStyle: const HeaderStyle(titleCentered: true),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        weekendTextStyle: theme.textTheme.bodyMedium!.copyWith(
          color: colorScheme.error.withValues(alpha: 0.85),
        ),
        todayDecoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(color: colorScheme.onSecondaryContainer),
        selectedDecoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(color: colorScheme.onPrimary),
        // Default dot markers are replaced by markerBuilder bars below.
        markersMaxCount: 0,
      ),
      calendarBuilders: CalendarBuilders<CalendarEvent>(
        markerBuilder: (context, day, events) {
          final bars = barsResolver.resolve(day, events);
          if (bars.isEmpty) return const SizedBox.shrink();
          return Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: CalendarDayBars(bars: bars),
            ),
          );
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
