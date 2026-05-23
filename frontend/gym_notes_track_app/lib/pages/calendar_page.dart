import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';

import '../bloc/calendar/calendar_bloc.dart';
import '../l10n/app_localizations.dart';
import '../models/calendar_event.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CalendarBloc()..add(const LoadCalendarEvents()),
      child: const _CalendarView(),
    );
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
          return Column(
            children: [
              _CalendarTable(state: loaded),
              const Divider(height: 1),
              Expanded(child: _SelectedEventsList(events: loaded.selectedEvents)),
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
            onPressed: () => _showAddEventDialog(context, selectedDay),
            child: const Icon(Icons.add_rounded),
          );
        },
      ),
    );
  }

  Future<void> _showAddEventDialog(BuildContext context, DateTime day) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.addEvent),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.eventTitle),
            maxLength: 120,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              final trimmed = value.trim();
              if (trimmed.isNotEmpty) {
                Navigator.of(dialogContext).pop(trimmed);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isNotEmpty) {
                  Navigator.of(dialogContext).pop(trimmed);
                }
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (title == null || !context.mounted) return;
    context.read<CalendarBloc>().add(
      CreateCalendarEvent(
        event: CalendarEvent(
          id: const Uuid().v4(),
          title: title,
          category: CalendarEventCategory.gym,
          startDate: day,
        ),
      ),
    );
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

    return TableCalendar<CalendarEvent>(
      firstDay: DateTime.utc(2000, 1, 1),
      lastDay: DateTime.utc(2100, 12, 31),
      focusedDay: state.focusedDay,
      selectedDayPredicate: (day) => isSameDay(state.selectedDay, day),
      calendarFormat: state.format,
      eventLoader: context.read<CalendarBloc>().eventsForDay,
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
        markerDecoration: BoxDecoration(
          color: colorScheme.tertiary,
          shape: BoxShape.circle,
        ),
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

class _SelectedEventsList extends StatelessWidget {
  final List<CalendarEvent> events;

  const _SelectedEventsList({required this.events});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.calendarNoEventsForDay,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final event = events[index];
        return Card(
          child: ListTile(
            leading: Icon(Icons.circle, color: _categoryColor(event.category), size: 14),
            title: Text(event.title),
            subtitle: Text(event.allDay ? l10n.eventAllDay : ''),
          ),
        );
      },
    );
  }

  Color _categoryColor(CalendarEventCategory category) {
    return switch (category) {
      CalendarEventCategory.gym => const Color(0xFF1E88E5),
      CalendarEventCategory.cardio => const Color(0xFFE53935),
      CalendarEventCategory.rest => const Color(0xFF43A047),
      CalendarEventCategory.holiday => const Color(0xFFFFB300),
      CalendarEventCategory.competition => const Color(0xFF8E24AA),
      CalendarEventCategory.measurement => const Color(0xFF00897B),
      CalendarEventCategory.other => const Color(0xFF757575),
    };
  }
}